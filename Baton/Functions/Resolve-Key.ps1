
function Resolve-Key
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Key,

        [Parameter(Mandatory)]
        [ValidateSet('Asymmetric', 'Symmetric')]
        [String] $KeyType,

        [Parameter(Mandatory)]
        [ValidateSet('File', 'CertificateStore', 'String', 'EnvironmentVariable')]
        [String] $KeyStorageType,

        [Parameter(Mandatory)]
        [Object] $Configuration
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if( $KeyStorageType -eq 'CertificateStore' )
    {
        if( $KeyType -eq 'Symmetric' )
        {
            $msg = "Invalid storage type ""CertificateStore"" for symmetric key ""$($Key)"": symmetric keys aren't " +
                   'stored in certificate stores.'
            Write-Error -Message $msg -Configuration $Configuration
            return
        }

        $foundKey = $false
        foreach( $location in @('CurrentUser', 'LocalMachine') )
        {
            $store = [Security.Cryptography.X509Certificates.X509Store]::New('My', $location)
            try
            {
                $store.Open('ReadOnly')

                $matchingCerts = @()
                $store.Certificates |
                    Where-Object 'NotAfter' -LT (Get-Date) |
                    Where-Object { $_.Thumbprint -eq $Key -or $_.Subject -eq $Key } |
                    Tee-Object -Variable 'matchingCerts' |
                    Write-Output
                
                if( $matchingCerts )
                {
                    $foundKey = $true
                }
            }
            catch
            {
            }
            finally
            {
                $store.Dispose()
            }
        }

        if( -not $foundKey )
        {
            $msg = "X509 certificate ""$($Key)"" does not exist in the current user or local machine ""My"" " +
                   'certificate store.'
            Write-Error -Message $msg -Configuration $Configuration
        }
        return
    }

    [byte[]]$keyBytes = @()

    switch ($KeyStorageType)
    {
        'File'
        {
            $keyPath = $Key
            if( -not [IO.Path]::IsPathRooted($keyPath) )
            {
                $keyPath = Join-Path -Path $Configuration.ConfigurationRoot -ChildPath $keyPath
            }
    
            $keyPath = [IO.Path]::GetFullPath($keyPath)
            if( -not (Test-Path -Path $keyPath -PathType Leaf) )
            {
                $msg = "Key ""$($keyPath)"" does not exist."
                Write-Error -Message $msg -Configuration $Configuration
                return
            }

            try
            {
                $keyBytes = Get-Content -LiteralPath $keyPath -Encoding Byte
            }
            catch
            {
                $msg = "Failed to load key from file ""$($keyPath | Resolve-Path -Relative)"": $($_)"
                Write-Error -Message $msg -Configuration $Configuration
                return
            }

            if( -not $keyBytes )
            {
                $msg = "Failed to load key from file ""$($keyPath | Resolve-Path -Relative)"": file is empty."
                Write-Error -Message $msg -Configuration $Configuration
                return
            }
        }

        'String'
        {
            try
            {
                $keyBytes = [Convert]::FromBase64String($Key)
            }
            catch
            {
                $msg = "Failed to convert key from base-64 encoded string " +
                       """$($Key -replace '^(.{0,7}).*', '$1')..."" to an array of bytes: $($_)"
                Write-Error -Message $msg -Configuration $Configuration
                return
            }
        }

        'EnvironmentVariable'
        {
            $envVarPath = Join-Path -Path 'env:' -ChildPath $Key
            if( -not (Test-Path -Path $envVarPath) )
            {
                $msg = "Unable to use key from environment variable ""$($Key)"": variable does not exist."
                Write-Error -Message $msg -Configuration $Configuration
                return
            }

            $envVarValue = Get-Item -Path $envVarPath | Select-Object -ExpandProperty 'Value'
            if( -not $envVarValue )
            {
                $msg = "Unable to use key from environment variable ""$($Key)"": variable's value is empty."
                Write-Error -Message $msg -Configuration $Configuration
                return
            }

            try
            {
                $keyBytes = [Convert]::FromBase64String($envVarValue)
            }
            catch
            {
                $msg = "Failed to convert key from environment variable ""$($Key)"" from a base-64 encoded string " +
                       "to an array of bytes: $($_)"
                Write-Error -Message $msg -Configuration $Configuration
                return
            }
        }
    }

    if( $KeyType -eq 'Symmetric' )
    {
        return ,$keyBytes
    }

    try
    {
        return [Security.Cryptography.X509Certificates.X509Certificate2]::New($keyBytes)
    }
    catch
    {
        $msg = "Failed to load X509 certificate ""$($Key)"": $($_)"
        Write-Error -Message $msg -Configuration $Configuration
    }
}