function Command-List {
    <#
    .SYNOPSIS
    List personal Databricks clusters.

    .DESCRIPTION
    Displays a list of personal clusters in the configured Databricks workspace.
    Automatically filters out job clusters. Supports filtering by state.

    .PARAMETER Environment
    Optional environment name (e.g., 'dev', 'prod'). Uses default configuration if not specified.

    .PARAMETER State
    Filter clusters by state: 'Running', 'Terminated', or 'All' (default: All)

    .EXAMPLE
    d list
    Lists all personal clusters (both running and terminated)

    .EXAMPLE
    d ls -State Running
    Lists only running personal clusters

    .EXAMPLE
    d list -State Terminated
    Lists only terminated personal clusters

    .EXAMPLE
    d list -Environment prod -State Running
    Lists running clusters in production workspace

    .NOTES
    Automatically excludes job clusters (cluster_source = "JOB").
    Only shows personal/interactive clusters (cluster_source = "UI").
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Environment,

        [Parameter()]
        [ValidateSet('Running', 'Terminated', 'All')]
        [string]$State = 'All'
    )

    $config = Get-ModuleConfig -ModuleName 'Databricks' `
        -SchemaPath "$PSScriptRoot/../config.schema.json" `
        -ExampleConfigPath "$PSScriptRoot/../config.example.json"

    $dbConfig = $config.databricks
    $envConfig = Get-EnvironmentConfig -Config $dbConfig -Environment $Environment

    Write-Host "Listing personal clusters..." -ForegroundColor Cyan
    
    # Get clusters as JSON and filter
    $clusters = databricks clusters list -p $envConfig.profile --output json | ConvertFrom-Json
    
    # Filter to only personal clusters (exclude job clusters)
    $personalClusters = $clusters | Where-Object { $_.cluster_source -eq 'UI' }
    
    # Apply state filter if specified
    if ($State -ne 'All') {
        $personalClusters = $personalClusters | Where-Object { $_.state -eq $State.ToUpper() }
    }
    
    # Sort by state (RUNNING first) then by cluster_name
    $personalClusters = $personalClusters | Sort-Object @{Expression = { $_.state -eq 'RUNNING' }; Descending = $true }, cluster_name
    
    if ($personalClusters.Count -eq 0) {
        Write-Host "No personal clusters found." -ForegroundColor Yellow
        return
    }
    
    # Display formatted output
    $personalClusters | Format-Table @{
        Label      = 'ID'
        Expression = { $_.cluster_id }
        Width      = 22
    }, @{
        Label      = 'Name'
        Expression = { $_.cluster_name }
        Width      = 50
    }, @{
        Label      = 'State'
        Expression = { $_.state }
    } -AutoSize
}
