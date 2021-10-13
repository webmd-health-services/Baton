
function Protect-Secret
{
    <#
    .SYNOPSIS
    Encrypts secrets using a given key.

    .DESCRIPTION
    The `Protect-WhsSecret` function prompts you for a secret, encrypts it, and returns the encrypted secret as a
    base-64 encoded string. These strings are then suitable for storing in your WhsEnvironments.json file or in a custom WHS settings hashtable. For more information on how to store encrypted secrets, see the `Get-WhsSecret` help topic.

    By default, secrets are encrypted with the key for a given environment. The path to the key to use is set by the `DefaultPublicKeyPath` setting (which you can override for your environment in `WhsEnvironments.json`).

    You can also encrypt a secret with a specific key, by passing the path to a public key to the `PublicKeyPath` parameter. This path can be the path to a certificate file on the file system, or to a certificate in one of the Windows certificate stores using the `cert:` drive and provider.

    You can encrypt with any key found in the Local Machine or Current User's My store by passing the key's thumbprint via the `Thumbprint` parameter.

    Protected secrets are decrypted with `Get-WhsSecret`.

    The `Password` parameter is used for testing. Please don't use it.

    .LINK
    Get-WhsSecret

    .LINK
    about_Protecting_WHS_Secrets

    .LINK
    about_WhsEnvironments.json

    .LINK
    New-CRsaKeyPair

    .EXAMPLE
    Protect-WhsSecret -Environment developer -Name 'WBMD\Scheduleuser' -AsJson

    A prompt will appear asking for the password. Enter it twice.

    .EXAMPLE
    ConvertTo-SecureString -String 'P@ssw0rd!' -AsPlainText -Force | Protect-WhsSecret -Environment 'developer'

    #>
    [CmdletBinding()]
    param(
        # The path to the public key to use to encrypt a secret. Can be a file system path or a certificate provider path (e.g. `cert:`).
        [Parameter(Mandatory)]
        [Object] $Key,

        [securestring] $Secret
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if( $PSCmdlet.ParameterSetName -like 'ByThumbprint*' )
    {
        $PublicKeyPath = 'cert:\CurrentUser\My\{0}' -f $Thumbprint
        if( -not (Test-Path -Path $PublicKeyPath -PathType Leaf) )
        {
            $PublicKeyPath = 'cert:\LocalMachine\My\{0}' -f $Thumbprint
            if( -not (Test-Path -Path $PublicKeyPath -PathType Leaf) )
            {
                Write-Error ('Certificate "{0}" not found. Please install this certificate in the local machine or current user''s My store.' -f $Thumbprint)
                return
            }
        }
    }
    
    if( $PSCmdlet.ParameterSetName -like 'ByEnvironment*' )
    {
        $PublicKeyPath = Import-Configuration | Get-WhsCfgSetting -Environment $Environment -Name 'DefaultPublicKeyPath'
        if( -not $PublicKeyPath )
        {
            return
        }
        $PublicKeyPath = Join-Path -Path $moduleRoot -ChildPath $PublicKeyPath -Resolve
        $cert = Get-CCertificate -Path $PublicKeyPath
        $Thumbprint = $cert.Thumbprint
    }

    $config = $null
    if( -not $PassThru )
    {
        if( $Path )
        {
            $config = Import-WhsCfgConfiguration -LiteralPath $Path
        }
        else
        {
            $config = Import-WhsCfgConfiguration
        }

        if( -not $config )
        {
            return
        }
        $Path = $config.Path
    }

    $secret = Read-Host -Prompt 'Please enter secret to encrypt' -AsSecureString

    $ciphertext = Protect-CString -String $secret -PublicKeyPath $PublicKeyPath

    if( $PassThru )
    {
        return $ciphertext
    }

    $newVault = [pscustomobject]@{
        'KeyThumbprint' = $Thumbprint;
        'Secrets' = @{
            $Name = $ciphertext;
        };
    }

    $env = $config.Environments | Where-Object 'Name' -EQ $Environment
    if( $env )
    {
        $vault = $env.Vaults | Where-Object 'Key' -EQ '' | Where-Object 'Thumbprint' -EQ $Thumbprint
        if( $vault )
        {
            if( -not $Force -and $vault.Secrets.ContainsKey($Name) )
            {
                $msg = "$($config.Path | Resolve-Path -Relative): A ""$($Thumbprint)"" vault in the $($Environment) " +
                       "environment already contains secret $($Name). Use the -Force switch to override the existing " +
                       'value.'
                Write-Error -Message $msg -ErrorActionPrefernce $ErrorActionPreference
                return
            }
            $vault.Secrets[$Name] = $ciphertext
        }
        else
        {
            $env.Vaults = & {
                $env.Vaults | Write-Output
                $newVault | Write-Output
            }
        }
    }
    else
    {
        $config.Environments = & {
                $config.Environments | Write-Output
                [pscustomobjct]@{
                    'Name' = $Environment;
                    'Vaults' = @(
                        $newVault
                    )
                } | Write-Output
            } |
            Sort-Object -Property 'Name'
    }

    $config | ConvertTo-Json -Depth 100 | Set-Content -Path $config.Path
}