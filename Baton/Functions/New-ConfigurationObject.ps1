
function New-ConfigurationObject
{
    <#
    .SYNOPSIS
    Creates a new Baton configuration object.

    .DESCRIPTION
    The `New-CfgConfigurationObject` function creates a new Baton configuration object. Use this function to create 
    configurations via automation of some kind.

    Returns an object with these properties:

    * `Path`: the path where the configuration's representation as a JSON file is saved.
    * `ConfigurationRoot`: the directory where the configuration's JSON file is saved. This property is used by Baton
    to find and resolve paths stored in the configuration file.
    * `Environments`: an empty list of environments. Use `Add-Environment` to add a new environment to a configuration.

    .EXAMPLE
    New-CfgConfigurationObject

    Demonstrates how to use this function to create a new Baton configuration object.

    .EXAMPLE
    New-CfgConfigurationObject -Path 'C:\Projects\Baton\baton.json'

    Demonstrates how to use this function to create a Baton configuration object for a baton.json file that exists.
    #>
    [CmdletBinding()]
    param(
        # The path to the baton.json file for this configuration object. The file *must* exist.
        [String] $Path
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $configRoot = ''
    if( $Path )
    {
        $Path = Resolve-Path -LiteralPath $Path | Select-Object -ExpandProperty 'ProviderPath'
        if( -not $Path )
        {
            return
        }

        $configRoot = $Path | Split-Path
    }

    $config = [pscustomobject]@{
        'Path' = $Path;
        'ConfigurationRoot' = $configRoot;
        'Environments' = [Collections.ArrayList]::New();
    }
    $config.pstypenames.Insert(0, 'Baton.Configuration')
    return $config
}
