
function Export-Configuration
{
    <#
    .SYNOPSIS
    Exports a Baton configuration object to a file.

    .DESCRIPTION
    The `Export-CfgConfiguration` function exports a Baton configuration object to a file. The object is converted to
    JSON. Pipe the configuration to function or pass it to the `Configuration` parameter. Pass the path where the 
    configuration should be saved to the `LiteralPath` parameter. The contents of the file will be overwritten.

    .EXAMPLE
    $config | Export-CfgConfiguration -LiteralPath 'C:\Projects\Baton\baton.json'

    Demonstrates how to save a Baton configuration by piping the configuration object to `Export-CfgConfiguration`.

    .EXAMPLE
    Export-CfgConfiguration -Configuration $config -LiteralPath '~/projects/Baton/baton.json'

    Demonstrates how to save a Baton configuration by passing the configuration object to the `Configuration`
    parameter.
    #>
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

        $cfgToExport = $Configuration | Select-Object -Property '*' -ExcludeProperty 'Path', 'ConfigurationRoot'
        $cfgToExport.Environments = [Object[]]($cfgToExport.Environments | Sort-Object -Property { $_.Name })
        if( -not $cfgToExport.Environments )
        {
            $cfgToExport.Environments = @()
        }

        foreach( $env in $cfgToExport.Environments )
        {
            $env.Vaults = [Object[]]($env.Vaults | Sort-Object -Property { $_.Key })
            if( -not $env.Vaults )
            {
                $env.Vaults = @()
            }

            foreach( $vault in $env.Vaults )
            {
                $secrets = $vault.Secrets
                $vault.Secrets = [ordered]@{}
                foreach( $key in ($secrets.Keys | Sort-Object) )
                {
                    $vault.Secrets[$key] = $secrets[$key]
                }
            }
        }

        $cfgToExport | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $LiteralPath -NoNewLine
    }
}
