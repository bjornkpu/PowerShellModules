function Start-Project {
    <#
    .SYNOPSIS
    Navigates to a project component and auto-starts it.

    .DESCRIPTION
    Uses fuzzy matching to find project and component, navigates to the directory,
    runs setup commands, and starts the component automatically.

    .PARAMETER Project
    Project name or prefix (fuzzy matched)

    .PARAMETER Component
    Component name or prefix (fuzzy matched)

    .PARAMETER List
    Show all available projects and components

    .EXAMPLE
    Start-Project calculator frontend

    .EXAMPLE
    sd c f    # Short form with fuzzy matching

    .EXAMPLE
    sd -List  # Show all projects
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$Project,

        [Parameter(Position = 1)]
        [string]$Component,

        [switch]$List
    )

    # Load config
    if (-not $script:ProjectConfig) {
        $configData = Get-ModuleConfig -ModuleName 'ProjectManager' `
            -SchemaPath "$PSScriptRoot/../Schemas/config.schema.json" `
            -ExampleConfigPath "$PSScriptRoot/../config.example.json"
        $script:ProjectConfig = $configData
    }

    # Show available projects/components
    if (-not $Project -or $List) {
        Show-Projects
        return
    }

    # Try to find matching project using fuzzy search
    $projectNames = @($script:ProjectConfig.PSObject.Properties.Name)
    $matchedProject = Find-FuzzyMatch -Prefix $Project -Items $projectNames

    if ($null -eq $matchedProject) {
        Write-Host "❌ No project found starting with '$Project'" -ForegroundColor Red
        Write-Host "Available projects:" -ForegroundColor Yellow
        $projectNames | ForEach-Object { Write-Host "  • $_" -ForegroundColor White }
        return
    }

    if ($matchedProject -is [array]) {
        Write-Host "❌ Multiple projects match '$Project'. Please be more specific:" -ForegroundColor Red
        $matchedProject | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow }
        return
    }

    $projectData = $script:ProjectConfig.$matchedProject

    # Try to find matching component using fuzzy search
    $componentNames = @($projectData.Components.PSObject.Properties.Name)
    $matchedComponent = Find-FuzzyMatch -Prefix $Component -Items $componentNames

    if ($null -eq $matchedComponent) {
        Write-Host "❌ No component found starting with '$Component' in project '$matchedProject'" -ForegroundColor Red
        Write-Host "Available components for '$matchedProject':" -ForegroundColor Yellow
        foreach ($compName in $componentNames) {
            $compData = $projectData.Components.$compName
            Write-Host "  $($compData.Icon) $compName - $($compData.Description)" -ForegroundColor White
        }
        return
    }

    if ($matchedComponent -is [array]) {
        Write-Host "❌ Multiple components match '$Component' in project '$matchedProject'. Please be more specific:" -ForegroundColor Red
        $matchedComponent | ForEach-Object {
            $compData = $projectData.Components.$_
            Write-Host "  $($compData.Icon) $_ - $($compData.Description)" -ForegroundColor Yellow
        }
        return
    }

    # Navigate and start the component
    Start-ProjectComponent -Project $matchedProject -Component $matchedComponent
}

# Helper function for fuzzy matching
function Find-FuzzyMatch {
    param (
        [string]$Prefix,
        [array]$Items
    )

    if (-not $Prefix) {
        return $null
    }

    $matchedItems = @($Items | Where-Object { $_ -like "$Prefix*" })

    if ($matchedItems.Count -eq 0) {
        return $null
    }
    elseif ($matchedItems.Count -eq 1) {
        return $matchedItems[0]
    }
    else {
        return $matchedItems
    }
}

Set-Alias -Name "sd" -Value Start-Project
