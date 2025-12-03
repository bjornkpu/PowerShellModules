# Aspire Module

PowerShell module for managing .NET Aspire Dashboard containers with Docker or Podman.

## Overview

The .NET Aspire Dashboard provides observability features for distributed applications. This module simplifies starting and stopping the dashboard container with configurable settings.

## Prerequisites

- PowerShell 7.4+
- Docker or Podman installed
- Shared module (automatically installed as dependency)

## Installation

```powershell
# Or import manually if developing
Import-Module .\Aspire
```

## Configuration

On first use, you'll be prompted to create a configuration file at `~/.config/Aspire/config.json`.

### Configuration Options

```json
{
    "aspire": {
        "containerRuntime": "podman",
        "dashboardPort": 18888,
        "otlpPort": 4317,
        "openBrowser": true,
        "containerName": "aspire-dashboard",
        "image": "mcr.microsoft.com/dotnet/aspire-dashboard:latest"
    }
}
```

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `containerRuntime` | string | `"podman"` | Container runtime to use (`"docker"` or `"podman"`) |
| `dashboardPort` | integer | `18888` | Port for the dashboard web interface |
| `otlpPort` | integer | `4317` | Port for OpenTelemetry Protocol endpoint |
| `openBrowser` | boolean | `true` | Automatically open browser when starting |
| `containerName` | string | `"aspire-dashboard"` | Name for the container |
| `image` | string | `"mcr.microsoft.com/dotnet/aspire-dashboard:latest"` | Docker image to use |

### Managing Configuration

```powershell
# Reset configuration (interactive setup)
Reset-ModuleConfig -ModuleName Aspire

# Manually edit config
code ~/.config/Aspire/config.json
```

## Functions

### Start-AspireDashboard

Starts the Aspire Dashboard container.

**Aliases:** `dashboard`, `dashboard-start`

**Features:**

- Checks if container is already running
- Automatically extracts and displays login URL
- Opens browser automatically (if configured)
- Supports both Docker and Podman

**Usage:**

```powershell
# Start dashboard
Start-AspireDashboard

# Or use aliases
dashboard
dashboard-start
```

**Output:**

```shell
🚀 Starting Aspire Dashboard...
   Container Runtime: podman
   Dashboard Port: 18888
   OTLP Port: 4317
✓ Dashboard started successfully!
Dashboard URL: http://localhost:18888/login?t=abc123...
Opening dashboard in browser...
```

### Stop-AspireDashboard

Stops the running Aspire Dashboard container.

**Alias:** `dashboard-stop`

**Usage:**

```powershell
# Stop dashboard
Stop-AspireDashboard

# Or use alias
dashboard-stop
```

**Output:**

```shell
🛑 Stopping Aspire Dashboard...
✓ Dashboard stopped successfully
```

## Use Cases

### Development Workflow

```powershell
# Start your Aspire dashboard
dashboard

# Work on your application with telemetry

# Stop when done
dashboard-stop
```

### Docker vs Podman

Switch between runtimes by updating your config:

```powershell
# Edit config to use Docker instead of Podman
Reset-ModuleConfig -ModuleName Aspire
# Select "docker" when prompted
```

## Troubleshooting

### Container Runtime Not Found

```shell
Error: podman not found. Install it or update your config
```

**Solution:** Install the container runtime or switch to another:

```powershell
# Install Podman
winget install RedHat.Podman

# Or switch to Docker
Reset-ModuleConfig -ModuleName Aspire
```

### Port Already in Use

```shell
Error: Failed to start Aspire Dashboard container
```

**Solution:** Check if ports are already in use:

```powershell
# Check what's using port 18888
netstat -ano | findstr :18888

# Change port in config
Reset-ModuleConfig -ModuleName Aspire
```

### Container Already Running

The module automatically detects running containers and retrieves the login URL instead of trying to start a new one.

## Learn More

- [.NET Aspire Documentation](https://learn.microsoft.com/dotnet/aspire/)
- [Aspire Dashboard GitHub](https://github.com/dotnet/aspire)
- [OpenTelemetry Protocol](https://opentelemetry.io/docs/specs/otlp/)

## Dependencies

- **Shared** module (v0.1.0+) - Provides config management utilities

## License

See repository LICENSE file.
