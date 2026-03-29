function New-RunFailures {
    <#
    .SYNOPSIS
    Creates Azure DevOps work items for failed Databricks runs.

    .DESCRIPTION
    Queries Databricks for failed job runs and creates corresponding bugs/stories in Azure DevOps.
    Avoids duplicates by tagging work items with run IDs. Requires both databricks CLI and az CLI.

    .PARAMETER TimeRange
    How far back to look for failures (in hours). Default: 24

    .PARAMETER JobId
    Optional: Specific Databricks job ID to monitor. If omitted, checks all jobs.

    .PARAMETER WhatIf
    Show what would be created without actually creating work items.

    .EXAMPLE
    New-RunFailures
    Checks last 24 hours of all jobs

    .EXAMPLE
    New-RunFailures -TimeRange 48 -JobId 12345
    Checks specific job for last 48 hours

    .EXAMPLE
    crf -WhatIf
    Preview mode
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('crf')]
    param(
        [Parameter()]
        [int]$TimeRange = 24,

        [Parameter()]
        [string]$JobId
    )

    # Lazy load config
    if (-not $script:config) {
        $script:config = Get-ModuleConfig -ModuleName 'Databricks'
    }

    $dbConfig = $script:config.databricks
    $azConfig = $script:config.azureDevOps

    # Check prerequisites
    $databricksCmd = Get-Command databricks -ErrorAction SilentlyContinue
    if (-not $databricksCmd) {
        Write-Error "Databricks CLI not found. Install from: https://docs.databricks.com/dev-tools/cli/install.html"
        return
    }

    $azCmd = Get-Command az -ErrorAction SilentlyContinue
    if (-not $azCmd) {
        Write-Error "Azure CLI not found. Install from: https://aka.ms/azure-cli"
        return
    }

    # Check Azure authentication
    Write-Verbose "Checking Azure authentication..."
    az account show 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Not authenticated with Azure. Launching authentication..." -ForegroundColor Yellow
        az login
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Azure authentication failed"
            return
        }
    }

    Write-Host "Querying Databricks for failed runs in last $TimeRange hours..." -ForegroundColor Cyan

    # Get failed runs
    try {
        $failedRuns = Get-DatabricksFailedRuns -TimeRange $TimeRange -JobId $JobId -DatabricksProfile $dbConfig.profile -WorkItemMapping $azConfig.workItemMapping

        if (-not $failedRuns -or $failedRuns.Count -eq 0) {
            Write-Host "No failed runs found in the specified time range." -ForegroundColor Green
            return
        }

        Write-Host "Found $($failedRuns.Count) failed run(s)" -ForegroundColor Yellow
    }
    catch {
        Write-Error "Failed to query Databricks runs: $_"
        return
    }

    # Process each failed run
    $created = 0
    $skipped = 0

    foreach ($run in $failedRuns) {
        $runId = $run.run_id
        $runName = $run.run_name
        $jobId = $run.job_id
        $state = $run.state.result_state

        Write-Verbose "Processing job $jobId, run $runId (state: $state)..."

        # Check if work item already exists
        try {
            $exists = Test-WorkItemExists -JobName $runName -Organization $azConfig.organization -Project $azConfig.project

            if ($exists) {
                Write-Host "  [SKIP] Work item already exists for job $runName" -ForegroundColor Gray
                $skipped++
                continue
            }
        }
        catch {
            Write-Warning "Failed to check for existing work item for job $runName : $_"
            continue
        }

        # Create work item
        if ($PSCmdlet.ShouldProcess("WorkItem", "Create $($azConfig.workItemMapping.$state) for job $runName")) {
            try {
                $workItem = New-RunFailureWorkItem `
                    -Run $run `
                    -WorkItemType $azConfig.workItemMapping.$state `
                    -Organization $azConfig.organization `
                    -Project $azConfig.project `
                    -AreaPath $azConfig.areaPath `
                    -IterationPath $azConfig.iterationPath `
                    -Tags $azConfig.tags `
                    -ParentWorkItemId $azConfig.parentWorkItemId `
                    -DatabricksHost $dbConfig.host

                Write-Host "  [CREATED] Work item #$($workItem.id): $($workItem.fields.'System.Title')" -ForegroundColor Green
                $created++
            }
            catch {
                Write-Error "Failed to create work item for job $runName : $_"
            }
        }
        else {
            Write-Host "  [WHATIF] Would create $($azConfig.workItemMapping.$state) for job $runName" -ForegroundColor Yellow
        }
    }

    Write-Host "`nSummary: $created created, $skipped skipped" -ForegroundColor Cyan
}

# Private helper functions

function Get-DatabricksFailedRuns {
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [int]$TimeRange,

        [Parameter()]
        [string]$JobId,

        [Parameter(Mandatory)]
        [string]$DatabricksProfile,

        [Parameter(Mandatory)]
        [object]$WorkItemMapping
    )

    # Calculate start time as Unix timestamp in milliseconds
    $startTime = [DateTimeOffset]::Now.AddHours(-$TimeRange).ToUnixTimeMilliseconds()

    # Build command
    $cmdArgs = @('jobs', 'list-runs', '--start-time-from', $startTime, '-p', $DatabricksProfile, '--output', 'JSON')

    if ($JobId) {
        $cmdArgs += @('--job-id', $JobId)
    }

    Write-Verbose "Running: databricks $($cmdArgs -join ' ')"

    # Execute command
    $output = & databricks $cmdArgs 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        throw "Databricks CLI failed: $output"
    }

    # Parse JSON
    try {
        $result = $output | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse Databricks response: $_"
    }

    # Filter by states that have work item mappings
    $monitoredStates = $WorkItemMapping.PSObject.Properties.Name

    # Only look at terminated runs with a result_state that matches our mapping
    $filteredRuns = @($result | Where-Object {
            $_.status.state -eq 'TERMINATED' -and
            $_.state.result_state -and
            $_.state.result_state -in $monitoredStates
        })

    # Group by job_id and take only the latest run per job
    $latestRunsPerJob = @($filteredRuns | Group-Object -Property job_id | ForEach-Object {
            $_.Group | Sort-Object -Property start_time -Descending | Select-Object -First 1
        })

    # Ensure we always return an array type
    return , $latestRunsPerJob
}

function Test-WorkItemExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$JobName,

        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Project
    )

    $jobTag = "databricks-job-$JobName"
    # Check if work item exists with the tag and is in an active state (New or Active)
    $wiql = "SELECT [System.Id] FROM WorkItems WHERE [System.Tags] CONTAINS '$jobTag' AND [System.State] IN ('New', 'Active')"

    Write-Verbose "Querying for active work item with tag: $jobTag"

    # Execute query
    $output = az boards query `
        --wiql $wiql `
        --org "https://dev.azure.com/$Organization" `
        --project $Project `
        --output json 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        throw "Azure DevOps query failed: $output"
    }

    # Parse result
    try {
        $result = $output | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse Azure DevOps response: $_"
    }

    return ($result -and $result.Count -gt 0)
}

function New-RunFailureWorkItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Run,

        [Parameter(Mandatory)]
        [string]$WorkItemType,

        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter(Mandatory)]
        [string]$AreaPath,

        [Parameter()]
        [string]$IterationPath,

        [Parameter()]
        [string]$AssignedTo,

        [Parameter()]
        [array]$Tags = @(),

        [Parameter()]
        [int]$ParentWorkItemId,

        [Parameter(Mandatory)]
        [string]$DatabricksHost
    )

    # Extract run details
    $runId = $Run.run_id
    $jobId = $Run.job_id
    $runName = $Run.run_name
    $stateMessage = $Run.state.state_message

    # Determine job/notebook name for title
    $jobName = if ($Run.task.notebook_task) {
        $Run.task.notebook_task.notebook_path
    }
    elseif ($Run.task.spark_python_task) {
        "Python: $($Run.task.spark_python_task.python_file)"
    }
    elseif ($runName) {
        $runName
    }
    else {
        "Job $jobId"
    }

    # Build title
    # $title = "Databricks Job Failed: $jobName"
    $title = "$jobName"

    # Build markdown description
    $runUrl = "$DatabricksHost/#job/$jobId/run/$runId"
    # Build tags with job ID for duplicate detection
    $jobTag = "databricks-job-$runName"
    $allTags = @($jobTag) + $Tags
    $tagsString = $allTags -join ';'

    # Build repro steps with clickable link
    $reproStepsHtml = "<div><a href=`"$runUrl`">$runUrl</a></div>"

    Write-Debug "Creating work item: $title"
    Write-Debug "Area: $AreaPath"
    Write-Debug "Iteration: $IterationPath"
    Write-Debug "Tags: $tagsString"

    # Build command arguments - double backslashes for Windows paths
    # Note: az CLI only accepts ONE --fields argument with space-separated field=value pairs
    $fieldsArray = @(
        "System.Tags=$tagsString"
        "Microsoft.VSTS.TCM.ReproSteps=$reproStepsHtml"
        "Microsoft.VSTS.TCM.SystemInfo=$stateMessage"
    )

    $cmdArgs = @(
        'boards', 'work-item', 'create',
        '--title', $title,
        '--type', $WorkItemType,
        '--org', "https://dev.azure.com/$Organization",
        '--project', $Project,
        '--area', ($AreaPath.Replace('\', '\\')),
        '--fields'
    )

    # Add each field as a separate array element (PowerShell will handle proper quoting)
    $cmdArgs += $fieldsArray

    # Add output format
    $cmdArgs += @('--output', 'json')

    # Add iteration if provided
    if ($IterationPath) {
        $cmdArgs += @('--iteration', ($IterationPath.Replace('\', '\\')))
    }

    # Add assigned-to if provided
    if ($AssignedTo) {
        $cmdArgs += @('--assigned-to', $AssignedTo)
    }

    # Execute command
    $output = & az $cmdArgs 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        throw "Azure DevOps work item creation failed: $output"
    }

    # Parse result
    try {
        $workItem = $output | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse Azure DevOps response: $_"
    }

    # Link to parent work item if provided (must be done after creation)
    if ($ParentWorkItemId) {
        Write-Verbose "Linking work item $($workItem.id) to parent $ParentWorkItemId..."
        $relationOutput = & az boards work-item relation add `
            --id $workItem.id `
            --relation-type 'parent' `
            --target-id $ParentWorkItemId `
            --org "https://dev.azure.com/$Organization" `
            --output json 2>&1 | Out-String

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to link work item to parent: $relationOutput"
        }
    }

    return $workItem
}

# Export only the main function
Set-Alias -Name "crf" -Value New-RunFailures
