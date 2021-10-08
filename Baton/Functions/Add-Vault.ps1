
function Add-Vault
{
    <#
    .SYNOPSIS
    Adds a new vault to a Baton configuration object.

    .DESCRIPTION
    The "Add-CfgVault" function adds a new vault to an environment in a Baton configuration object. Pipe the 
    configuration object to this function or pass it to the "Configuration" parameter. Pass the environment where the
    vault should be added to the "Environment" parameter. Pass the Key used by the vault to the "Key" parameter. If the
    vault uses symmetric encryption, pass the key used to decrypt the vault's key to the "KeyDecryptionKey" parameter.

    By default, this function returns nothing. Use the "-PassThru" switch to return the configuration object piped to
    `Add-CfgVault` or passed to the `Configuration` parameter.

    If a vault that uses the given key already exists, this function writes an error and returns nothing.

    .EXAMPLE
    Import-CfgConfiguration | Add-CfgVault -Environment 'Verification' -Key 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'

    Demonstrates how to add a new vault to a configuration object. In this example, a vault that uses key 
    "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" will be added to the "Verification" environment.

    .EXAMPLE
    Import-CfgConfiguration | Add-CfgVault  -Environment 'Verification' -Key 'R1FLTERBL01hOlJF' -KeyDecryptionKey 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'

    Demonstrates how to add a new vault to a configuration object that uses symmetric encryption. In this example, the
    symmetric key is 'R1FLTERBL01hOlJF', which is base-64 encoded from the bytes of the key encrypted with the key
    in certificat with thumbprint "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Environment,

        [Parameter(Mandatory)]
        [String] $Key,

        [String] $KeyDecryptionKey,

        [Parameter(Mandatory, ValueFromPipeline)]
        [Object] $Configuration,

        [switch] $PassThru,

        [switch] $Overwrite
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        if( ($Configuration | Get-Vault -Environment $Environment -Key $Key -ErrorAction Ignore) )
        {
            $msg = "Failed to add vault ""$($Key)"": a vault using that key already exists."
            Write-Error -Message $msg -Configuration $Configuration
            return
        }

        $env = $Configuration | Get-Environment -Name $Environment -ErrorAction Ignore
        if( -not $env )
        {
            $env = $Configuration | Add-Environment -Name $Environment -PassThru | Get-Environment -Name $Environment
        }

        $secrets = @{}
        $newVault = New-VaultObject -Key $Key -KeyDecryptionKey $KeyDecryptionKey -Secrets $secrets
        [void]$env.Vaults.Add( $newVault )

        if( $PassThru )
        {
            return $Configuration
        }
    }
}
