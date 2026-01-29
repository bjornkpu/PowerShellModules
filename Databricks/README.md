# Databricks Module

Command-based CLI for Databricks operations including cluster management, package deployment, and workspace authentication.

## Installation

```powershell
Install-Module Databricks -Scope CurrentUser
```

## Configuration

Config file: `~/.config/Databricks/config.json`

```json
{
  "databricks": {
    "host": "https://your-workspace.azuredatabricks.net",
    "accountId": "your.email@company.com",
    "clusterId": "0904-090205-xxxxxx",
    "workspacePath": "C:\\repos\\your-project",
    "defaultPackage": "your-package-name",
    "profile": "DEFAULT",
    "environments": {
      "dev": {
        "profile": "DEFAULT",
        "host": "https://dev-workspace.azuredatabricks.net",
        "clusterId": "0904-090205-xxxxxx"
      },
      "prod": {
        "profile": "PROD",
        "host": "https://prod-workspace.azuredatabricks.net",
        "clusterId": "1234-123456-yyyyyy"
      }
    }
  }
}
```

## Usage

**Alias:** `d`

```powershell
d                              # Show help
d <command> help               # Show command-specific help

# Cluster management
d start                        # Start default cluster
d stop                         # Stop default cluster
d list                         # List all clusters

# Package deployment
d upload                       # Upload package (auto-detects version)
d install                      # Install package on cluster
d upstall                      # Upload and install in one step

# Environment support
d start -Environment prod      # Start production cluster
d upstall -Environment dev     # Deploy to dev environment

# Authentication
d login                        # Authenticate with workspace
d login -Environment prod      # Login to production

# Keep cluster alive
d keep-alive                   # Prevent auto-termination
```

## Commands

| Command | Description |
|---------|-------------|
| `login` | Authenticate with Databricks workspace |
| `start` | Start a cluster |
| `stop` | Stop a cluster |
| `list`, `ls` | List all clusters |
| `upload` | Upload Python package to workspace |
| `install` | Install package on cluster |
| `upstall` | Upload and install in one step |
| `keep-alive` | Keep cluster alive with periodic heartbeat |
| `help` | Show help for commands |

All commands support `-Environment` parameter for multi-environment workflows.
