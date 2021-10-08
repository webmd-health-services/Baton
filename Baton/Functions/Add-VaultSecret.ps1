
function Add-VaultSecret
{
    <#
    .SYNOPSIS
    Adds a secret to a vault.

    .DESCRIPTION
    The `Add-CfgVaultSecret` function adds a secret to an existing vault. Pass the vault's environment name to the
    `Environment` parameter. Pass the vault's key to the `Key` parameter. Pass the secret's name to the `Name`
    parameter. Pass the encrypted, base-64 encoded secret value to the `CipherText` parameter. Pipe the configuration to
    add the secret to the function, or pass it to the `Configuration` parameter. The secret will be added to a vault
    that uses key `Key` in environment `Environment`.

    If a secret with name `Name` already exists, `Add-CfgVaultSecret` writes an error and makes no changes. Use the
    `-Overwrite` switch to overwrite the value of the secret if it exists.

    Use the `-PassThru` switch to return the configuration object that was piped to `Add-CfgVaultSecret` or passed to
    the `Configuration` parameter.

    .EXAMPLE
    $config | Add-CfgVaultSecret -Environment $env -Key $key -Name $name -CipherText $ciphertext

    Demonstrates how to add a secret to a vault by piping the configuration object to the `Add-CfgVaultSecret` function.

    .EXAMPLE
    Add-CfgVaultSecret -Configuration $config -Environment $env -Key $key -Name $name -CipherText $ciphertext
    
    Demonstrates how to add a secret to a vault by passing the configuration object to the `Add-CfgVaultSecret`
    function's `Configuration` parameter.

    .EXAMPLE
    $config | Add-CfgVaultSecret -Environment $env -Key $key -Name $name -CipherText $ciphertext -Overwrite

    Demonstrates how to replace an existing secret's value by using the `-Overwrite` parameter.

    .EXAMPLE
    $config | Add-CfgVaultSecret -Environment $env -Key $key -Name $name -CipherText $ciphertext -PassThru

    Demonstrates how to return the configuration object passed to `Add-CfgVaultSecret` using the `PassThru` switch.
    #>
    [CmdletBinding()]
    param(
        # The environment of the vault where the secret should be added. This environment will be created if it doesn't
        # exist.
        [Parameter(Mandatory)]
        [String] $Environment,

        # The vault key where the secret should be added.
        [Parameter(Mandatory)]
        [String] $Key,

        # The name of the secret.
        [Parameter(Mandatory)]
        [String] $Name,

        # The secret's encrypted, base-64 encoded value.
        [Parameter(Mandatory)]
        [String] $CipherText,

        # The configuration object to operate on.
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object] $Configuration,

        # If set, will overwrite any existing secret.
        [switch] $Overwrite,

        # If set, will return the configuration object piped to the function or passed to the `Configuration` parameter.
        [switch] $PassThru
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        $vault = $Configuration | Get-Vault -Environment $Environment -ErrorAction Ignore | Where-Object 'Key' -EQ $Key
        if( -not $vault )
        {
            $vault =
                $Configuration |
                Add-Vault -Environment $Environment -Key $Key -PassThru |
                Get-Vault -Environment $Environment -Key $Key
        }

        if( -not $Overwrite -and $vault.Secrets.ContainsKey($Name) )
        {
            $msg = "The ""$($Key)"" vault in the $($Environment) environment already contains secret ""$($Name)"". " +
                   'Use the -Overwrite switch to overwrite the existing value.'
            Write-Error -Message $msg -Configuration $Configuration
            return
        }
        $vault.Secrets[$Name] = $ciphertext

        if( $PassThru )
        {
            return $Configuration
        }
    }
}
