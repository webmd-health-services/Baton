
function Resolve-Key
{
    <#
    .SYNOPSIS
    ***INTERNAL***. Do not use.
    .DESCRIPTION
    ***INTERNAL***. Do not use.
    .EXAMPLE
    ***INTERNAL***. Do not use.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Key,

        [Parameter(Mandatory)]
        [ValidateSet('File', 'Base64', 'Certificate')]
        [String] $SourceType,

        [Parameter(Mandatory)]
        [Object] $Configuration
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    # The key is in an environment variable.
    if( $Key -like 'env:*' )
    {
        $envVarPath = $Key
        $displayKey = $envVarPath -replace '^env:', ''
        if( -not (Test-Path -Path $envVarPath) )
        {
            $msg = "Unable to use key in environment variable ""$($displayKey)"": variable does not exist."
            Write-Error -Message $msg -Configuration $Configuration
            return
        }

        $envVarValue = Get-Item -Path $envVarPath | Select-Object -ExpandProperty 'Value'
        if( -not $envVarValue )
        {
            $msg = "Unable to use key in environment variable ""$($displayKey)"": variable's value is empty."
            Write-Error -Message $msg -Configuration $Configuration
            return
        }

        $Key = $envVarValue
    }

    [byte[]] $keyBytes = [byte[]]::New(0)
    $displayKey = $Key

    if( $SourceType -eq 'Certificate' )
    {
        $numStartErrors = $Global:Error.Count
        $cert = & {
                Get-CCertificate -StoreLocation CurrentUser -StoreName 'My'
                Get-CCertificate -StoreLocation LocalMachine -StoreName 'My'
            } |
            Where-Object { 
                $_.Thumbprint -eq $Key -or `
                $_.Subject -eq $Key -or `
                # FriendlyName is Windows-only.
                ($_ | Select-Object -ExpandProperty 'FriendlyName' -ErrorAction Ignore) -eq $Key
            } |
            Sort-Object -Property 'NotAfter' -Descending |
            Select-Object -First 1
        $numEndErrors = $Global:Error.Count
        for( $idx = 0; $idx -lt $numEndErrors - $numStartErrors; ++$idx )
        {
            $Global:Error.RemoveAt(0)
        }
        

        if( -not $cert )
        {
            $msg = "X509 certificate ""$($displayKey)"" does not exist in the current user or local machine ""My"" " +
                   'certificate store. Make sure a certificate with that thumbprint, subject, or, on Windows, ' +
                   'friendly name, exists in the current user or local machine "My" store.'
            Write-Error -Message $msg -Configuration $Configuration
            return
        }

        return $cert
    }

    if( $SourceType -eq 'File' )
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

        $displayKey = Resolve-Path -LiteralPath $keyPath -Relative

        $ex = $null
        try
        {
            # Using Get-Content to read a file as raw bytes changed between major versions of PowerShell.
            $params = @{ 'Encoding' = 'Byte' }
            if( (Get-Command -Name 'Get-Content' -ParameterName 'AsByteStream' -ErrorAction Ignore) )
            {
                $params = @{ 'AsByteStream' = $true; 'ReadCount' = 0; }
            }
            $keyBytes = Get-Content -LiteralPath $keyPath @params -ErrorAction Stop
        }
        catch
        {
            $ex = $_
            while( ($ex | Get-Member -Name 'InnerException') -and $ex.InnerException )
            {
                $ex = $ex.InnerException
            }
        }

        if( -not $keyBytes )
        {
            $exMsg = 'file is empty.'
            if( $ex )
            {
                $exMsg = $ex.ToString()
            }
            $msg = "Failed to load key from file ""$($displayKey)"": $($exMsg)"
            Write-Error -Message $msg -Configuration $Configuration
            return
        }

        $numStartErrors = $Global:Error.Count
        try
        {
            # Is it an X509Certificate file?
            return [Security.Cryptography.X509Certificates.X509Certificate2]::New($keyBytes)
        }
        # Nope. Treat the file as raw key bytes.
        catch [Security.Cryptography.CryptographicException]
        {
            # We handled this exception so remove all trace of it.
            $numEndErrors = $Global:Error.Count
            for( $idx = 0; $idx -lt $numEndErrors - $numStartErrors; ++$idx )
            {
                $Global:Error.RemoveAt(0)
            }
            return ,$keyBytes
        }
    }

    if( $SourceType -eq 'Base64' )
    {
        try
        {
            return ,([Convert]::FromBase64String($Key))
        }
        catch
        {
            if( $displayKey.Length -gt 17 )
            {
                $displayKey = $displayKey -replace '^(.{7}).*(.{7})$', '$1...$2'
            }
            $msg = "Failed to convert key from base-64 encoded string ""$($displayKey)"" to an array of bytes: " +
                   "$($_)"
            Write-Error -Message $msg -Configuration $Configuration
            return
        }
    }
}