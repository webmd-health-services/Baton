

function Import-Configuration
{
    <#
    .SYNOPSIS
    Imports a Baton configuration file.

    .DESCRIPTION
    The `Import-CfgConfiguration` function imports configuration from a Baton configuration file and returns a
    configuration object. By default, `Import-CfgConfiguration` returns configuration from the first "baton.json"
    file found, starting in the current directory followed by each of its parent directories. If no "baton.json"
    file is found, `Import-CfgConfiguration` writes an error.

    To import a "baton.json" file from a specific directory (or its parents), pass the path to that directory to the
    `-LiteralPath` parameter. To import configuration from a specific file, pass the path to that file to the 
    `-LiteralPath` parameter. You can also pipe files and directories from the output of `Get-Item` and `Get-ChildItem`
    to `Import-CfgConfiguration`.

    A Baton configuration file is JSON. It should be an object with an "Environments" property that is an array of
    environment objects. Each environment object must have a "Name" property. Each environment object can also have
    these properties:

    * "InheritsFrom": Another environment in the same configuration file from which configuration is inherited.
    * "Settings": An object containing settings for that environment. Setting names are the object's property names and
    the setting values are the properties' values.
    * "Vaults": An array of objects. Each object is a vault of encrypted secrets and must have a "Secrets" property
    that contains secret names whose values are the encrypted secrets. If the secrets are asymmetrically encrypted,
    the vault must have a "KeyThumbprint" property that is the thumbprint of a certificate with a private key to use
    to decrypt. If the secrets are symmetrically encrypted, the vault must have a "Key" property which is the symmetric
    encryption key that has been asymmetrically encrypted with the public key indicated by the "KeyThumbprint" property.

    Here's an example:

        {
            "Environments": {
                [
                    {
                        "Name": "Default",
                        "Settings": {
                            "SettingOne": "ValueOne"
                        },
                        "Vaults": [
                            {
                                "KeyThumbprint": "deadbee",
                                "Secrets": {
                                    "secretone": "encryptedsecretone"
                                }
                            }
                        ]
                    },

                    {
                        "Name": "Dev",
                        "InheritsFrom": "Default",
                        "Settings": {
                            "SettingTwo": "ValueTwo"
                        },
                        "Vaults": [
                            {
                                "KeyThumbprint": "deadbee",
                                "Key": "My super secret symmetric key encrypted with the certificates whose thumbprint is KeyThumbprint.",
                                "Secrets": {
                                    "secrettwo": "encryptedsecrettwo"
                                }
                            }
                        ]
                    }
                ]
            }
        }


    .EXAMPLE
    Import-CfgConfiguration

    Demonstrates how to import configuration from the first "baton.json" file from the current directory or any of
    its parent directories.

    .EXAMPLE
    'example.json' | Import-CfgConfiguration

    Demonstrates that you can import configuration from a specific file and that you can pipe file paths to
    `Import-CfgConfiguration`.

    .EXAMPLE
    Get-Item 'C:\example' | Import-CfgConfiguration

    Demonstrates that you can pipe items from `Get-Item` and `Get-ChildItem` to `Import-CfgConfiguration` and that
    `Import-CfgConfiguration` accepts paths to directories.
    #>
    [CmdletBinding()]
    param(
        # The path to the file to import or the path to a directory where `Import-CfgConfiguration` should start 
        # looking for a "baton.json" file.
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Position=0, ParameterSetName='ByPath')]
        [Alias('FullName')]
        [Alias('Path')]
        [String] $LiteralPath
    )

    begin
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        Write-Debug "[$($MyInvocation.MyCommand.Name)]"
    }

    process 
    {
        if( -not $LiteralPath )
        {
            $LiteralPath = Find-ConfigurationPath
        }
        else
        {
            $LiteralPath = 
                Resolve-Path -LiteralPath $LiteralPath -ErrorAction $ErrorActionPreference |
                Select-Object -ExpandProperty 'ProviderPath'

        }

        if( -not $LiteralPath )
        {
            return
        }

        if( (Test-Path -Path $LiteralPath -PathType Container) )
        {
            Push-Location -Path $LiteralPath
            try
            {
                $LiteralPath = Find-ConfigurationPath
            }
            finally
            {
                Pop-Location
            }

            if( -not $LiteralPath )
            {
                return
            }
        }

        $displayPath = Resolve-Path -LiteralPath $LiteralPath -Relative

        Write-Debug "  $($displayPath)"

        $jsonConfig = $null
        try
        {
            $jsonConfig = Get-Content -LiteralPath $LiteralPath | ConvertFrom-Json
        }
        catch
        {
            $msg = "$($displayPath): error parsing JSON: $($_)"
            Write-Error -Message $msg -ErrorAction $ErrorActionPreference
            return
        }

        if( -not $jsonConfig )
        {
            $jsonConfig = [pscustomobject]::New()
        }
        elseif( $jsonConfig -isnot ('{}' | ConvertFrom-Json).GetType() )
        {
            $msg = "$($displayPath): contains invalid JSON. Expected to get an object after parsing, but instead " +
                "got [$($jsonConfig.GetType().FullName)]. Please update this file so that when parsed, returns a " +
                'single JSON object (i.e. `{` and `}` should be the first and last characters in the file).'
            Write-Error -Message $msg -ErrorAction $ErrorActionPreference
            return
        }

        $batonConfig = New-ConfigurationObject -Path $LiteralPath
        
        $envIdx = 0

        $jsonEnvs = 
            $jsonConfig |
            Select-Object -ExpandProperty 'Environments' -ErrorAction Ignore |
            Select-Object -Property 'Name', 'InheritsFrom', 'Settings', 'Vaults'
        foreach( $jsonEnv in $jsonEnvs )
        {
            $envIdx += 1

            if( -not $jsonEnv.Name )
            {
                $msg = "$($displayPath): Environment $($envIdx) doesn't have a ""Name"" property. Each " +
                    'environment *must* have a name.'
                Write-Error -Message $msg -ErrorAction $ErrorActionPreference
                return
            }

            $batonEnv = New-EnvironmentObject -Name $jsonEnv.Name `
                                        -InheritsFrom $jsonEnv.InheritsFrom `
                                        -Settings $jsonEnv.Settings
            [void]$batonConfig.Environments.Add( $batonEnv )

            $vaultIdx = 0
            $jsonVaults =
                $jsonEnv |
                Select-Object -ExpandProperty 'Vaults' -ErrorAction Ignore |
                Select-Object -Property 'Key', 'KeyDecryptionKey', 'Secrets'
            foreach( $jsonVault in $jsonVaults )
            {
                $vaultIdx += 1
                if( -not $jsonVault.Key )
                {
                    $msg = "$($displayPath): Environment $($jsonEnv.Name): Vault $($vaultIdx) doesn't have a " +
                           '"Key" property. Each vault must have a "Key" property. For asymmetric keys (i.e. public ' +
                           'key cryptography), "Key" should be the thumbprint of the certificate to use. The ' +
                           'certificate must be in the "My"/"Personal" certificate store. For symmetric keys, "Key" ' +
                           'should be the bytes of the key, encrypted and base-64 encoded. The key should be ' +
                           'encrypted using the asymmetric key given by the thumbprint in the ' +
                           '"KeyDecryptionKey" property.'
                    Write-Error -Message $msg -ErrorAction $ErrorActionPreference
                    return
                }

                $batonVault = New-VaultObject -Key $jsonVault.Key `
                                        -KeyDecryptionKey $jsonVault.KeyDecryptionKey `
                                        -Secrets $jsonVault.Secrets
                [void]$batonEnv.Vaults.Add( $batonVault )
            }
        }

        return $batonConfig
    }

    end
    {
        Write-Debug "[$($MyInvocation.MyCommand.Name)]"
    }
}