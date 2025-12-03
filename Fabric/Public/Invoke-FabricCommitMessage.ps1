function Invoke-FabricCommitMessage {
    <#
    .SYNOPSIS
        Generates commit messages using fabric's generate_commit_message pattern

    .DESCRIPTION
        This function reads the git diff from staged files and uses fabric to generate
        10 commit message suggestions following Conventional Commits format.
        Designed to be used with lazygit custom commands.

    .EXAMPLE
        Invoke-FabricCommitMessage

    .EXAMPLE
        fcm
    #>

    [CmdletBinding()]
    [Alias('fcm')]
    param()

    try {
        # Check if fabric is installed
        $fabricCmd = Get-Command fabric -ErrorAction SilentlyContinue
        if (-not $fabricCmd) {
            Write-Error "fabric CLI not found. Install it with: pipx install fabric"
            return
        }

        # Check if we're in a git repository
        $gitCheck = git rev-parse --git-dir 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Not in a git repository."
            return
        }

        # Get the staged diff
        $diff = git diff --cached

        if ([string]::IsNullOrWhiteSpace($diff)) {
            Write-Warning "No staged changes found. Stage some files first with 'git add'."
            return
        }

        # Use fabric with the generate_commit_message pattern
        $commitMessages = $diff | fabric --pattern generate_commit_message

        if ([string]::IsNullOrWhiteSpace($commitMessages)) {
            Write-Error "Failed to generate commit messages"
            return
        }

        # Clean up the output by removing common conversational patterns
        # Split into lines and filter out unwanted content
        $lines = $commitMessages -split "`n" | ForEach-Object {
            $line = $_.Trim()

            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) {
                return
            }

            # Remove numbered list markers (e.g., "1. ", "2. ", etc.)
            $line = $line -replace '^\d+\.\s*', ''

            # Remove backticks if present
            $line = $line -replace '`', ''

            # Re-trim after removals
            $line = $line.Trim()

            # Skip if empty after cleaning
            if ([string]::IsNullOrWhiteSpace($line)) {
                return
            }

            # Only keep lines that look like conventional commits
            if ($line -match '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\(.+?\))?:\s*.+') {
                # Extract only the commit message part (before any " - " explanation)
                if ($line -match '^((?:feat|fix|docs|style|refactor|perf|test|build|ci|chore)(?:\(.+?\))?:\s*[^-]+)(?:\s*-\s*.*)?$') {
                    $matches[1].Trim()
                }
            }
        } | Where-Object { $_ }

        # Output the cleaned commit messages
        if ($lines) {
            Write-Output ($lines -join "`n")
        }
        else {
            Write-Error "No valid commit messages found after filtering"
        }
    }
    catch {
        Write-Error "Error generating commit messages: $_"
    }
}
