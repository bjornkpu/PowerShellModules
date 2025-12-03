function Start-ProjectComponent {
    <#
    .SYNOPSIS
    Core function to navigate, setup, and start a project component.

    .DESCRIPTION
    Handles navigation to component directory, running setup commands,
    and executing the start command.

    .PARAMETER Project
    Exact project name

    .PARAMETER Component
    Exact component name

    .EXAMPLE
    Start-ProjectComponent -Project 'calculator' -Component 'frontend'
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter(Mandatory)]
        [string]$Component
    )

    # Load config if not cached
    if (-not $script:ProjectConfig) {
        $configData = Get-ModuleConfig -ModuleName 'ProjectManager' `
            -SchemaPath "$PSScriptRoot/../Schemas/config.schema.json" `
            -ExampleConfigPath "$PSScriptRoot/../config.example.json"
        $script:ProjectConfig = $configData
    }

    $projectData = $script:ProjectConfig.$Project
    $componentData = $projectData.Components.$Component

    $basePath = $projectData.BasePath
    $componentPath = Join-Path $basePath $componentData.Path

    # Validate paths exist
    if (-not (Test-Path $basePath)) {
        Write-Error "❌ Project base path does not exist: $basePath"
        return
    }

    if (-not (Test-Path $componentPath)) {
        Write-Error "❌ Component path does not exist: $componentPath"
        return
    }

    # Navigate to component directory
    Set-Location $componentPath

    # Display component info
    $icon = if ($componentData.Icon) { $componentData.Icon } else { "📦" }
    $color = if ($componentData.Color) { $componentData.Color } else { "White" }

    Write-Host "$icon $Project → $Component" -ForegroundColor $color
    Write-Host "📁 $componentPath" -ForegroundColor Gray
    Write-Host "📝 $($componentData.Description)" -ForegroundColor White

    # Run setup commands
    if ($componentData.SetupCommands -and $componentData.SetupCommands.Count -gt 0) {
        Write-Host "`n🔧 Running setup..." -ForegroundColor Yellow
        foreach ($setupCmd in $componentData.SetupCommands) {
            if ($setupCmd.Trim()) {
                Write-Host "▶ $setupCmd" -ForegroundColor Gray
                Invoke-Expression $setupCmd
            }
        }
    }

    # Auto-start the component
    Write-Host "`n🚀 Starting component..." -ForegroundColor Green
    Write-Host "▶ $($componentData.StartCommand)" -ForegroundColor Gray
    Invoke-Expression $componentData.StartCommand
}
