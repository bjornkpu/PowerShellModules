function Invoke-DatabricksCommand {
    <#
    .SYNOPSIS
    Command-based CLI for Databricks operations.

    .DESCRIPTION
    Provides a command-based interface for common Databricks operations including cluster management,
    package deployment, and workspace authentication. Each command supports environment-specific
    configuration through the -Environment parameter.

    AVAILABLE COMMANDS
      login                 Authenticate with Databricks workspace
      start                 Start a Databricks cluster
      stop                  Stop a Databricks cluster
      list, ls              List all clusters in workspace
      cleanup-libraries     Remove stale mimir bundle libraries from cluster
      upload                Upload Python package to workspace
      install               Install package on cluster
      upstall               Upload and install in one step
      keep-alive            Keep cluster alive with periodic heartbeat

    .PARAMETER Command
    The command to execute. See AVAILABLE COMMANDS for details.

    .PARAMETER Rest
    Additional arguments passed to the command. Use 'd <command> help' for command-specific parameters.

    .EXAMPLE
    d
    Shows this help message

    .EXAMPLE
    d upload help
    Shows detailed help for the upload command

    .EXAMPLE
    d login
    Authenticates with default Databricks workspace

    .EXAMPLE
    d start -Environment prod
    Starts the production cluster

    .EXAMPLE
    d upload -Version 1.2.3
    Uploads version 1.2.3 of the package

    .EXAMPLE
    d upstall -Environment dev
    Uploads and installs package to dev environment

    .NOTES
    This is a command dispatcher that routes to individual command handler functions.
    All commands support the -Environment parameter for multi-environment workflows.
    Package-related commands (upload, install, upstall) auto-detect version from pyproject.toml.

    Use 'd help <command>' to see detailed help for each command.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $commands = @('login', 'start', 'stop', 'list', 'ls', 'cleanup-libraries', 'upload', 'install', 'upstall', 'keep-alive')
                $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { $_ }
            })]
        [ValidateSet('login', 'start', 'stop', 'list', 'ls', 'cleanup-libraries', 'upload', 'install', 'upstall', 'keep-alive')]
        [string]$Command,

        [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
        $Rest
    )

    # Show help if no command specified
    if (-not $Command) {
        Command-Help
        return
    }

    # Check if help is requested for this command (e.g., "d upload help")
    if ($Rest -and $Rest[0] -in @('help', '-?', '--help', '?')) {
        Command-Help -CommandName $Command
        return
    }

    # Convert $Rest array to proper splatting hashtable for named parameters
    $params = @{}
    for ($i = 0; $i -lt $Rest.Count; $i++) {
        if ($Rest[$i] -is [string] -and $Rest[$i].StartsWith('-')) {
            $paramName = $Rest[$i].TrimStart('-')
            if ($i + 1 -lt $Rest.Count -and -not $Rest[$i + 1].StartsWith('-')) {
                $params[$paramName] = $Rest[$i + 1]
                $i++ # Skip the value
            }
            else {
                $params[$paramName] = $true # Switch parameter
            }
        }
    }

    # Dispatch to command handlers
    switch ($Command) {
        'login' { Command-Login @params }
        'start' { Command-Start @params }
        'stop' { Command-Stop @params }
        { $_ -in @('list', 'ls') } { Command-List @params }
        'cleanup-libraries' { Command-CleanupLibraries @params }
        'upload' { Command-Upload @params }
        'install' { Command-Install @params }
        'upstall' { Command-Upstall @params }
        'keep-alive' { Command-KeepAlive @params }
    }
}

Set-Alias -Name "d" -Value Invoke-DatabricksCommand
