function Command-Upstall {
    <#
    .SYNOPSIS
    Upload and install a Python package in one step.

    .DESCRIPTION
    Convenience command that uploads a Python package to workspace and installs it
    on the cluster in a single operation. Equivalent to running 'd upload' followed by 'd install'.

    .PARAMETER Version
    Package version to upload and install (e.g., '1.2.3'). If not specified, reads from pyproject.toml.

    .PARAMETER Environment
    Optional environment name (e.g., 'dev', 'prod'). Uses default configuration if not specified.

    .EXAMPLE
    d upstall
    Uploads and installs package using version from pyproject.toml

    .EXAMPLE
    d upstall -Version 1.2.3
    Uploads and installs version 1.2.3

    .EXAMPLE
    d upstall -Version 1.2.3 -Environment prod
    Uploads and installs version 1.2.3 to production

    .NOTES
    This is the most common workflow for deploying package updates.
    The .whl file must exist in the dist/ directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Version,

        [Parameter()]
        [string]$Environment
    )

    # Build parameters for delegation
    $params = @{}
    if ($Version) { $params.Version = $Version }
    if ($Environment) { $params.Environment = $Environment }

    # Upload then install
    Command-Upload @params
    Command-Install @params
}
