---
applyTo: "**"
---

# PowerShell Modules - Project Instructions

## Vision

Create a maintainable, config-driven PowerShell module ecosystem that is:

- **100% Open Source** - No hardcoded credentials, paths, or company-specific data
- **Config-Driven** - All personalization through JSON configs in `~/.config/{Module}/`
- **Low Maintenance** - Automated versioning, minimal manual work
- **User-Friendly** - Interactive setup, sensible defaults, helpful error messages
- **Performance-Conscious** - Fast loading, lazy validation, module-scoped caching

## Core Principles

### 1. Configuration Over Code

- **Never hardcode** credentials, API keys, hostnames, file paths, or company-specific values
- All sensitive/personal data goes in `~/.config/{Module}/config.json`
- Provide `config.example.json` with realistic placeholders (e.g., `https://your-workspace.azuredatabricks.net`)
- Use JSON Schema validation to catch configuration errors early

### 2. Open Source First

- Assume all code will be public on GitHub and PowerShell Gallery
- Design for reusability across different environments and organizations
- Document configuration requirements clearly
- Use placeholder patterns like `<placeholder>` that get validated and rejected

### 3. Lazy Initialization

- **Don't validate configs on module import** - this blocks terminal startup
- Validate on first function call instead
- Use module-scoped caching (`$script:config`) to avoid repeated file reads
- Keep imports fast - users shouldn't wait for modules they don't use

### 4. Automation & DRY

- Publish modules to PowerShell Gallery for easy installation
- Automated version management through Git tags
- Shared module provides common utilities (don't duplicate config logic)
- Use `RequiredModules` in manifests for automatic dependency loading
- Minimize manual steps in development workflow

### 5. PowerShell Gallery Publishing

- All modules published to PowerShell Gallery for `Install-Module` support
- Users install with: `Install-Module ModuleName -Scope CurrentUser`
- Semantic versioning enforced (MAJOR.MINOR.PATCH)
- Module manifests include all required metadata (Author, Description, ProjectUri, LicenseUri, Tags)

## Architecture Guidelines

### Module Structure

```
ModuleName/
├── ModuleName.psd1           # Manifest with metadata, RequiredModules
├── ModuleName.psm1           # Loader (dot-sources Public/*.ps1)
├── Public/                   # Exported functions (one per file)
│   ├── Verb-Noun.ps1        # Follow PowerShell naming conventions
│   └── ...
├── Schemas/                  # JSON schemas (if module uses config)
│   └── config.schema.json   # Draft-07 with placeholder validation
└── config.example.json       # Example config with placeholders
```

### Configuration System

#### Location

- User configs: `$env:USERPROFILE\.config\{ModuleName}\config.json`
- Example configs: In module root as `config.example.json`
- Schemas: In `Schemas/config.schema.json`

#### Validation Pattern

```powershell
function Get-Something {
    [CmdletBinding()]
    param()

    # Lazy load and validate config on first use
    if (-not $script:config) {
        $script:config = Get-ModuleConfig -ModuleName 'YourModule'
    }

    # Use config values
    $script:config.someValue
}
```

#### Placeholder Rejection

All string fields in schemas should reject placeholder patterns:

```json
{
  "type": "string",
  "pattern": "^(?!<).*(?<!>)$",
  "description": "Description (e.g., example-value)"
}
```

#### Interactive Setup

- First function call detects missing/invalid config
- Prompts user interactively with defaults from `config.example.json`
- Uses `Test-ConfigSchema` to validate before saving
- Provides clear error messages with remediation steps

### Shared Module

The `Shared` module provides common utilities - always use these instead of duplicating:

- **Get-ModuleConfig** - Loads, validates, and caches config
- **Test-ConfigSchema** - JSON schema validation + placeholder detection
- **Initialize-ModuleConfig** - Interactive config setup
- **Reset-ModuleConfig** - Delete and reinitialize config

Add `RequiredModules = @('Shared')` to your manifest to auto-import.

### Versioning Workflow

1. **Development** - Make changes, test locally
2. **Commit** - `git add .` and `git commit -m "description"`
3. **Tag** - `git tag v1.2.3` (semantic versioning)
4. **Push** - `git push --tags` triggers pre-push hook
5. **Automatic** - Hook updates all `.psd1` ModuleVersion fields and stages changes
6. **Publish** - Run `Publish-ModuleToGallery.ps1 -ModuleName YourModule` to publish to PowerShell Gallery

Never manually edit `ModuleVersion` in manifests - let Git handle it.

### Publishing to PowerShell Gallery

#### Prerequisites

- PowerShell Gallery API key (get from https://www.powershellgallery.com/account/apikeys)
- Module manifest with required metadata:
  - `Author`
  - `Description`
  - `ProjectUri` (GitHub repo URL)
  - `LicenseUri` (GitHub license URL)
  - `Tags` (searchability keywords)

#### Publishing Process

```powershell
# One-time: Set API key (stored securely)
$apiKey = Read-Host -AsSecureString "Enter PowerShell Gallery API Key"
$apiKey | ConvertFrom-SecureString | Out-File "$env:USERPROFILE\.psgallery-apikey"

# Publish a module
.\Publish-ModuleToGallery.ps1 -ModuleName WireGuard

# Or publish with explicit version
.\Publish-ModuleToGallery.ps1 -ModuleName WireGuard -Version 1.0.0
```

#### Installation by Users

Users can then install your modules with:

```powershell
# Install a module
Install-Module WireGuard -Scope CurrentUser

# Update a module
Update-Module WireGuard

# List installed modules
Get-InstalledModule | Where-Object Author -eq 'YourName'
```

#### Module Metadata Template

All manifests should include:

```powershell
@{
    ModuleVersion = '1.0.0'  # Auto-updated by Git hooks
    Author = 'Your Name'
    CompanyName = 'Personal'
    Copyright = '(c) 2025 Your Name. All rights reserved.'
    Description = 'Brief description of what the module does'

    # Gallery metadata
    PrivateData = @{
        PSData = @{
            Tags = @('tag1', 'tag2', 'automation')
            LicenseUri = 'https://github.com/yourusername/PowerShellModules/blob/main/LICENSE'
            ProjectUri = 'https://github.com/yourusername/PowerShellModules'
            ReleaseNotes = 'Initial release'
        }
    }

    # Dependencies
    RequiredModules = @('Shared')

    # Exports
    FunctionsToExport = @('Verb-Noun')
    AliasesToExport = @('alias')
}
```

### Function Guidelines

#### Naming

- Use approved PowerShell verbs: `Get-`, `Set-`, `Start-`, `Stop-`, `Invoke-`, etc.
- Noun should be module-specific: `Start-WireGuardTunnel`, not `Start-Tunnel`
- Check verb approval: `Get-Verb | Where-Object Verb -eq 'YourVerb'`

#### Aliases

- Provide short aliases for frequently used commands
- Define in function: `[Alias('shortalias')]`
- Export in manifest: `AliasesToExport = @('shortalias')`
- Examples: `sd` (Start-Project), `ef` (Format-PythonError), `j2p` (Convert-JsonToSparkSchema)

#### Parameters

- Use `[CmdletBinding()]` for advanced function features
- Use proper parameter validation: `[ValidateNotNullOrEmpty()]`, `[ValidateSet()]`
- Support pipeline where appropriate: `[Parameter(ValueFromPipeline)]`
- Provide sensible defaults from config when possible

#### Error Handling

- Use `try/catch` for external commands that might fail
- Provide helpful error messages with remediation steps
- Example: "WireGuard executable not found at {path}. Update config with: Reset-ModuleConfig -ModuleName WireGuard"

#### Output

- Use `Write-Host` for user messages (colored output OK)
- Use `Write-Verbose` for debug info (user can enable with `-Verbose`)
- Return objects when function is meant to be used in pipeline
- Use `Write-Warning` for non-fatal issues

### Development Mode

Enable live reload during development:

```powershell
$env:PS_DEV_MODE = $true
. $PROFILE  # Modules now import with -Force
```

This allows testing changes without restarting PowerShell.

### Dependencies

#### External Tools

- Document external dependencies in module README
- Provide clear installation instructions
- Check for tools before using: `Get-Command tool -ErrorAction SilentlyContinue`
- Give helpful error if tool missing

Examples:

- **Databricks** module requires: `databricks` CLI, `poetry`, Python
- **WireGuard** module requires: `wireguard` installed, `sc.exe` (Windows service control)
- **SparkSchema** module requires: Python with `pyspark` package

#### Module Dependencies

- Use `RequiredModules` in manifest for PowerShell module deps
- Always require `Shared` if using config system
- Version pins optional but recommended for stability

## Testing Checklist

Before committing new modules or major changes:

- [ ] Fresh PowerShell session loads module without errors
- [ ] First-run config initialization works (prompts, defaults, validation)
- [ ] Config with placeholders gets rejected with clear error
- [ ] Valid config passes validation
- [ ] All exported functions work as expected
- [ ] Aliases are exported and functional
- [ ] Error messages are helpful and actionable
- [ ] External tool dependencies are documented
- [ ] `README.md` updated with module documentation
- [ ] `config.example.json` has realistic placeholders
- [ ] Schema includes placeholder pattern validation
- [ ] No hardcoded credentials, paths, or company-specific data

## Common Patterns

### Config-Driven Command Wrapper

```powershell
function Invoke-SomeTool {
    [CmdletBinding()]
    [Alias('shortalias')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('command1', 'command2')]
        [string]$Command
    )

    if (-not $script:config) {
        $script:config = Get-ModuleConfig -ModuleName 'YourModule'
    }

    $toolPath = $script:config.toolPath
    $defaultValue = $script:config.defaultValue

    & $toolPath $Command $defaultValue
}
```

### Elevated Execution Check

```powershell
function Start-SomethingElevated {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Warning "This command requires administrator privileges"
        return
    }

    # Elevated code here
}
```

### Interactive Selection

```powershell
function Select-Something {
    param([array]$Items)

    for ($i = 0; $i -lt $Items.Count; $i++) {
        Write-Host "$($i + 1). $($Items[$i])"
    }

    $selection = Read-Host "Select (1-$($Items.Count))"
    $Items[[int]$selection - 1]
}
```

### Fuzzy Matching

```powershell
function Find-Match {
    param(
        [string]$Input,
        [array]$Candidates
    )

    # Exact match
    $exact = $Candidates | Where-Object { $_ -eq $Input }
    if ($exact) { return $exact }

    # Prefix match
    $prefix = $Candidates | Where-Object { $_ -like "$Input*" }
    if ($prefix.Count -eq 1) { return $prefix[0] }

    # Fuzzy match
    $fuzzy = $Candidates | Where-Object { $_ -like "*$Input*" }
    if ($fuzzy.Count -eq 1) { return $fuzzy[0] }

    # Multiple or no matches
    return $null
}
```

## Anti-Patterns to Avoid

### ❌ Don't Do This

```powershell
# Hardcoded paths
$configPath = "C:\Users\username\config.json"

# Hardcoded credentials
$apiKey = "sk-1234567890abcdef"

# Company-specific values
$databricksHost = "https://enova.azuredatabricks.net"

# Validating on import
if (-not (Test-Path $configPath)) {
    throw "Config not found"  # Blocks terminal startup!
}

# Duplicating config logic
$configPath = "$env:USERPROFILE\.config\MyModule\config.json"
$config = Get-Content $configPath | ConvertFrom-Json
# Use Get-ModuleConfig instead!
```

### ✅ Do This Instead

```powershell
# Config-driven paths
if (-not $script:config) {
    $script:config = Get-ModuleConfig -ModuleName 'MyModule'
}
$configPath = $script:config.customPath

# Config-driven credentials
$apiKey = $script:config.apiKey

# Config-driven endpoints
$databricksHost = $script:config.databricksHost

# Lazy validation (on function call)
function Use-Config {
    if (-not $script:config) {
        $script:config = Get-ModuleConfig -ModuleName 'MyModule'
        # Get-ModuleConfig handles validation, prompting, etc.
    }
}

# Reuse shared utilities
$script:config = Get-ModuleConfig -ModuleName 'MyModule'
```

## Troubleshooting

### Module Not Found

```powershell
# Verify module path
$env:PSModulePath -split ';'

# Should include: C:\Users\{username}\PowerShellModules
```

### Config Issues

```powershell
# Reset config interactively
Reset-ModuleConfig -ModuleName 'WireGuard'

# Validate existing config
Test-ConfigSchema -ConfigPath "~/.config/WireGuard/config.json" -SchemaPath "path/to/schema.json"
```

### Version Not Updating

```powershell
# Ensure hook is installed
.\Install-GitHooks.ps1

# Manually update version (testing only)
git tag v1.0.0
.\.githooks\pre-push
```

## Contributing Guidelines

When adding new modules:

1. **Plan first** - What's the purpose? What config is needed? What functions?
2. **Use templates** - Copy structure from existing modules (WireGuard is a good template)
3. **Config-driven** - No hardcoded values, everything in config
4. **Schema validation** - Include placeholder pattern validation
5. **Example config** - Realistic placeholders users can understand
6. **Shared utilities** - Don't reinvent Get-ModuleConfig, use Shared module
7. **Documentation** - Update README.md with module description, config example, usage
8. **Test thoroughly** - Fresh session, first-run experience, error cases

## Questions to Ask Before Coding

1. **Does this need config?** If yes, what values? Can they be open-sourced?
2. **What's the user experience?** How do they discover this? What's the most common use case?
3. **What can fail?** External tools? Network? Permissions? How do we handle it?
4. **Is this reusable?** Can someone else use this in a different company/environment?
5. **Am I duplicating code?** Is there something in Shared module I should use?
6. **What's the naming?** Approved verb? Module-specific noun? Good alias?

## Success Metrics

A good module should:

- ✅ Load in < 50ms (use `Measure-Command { Import-Module ModuleName }`)
- ✅ Work on first try after config setup
- ✅ Give clear errors with remediation steps
- ✅ Have zero hardcoded secrets/paths/company data
- ✅ Work for someone else who clones the repo (with their config)
- ✅ Require minimal maintenance (automated versioning, no manual updates)

---

## Philosophy

> "Configuration is for values that change. Code is for logic that doesn't."

> "If you can't open-source it, it belongs in a config file."

> "The best module is one you forget exists - it just works."

These principles guide every decision in this project. When in doubt, choose the path that:

1. Keeps code generic and reusable
2. Minimizes maintenance burden
3. Improves user experience
4. Enables open-source collaboration
