function Show-Projects {
    <#
    .SYNOPSIS
    Displays all available projects and their components.

    .DESCRIPTION
    Shows a formatted list of all configured projects and components
    with their descriptions and usage instructions.

    .EXAMPLE
    Show-Projects

    .EXAMPLE
    sdl   # Alias
    #>
    [CmdletBinding()]
    param()

    # Load config if not cached
    if (-not $script:ProjectConfig) {
        $configData = Get-ModuleConfig -ModuleName 'ProjectManager' `
            -SchemaPath "$PSScriptRoot/../Schemas/config.schema.json" `
            -ExampleConfigPath "$PSScriptRoot/../config.example.json"
        $script:ProjectConfig = $configData
    }

    $projectNames = @($script:ProjectConfig.PSObject.Properties.Name)

    if ($projectNames.Count -eq 0) {
        Write-Host "⚠️ No projects configured. Please check your config file." -ForegroundColor Yellow
        return
    }

    Write-Host "📋 Available Projects and Components" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Green

    foreach ($projectName in $projectNames) {
        $project = $script:ProjectConfig.$projectName
        Write-Host "`n🚀 $projectName" -ForegroundColor Yellow
        Write-Host "   📁 $($project.BasePath)" -ForegroundColor Gray

        $componentNames = @($project.Components.PSObject.Properties.Name)
        foreach ($componentName in $componentNames) {
            $component = $project.Components.$componentName
            $icon = if ($component.Icon) { $component.Icon } else { "📦" }
            $color = if ($component.Color) { $component.Color } else { "White" }
            Write-Host "   $icon $componentName - $($component.Description)" -ForegroundColor $color
        }
    }

    Write-Host "`n💡 Usage:" -ForegroundColor Cyan
    Write-Host "   Start-Project <project> <component>     # Navigate, setup & auto-start" -ForegroundColor White
    Write-Host "   sd <project-prefix> <comp-prefix>       # Short form with fuzzy matching" -ForegroundColor White
    Write-Host "`n📝 Examples:" -ForegroundColor Cyan
    Write-Host "   sd my-project frontend    # Full names" -ForegroundColor Gray
    Write-Host "   sd my f                   # Fuzzy matching" -ForegroundColor Gray
}

Set-Alias -Name "sdl" -Value Show-Projects
