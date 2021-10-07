

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

        $emptyObject = [pscustomobject]@{}
        $emptyArray = @()

        function ConvertTo-Hashtable
        {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory, ValueFromPipeline)]
                [Object] $InputObject
            )

            process
            {
                $ht = @{}
                $propertyNames =
                    $InputObject | Get-Member -MemberType 'NoteProperty' | Select-Object -ExpandProperty 'Name'
                foreach( $propertyName in $propertyNames )
                {
                    $ht[$propertyName] = $InputObject.$propertyName
                }
                return $ht
            }
        }

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

        $config = $null
        try
        {
            $config = Get-Content -LiteralPath $LiteralPath | ConvertFrom-Json
        }
        catch
        {
            $msg = "$($displayPath): error parsing JSON: $($_)"
            Write-Error -Message $msg -ErrorAction $ErrorActionPreference
            return
        }

        if( -not $config )
        {
            $config = [pscustomobject]::New()
        }
        elseif( $config -isnot ('{}' | ConvertFrom-Json).GetType() )
        {
            $msg = "$($displayPath): contains invalid JSON. Expected to get an object after parsing, but instead " +
                "got [$($config.GetType().FullName)]. Please update this file so that when parsed, returns a " +
                'single JSON object (i.e. `{` and `}` should be the first and last characters in the file).'
            Write-Error -Message $msg -ErrorAction $ErrorActionPreference
            return
        }

        # Make sure the config has required properties. Can't do this in a single pipeline because if there's an error,
        # Add-Member doesn't return anything.
        $config |
            Add-Member -Name 'Environments' -MemberType NoteProperty -Value $emptyArray.Clone() -ErrorAction Ignore
        $config | Add-Member -Name 'Path' -MemberType NoteProperty -Value $LiteralPath -Force

        # Make sure environments is *always* an array.
        if( $config.Environments -is [pscustomobject] )
        {
            $config.Environments = @( $config.Environments )
        }

        $envIdx = 0
        foreach( $env in $config.Environments )
        {
            $envIdx += 1

            if( -not ($env | Get-Member -Name 'Name') )
            {
                $msg = "$($displayPath): Environment $($envIdx) doesn't have a ""Name"" property. Each " +
                    'environment *must* have a name.'
                Write-Error -Message $msg -ErrorAction $ErrorActionPreference
                return
            }

            # Make sure each environment has all required settings.
            $env | Add-Member -Name 'Settings' -MemberType NoteProperty -Value $emptyObject -ErrorAction Ignore
            $env | Add-Member -Name 'Vaults' -MemberType NoteProperty -Value $emptyArray.Clone() -ErrorAction Ignore
            $env | Add-Member -Name 'InheritsFrom' -MemberType NoteProperty -Value '' -ErrorAction Ignore

            $env.Settings = $env.Settings | ConvertTo-Hashtable

            $vaultIdx = 0
            foreach( $vault in $env.Vaults )
            {
                $vaultIdx += 1
                if( -not ($vault | Get-Member -Name 'Key') )
                {
                    $msg = "$($displayPath): Environment $($env.Name): Vault $($vaultIdx) doesn't have a " +
                           '"Key" property. Each vault must have a "Key" property. For asymmetric keys (i.e. public ' +
                           'key cryptography), "Key" should be the thumbprint of the certificate to use. The ' +
                           'certificate must be in the "My"/"Personal" certificate store. For symmetric keys, "Key" ' +
                           'should be the bytes of the key, encrypted and base-64 encoded. The key should be ' +
                           'encrypted using the asymmetric key given by the thumbprint in the ' +
                           '"KeyDecryptionKey" property.'
                    Write-Error -Message $msg -ErrorAction $ErrorActionPreference
                    return
                }
                $vault | Add-Member -Name 'IsSymmetricKey' -MemberType 'NoteProperty' -Value $false -ErrorAction Ignore
                $vault | Add-Member -Name 'KeyDecryptionKey' -MemberType 'NoteProperty' -Value '' -ErrorAction Ignore
                $vault | Add-Member -Name 'Secrets' -MemberType NoteProperty -Value $emptyObject -ErrorAction Ignore

                $vault.Secrets = $vault.Secrets | ConvertTo-Hashtable
            }
        }

        return $config
    }

    end
    {
        Write-Debug "[$($MyInvocation.MyCommand.Name)]"
    }
}