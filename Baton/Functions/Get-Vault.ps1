
function Get-Vault
{
    <#
    .SYNOPSIS
    Gets an environment's vaults.

    .DESCRIPTION
    The `Get-CfgVault` function gets an enviornment's vaults from a "baton.json" file. Pass the name of the
    current environment to the "Environment" parameter. `Get-CfgVault` returns vault objects for that environment and
    all of its parent environments.
    
    Vaults are objects that contain encrypted values. The object's "Secrets" property is a hashtable containing the
    encrypted secrets: the key is the secret name, and the value is the encrypted secret.
    
    Each vault defines a "KeyThumbprint", which is the thumbprint of the certificate whose private key can be used to
    decrypt the values in that vault. A vault may also optionally have a "Key" property, which is the symmetric key used
    to encrypt all the values in that vault. The value of the "Key" property should be encrypted with the public key
    whose thumbprint is given by the "KeyThumbprint" property.
    
    By default, `Get-CfgVault` returns the vaults from the first "baton.json" file found in the current directory
    and its parent directories. To get vaults from a specific configuration file or another repository/directory, use
    `Import-CfgConfiguration` and pipe its output to `GetCfgVault`.

    If an environment has one or more parent environments, `Get-CfgVault` will return *all* the vaults, starting with
    the environment, then each of its parent environments.

    If no vaults exist, nothing is returned.

    .EXAMPLE
    Get-CfgVault -Environment 'Verification'

    Demonstrates how to get all the vaults in an environment and all of its parent environments. In this case, all the
    verification environment's vaults—and each of its parent environments—are returned.

    .EXAMPLE
    Import-CfgConfiguration -LiteralPath 'C:\Some\Other\Repo\Or\File' | Get-CfgVault -Environment 'Verification'

    Demonstrates how to get the vaults from a configuration file other than the default configuration file by using
    `Import-CfgConfiguration` to load that file and piping the configuration to `Get-CfgVault`.
    #>
    [CmdletBinding()]
    param(
        # The name of the environments whose vaults to return.
        [Parameter(Mandatory)]
        [String] $Environment,

        # The key thumbprint of the vault to return.
        [String] $Key,

        # The configuration to use. The default is to use the configuration in the first "config.json" file found,
        # starting in the current directory followed by each of its parent directories. Use `Import-CfgConfiguration`
        # to import configurations.
        [Parameter(ValueFromPipeline)]
        [Object] $Configuration
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        if( -not $Configuration )
        {
            $Configuration = Import-Configuration
            if( -not $Configuration )
            {
                return
            }
        }

        $Configuration |
            Get-Environment -Name $Environment -All |
            Select-Object -ExpandProperty 'Vaults' |
            Where-Object {
                if( $Key )
                {
                    return $_.Key -eq $Key
                }
                return $true
            }
    }
}