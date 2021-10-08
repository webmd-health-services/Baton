
function Export-Configuration
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object] $Configuration,

        [Parameter(Mandatory)]
        [String] $LiteralPath
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        $Configuration |
            ConvertTo-Json -Depth 100 |
            Set-Content -LiteralPath $LiteralPath
    }
}
