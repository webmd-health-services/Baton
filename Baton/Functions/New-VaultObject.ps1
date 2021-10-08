
function New-VaultObject
{
    <#
    .SYNOPSIS
    Creates a new Baton vault object.

    .DESCRIPTION
    The `New-VaultObject` function creates a new Baton vault object. Vaults store encrypted secrets. Use this function to
    create configurations via automation. Pass the thumbprint of the certificate used to encrypt/decrypt the vault's
    secrets to the "Key" parameter. If the vault uses symmetric encryption, pass the encrypted, base-64 encoded
    symmetric key to the "Key" parameter and the thumbprint of the certificate to use to decrypt the symmetric key to 
    the "KeyDecryptionKey" parameter. Pass existing secrets to the "Secrets" parameter as a hashtable of secret names
    and encrypted, base-64 encoded values.

    Returns an object with these properties:

    * `Key`: the thumbprint of the public/private-key (i.e. asymmetric) certificate to used to decrypt/encrypt the
    vault's secrets. Or, if using symmetric encryption, the encrypted, base-64 encoded symmetric key.
    * `KeyDecryptionKey`: if "Key" is a symmetric key, this property should be set to the thumbprint of the
    public/private key certificate to use to decrypt the key.
    * `Secrets`: a hashtable of the secret names and their encrypted, base-64 encoded values.

    .EXAMPLE
    New-VaultObject -Key 'feebdaedfeebdaedfeebdaedfeebdaedfeebdaed'

    Demonstrate how to create a new Baton vault object that uses asymmetric encryption. The thumbprint of the
    public/private key pair

    .EXAMPLE
    New-VaultObject -KeyDecryptionKey 'feebdaedfeebdaedfeebdaedfeebdaedfeebdaed' -Key 'UWB6BI8XIpyVvxuV6curwZClplqyev2bUjv3WfPkJw+B/4g+fSuQPMJlli2ALawmICcr4eIxpqH3GGGUDze8OD1W1OGsJmQmDh0nSqmjr9i6FLn1crGzsSTqTv1gS8/KwZTcVTTenLxwCMpO3BGUy+CAjrfuqbkKp/gMVPjs2HjfPgO9Om9bdBimkUVEO9HQY7M3tOThSVWeeU54NEre6qmB95IO7Bre50MjXsyyhhzJOWUTKtTjqeVBZLES0y0gI6z1GEWiY/Qzt1LGlszm6c+eJ/s/zpF3NVCNsV/FBMrMG+xlCKlk5HHcNRbtTaOyxVcF912WM4TU8Okka0PQcXQ91cxIoWDqj/FjCpzy1oO/NY5RMf4fei75YhypopcXUMpCCGx3GCNGQr5/Nyd9L7EI25sTojUIX5xF3ILuhdq/zL+L/zrqZtf/kpqpxwW8819r8nqDGsgAzOyhax//M3pbUeGIF09z3oR3nhY12lYizvZkKDhVlcHmvTPbtpyPpoSkfeK/VxpPCkFx36adWBKriwpnbeydPRB7dGk9Nv0ol7kPQc8KOsrDcEQl6PqgxXWBpPhDNb8wd3WydQVgh9TvEEhkxPwLouA/169RKwPdITa1uscs0ZCOQogbKxo+1v4ujLi7ofK5+aWAAEBo46asy7z760d2m7SQPOpXN3U='

    Demonstrates how to create a vault that uses symmetric encryption. The encrypted, base-64 encoded key is passed to
    the "Key" parameter, and the thumbprint of the public/private key certificate to use to decrypt the key is passed
    to the "KeyDecryptionKey" object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Key,

        [String] $KeyDecryptionKey,

        [Object] $Secrets
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $vault = [pscustomobject]@{
        'Key' = $Key;
        'KeyDecryptionKey' = $KeyDecryptionKey;
        'Secrets' = @{};
    }
    $vault.pstypenames.Insert(0, 'Baton.Vault')
    
    if( $Secrets )
    {
        $Secrets | Copy-Object -DestinationObject $vault.Secrets
    }

    return $vault
}
