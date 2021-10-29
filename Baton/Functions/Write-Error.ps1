
function Write-Error
{
    <#
    .SYNOPSIS
    ***INTERNAL***. Do not use.
    .DESCRIPTION
    ***INTERNAL***. Do not use.
    .EXAMPLE
    ***INTERNAL***. Do not use.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Message,

        [Object] $Configuration
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if( $Configuration -and $Configuration.Path )
    {
        $sourcePrefix = $Configuration.Path | Resolve-Path -Relative -ErrorAction Ignore
        if( $sourcePrefix )
        {
            $Message = "$($sourcePrefix): $($Message)"
        }
    }

    Microsoft.PowerShell.Utility\Write-Error -Message $Message -ErrorAction $ErrorActionPreference
}
