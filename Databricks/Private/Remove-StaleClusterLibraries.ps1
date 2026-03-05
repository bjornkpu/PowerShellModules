function Remove-StaleClusterLibraries {
    <#
    .SYNOPSIS
    Remove stale mimir bundle libraries from a cluster before startup.

    .DESCRIPTION
    Queries the cluster for installed libraries, filters to only those deployed by the
    Databricks Asset Bundle (/.bundle/mimir/ path), and uninstalls them. This prevents
    cluster startup from installing multiple accumulated historical versions of the mimir wheel.

    .PARAMETER ClusterId
    The Databricks cluster ID to clean up libraries from.

    .PARAMETER DatabricksProfile
    The Databricks CLI profile name to use for authentication.

    .EXAMPLE
    Remove-StaleClusterLibraries -ClusterId "0904-090205-xyz123" -DatabricksProfile "development"
    Uninstalls all /.bundle/mimir/ libraries from the cluster.

    .NOTES
    This function is called by Command-Start to prevent library accumulation on personal clusters.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ClusterId,

        [Parameter(Mandatory)]
        [string]$DatabricksProfile
    )

    try {
        # Get current library status on cluster
        Write-Host "Checking for stale mimir bundle libraries..." -ForegroundColor Gray
        $responseJson = databricks libraries cluster-status $ClusterId -o json -p $DatabricksProfile 2>&1 | Out-String

        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error querying cluster libraries: $responseJson" -ForegroundColor Red
            return
        }

        # Parse JSON array of library statuses
        $libraryStatuses = @($responseJson | ConvertFrom-Json -ErrorAction Stop)

        # Filter to only .bundle/mimir/ libraries (DAB-deployed artifacts)
        $staleLibraries = @($libraryStatuses |
            Where-Object { $_.library.whl -and $_.library.whl -like "*/.bundle/mimir/*" })

        # If no stale libraries, exit silently
        if ($staleLibraries.Count -eq 0) {
            Write-Host "No stale mimir libraries found." -ForegroundColor Green
            return
        }

        # Build uninstall payload
        $uninstallPayload = @{
            cluster_id = $ClusterId
            libraries  = @($staleLibraries | ForEach-Object { @{ whl = $_.library.whl } })
        } | ConvertTo-Json -Depth 3

        # Uninstall the libraries
        Write-Host "Uninstalling $($staleLibraries.Count) stale mimir bundle libraries..." -ForegroundColor Yellow
        databricks libraries uninstall $ClusterId -p $DatabricksProfile --json $uninstallPayload | Out-Null

        Write-Host "Stale libraries removed successfully." -ForegroundColor Green
    }
    catch {
        # Silently continue if libraries cleanup fails (e.g., cluster already terminated)
        # This prevents startup from failing due to library cleanup issues
        Write-Verbose "Library cleanup encountered an error: $_"
    }
}
