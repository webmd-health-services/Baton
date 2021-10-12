
function Write-Error
{
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