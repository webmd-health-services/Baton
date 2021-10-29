#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$result = $null
$testDir = $null
$testNum = 0
$publicCertPath = Join-Path -Path $PSScriptRoot -ChildPath 'baton.pem' -Resolve
$publicCert = Get-TCertificate -Path $publicCertPath
$privateCertPath = Join-Path -Path $PSScriptRoot -ChildPath 'baton.pfx' -Resolve

function GivenCertificate
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [String] $InstalledFor
    )

    $installIn = [Collections.ArrayList]::New()
    $uninstallFrom = [Collections.ArrayList]::New()
    $locations = @('CurrentUser', 'LocalMachine')
    foreach( $location in $locations )
    {
        $numErrorsBefore = $Global:Error.Count
        $cert = Get-TCertificate -StoreLocation $location -StoreName 'My' -Thumbprint $publicCert.Thumbprint -ErrorAction Ignore
        $numErrorsAfter = $Global:Error.Count
        for( $idx = 0; $idx -lt ($numErrorsAfter - $numErrorsBefore); ++$idx )
        {
            $Global:Error.RemoveAt(0)
        }

        $installed = $null -ne $cert
        if( $installed )
        {
            Write-Verbose "Installed for $($location)."
        }
        else
        {
            Write-Verbose "Not installed for $($location)."
        }
        if( $location -eq $InstalledFor )
        {
            if( -not $installed )
            {
                [void]$installIn.Add($location)
            }
            continue
        }

        if( $installed )
        {
            [void]$uninstallFrom.Add($location)
            continue
        }
    }

    foreach( $location in $locations )
    {
        $install = $installIn -contains $location
        $uninstall = $uninstallFrom -contains $location
        if( -not $install -and -not $uninstall )
        {
            continue
        }

        if( $install )
        {
            try
            {
                Write-Verbose "Installing for $($location)."
                Install-TCertificate -StoreLocation $location -StoreName 'My' -Path $publicCertPath -ErrorAction Ignore
            }
            catch
            {
                $Global:Error.RemoveAt(0)
            }
        }
        
        if( $uninstall )
        {
            try
            {
                Write-Verbose "Uninstalling for $($location)."
                Uninstall-TCertificate -StoreLocation $location `
                                       -StoreName 'My' `
                                       -Thumbprint $publicCert.Thumbprint `
                                       -ErrorAction Ignore
            }
            catch
            {
                $Global:Error.RemoveAt(0)
            }
        }
    }

}

function GivenFile
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [String] $Named,

        [Parameter(Mandatory, ParameterSetName='FromFile')]
        [String] $FromFile,

        [Parameter(Mandatory, ParameterSetName='WithContent')]
        [String] $WithContent
    )

    $path = Join-Path -Path $testDir -ChildPath $Named
    if( $FromFile )
    {
        Copy-Item -Path $FromFile -Destination $path
    }
    elseif( $WithContent )
    {
        Set-Content -Path $path -Value $WithContent -NoNewline
    }
}

function Init
{
    $Global:Error.Clear()
    $script:result = $null
    $script:testDir = Join-Path -Path $TestDrive.FullName -ChildPath (++$script:testNum)
    New-Item -Path $script:testDir -ItemType 'Directory'
    Remove-Item 'env:BATON_TEST_KEY' -ErrorAction Ignore
}

function Reset
{
    Remove-Item 'env:BATON_TEST_KEY' -ErrorAction Ignore
}

function Test-IsAdministrator
{
    if( (Test-TCOperatingSystem -IsWindows) )
    {
        [Security.Principal.WindowsPrincipal]$currentIdentity =[Security.Principal.WindowsIdentity]::GetCurrent()
        return $currentIdentity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # Don't know how to do this check on other platforms or even if it makes sense?
    if( (Get-Command -Name 'id' -ErrorAction Ignore) )
    {
        return (id -u) -eq 0
    }
    
    Write-Error -Message ('Unable to determine on the current operating system if the current user has admin rights.') `
                -ErrorAction Stop
}

if( -not (Test-IsAdministrator) -and `
    (Get-TCertificate -StoreLocation LocalMachine -Thumbprint $publicCert.Thumbprint -ErrorAction Ignore) )
{
    $msg = "Unable to run tests: test certificate ""$($publicCert.Subject)"" ($($publicCert.Thumbprint)) is " +
           'installed for the LocalMachine. Please remove this certificate and re-run your tests.'
    Write-Error -Message $msg -ErrorAction Stop
}

function Test-MyStore
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [switch] $IsSupported,

        [Parameter(Mandatory)]
        [Security.Cryptography.X509Certificates.StoreLocation] $Location
    )

    if( $Location -eq [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser )
    {
        return $true
    }

    if( (Test-TCOperatingSystem -Linux) )
    {
        return $false
    }

    return $true
}

function ThenResolvedKeyTo
{
    [CmdletBinding()]
    param(
        [Security.Cryptography.X509Certificates.X509Certificate2] $X509Certificate,

        [String] $X509CertificateFile,

        [String] $BytesFromString
    )

    ,$script:result | Should -Not -BeNullOrEmpty
    if( $X509CertificateFile -or $X509Certificate )
    {
        if( $X509CertificateFile )
        {
            $X509Certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::New($X509CertificateFile)
        }
        $script:result | Should -BeOfType [Security.Cryptography.X509Certificates.X509Certificate2]
        $script:result.Thumbprint | Should -Be $X509Certificate.Thumbprint
        $script:result.Subject | Should -Be $X509Certificate.Subject
    }

    if( $BytesFromString )
    {
        ,$script:result | Should -BeOftype [byte[]]
        $script:result | Should -Be ([Text.Encoding]::UTF8.GetBytes($BytesFromString))
    }
}

function ThenReturned
{
    [CmdletBinding()]
    param(
        [switch] $Nothing
    )

    if( $Nothing )
    {
        $script:result | Should -BeNullOrEmpty
    }
}

function WhenResolvingKey
{
    [CmdletBinding()]
    param(
        [String] $FromFile,

        [String] $FromBase64,

        [String] $FromCertificate
    )

    $config = New-CfgConfigurationObject
    $config.ConfigurationRoot = $script:testDir
    $params = @{
        Configuration = $config;
    }

    if( $FromFile )
    {
        $params['Key'] = $FromFile
        $params['SourceType'] = 'File'
    }
    elseif( $FromBase64 )
    {
        $params['Key'] = $FromBase64
        $params['SourceType'] = 'Base64'
    }
    elseif( $FromCertificate )
    {
        $params['Key'] = $FromCertificate
        $params['SourceType'] = 'Certificate'
    }

    $script:result = Invoke-ModulePrivateCommand 'Baton' 'Resolve-Key' $params -ErrorAction $ErrorActionPreference
}

Describe 'Resolve-Key.from a file using a relative path' {
    It 'should create key' {
        Init
        GivenFile 'private.pfx' -FromFile $privateCertPath
        WhenResolvingKey -FromFile 'private.pfx'
        ThenResolvedKeyTo -X509CertificateFile $privateCertPath
    }
}

Describe 'Resolve-Key.from a file using a full path' {
    It 'should create key' {
        Init
        WhenResolvingKey -FromFile $privateCertPath
        ThenResolvedKeyTo -X509CertificateFile $privateCertPath
    }
}
Describe 'Resolve-Key.from a file when file does not exist' {
    It 'should fail' {
        Init
        WhenResolvingKey -FromFile 'does not exist.pfx' -ErrorAction SilentlyContinue
        ThenReturned -Nothing
        ThenFailed -WithErrorMatching 'Key ".*(\\|/)does not exist.pfx" does not exist.'
    }
}
Describe 'Resolve-Key.from a file when reading the file fails' {
    It 'should fail' {
        Init
        Mock -CommandName 'Test-Path' -ModuleName 'Baton' -MockWith { return $true }
        Mock -CommandName 'Resolve-Path' `
                -ModuleName 'Baton' `
                -MockWith { return ($LiteralPath | Split-Path -Leaf) }
        WhenResolvingKey -FromFile 'does not exist.pfx' -ErrorAction SilentlyContinue
        ThenReturned -Nothing
        ThenFailed -WithErrorMatching 'Failed to load key from file "does not exist\.pfx"' -AtIndex 0
    }
}

Describe 'Resolve-Key.from base-64 encoded string' {
    It 'should create key' {
        Init
        $key = [Convert]::ToBase64String( [Text.Encoding]::UTF8.GetBytes('somekey'))
        WhenResolvingKey -FromBase64 $key
        ThenResolvedKeyTo -BytesFromString 'somekey'
    }
}

Describe 'Resolve-Key.from non base-64 encoded string' {
    It 'should fail' {
        Init
        WhenResolvingKey -FromBase64 'notbase64encoded~!@#$%^&*()_+' -ErrorAction SilentlyContinue
        ThenReturned -Nothing
        $regex = [regex]::Escape('Failed to convert key from base-64 encoded string "notbase...^&*()_+"')
        ThenFailed -WithErrorMatching $regex
    }
}

Describe 'Resolve-Key.from an environment variable holding base-64 string' {
    It 'should create key' {
        Init
        $env:BATON_TEST_KEY = [Convert]::ToBase64String( [Text.Encoding]::UTF8.GetBytes('somekey'))
        WhenResolvingKey -FromBase64 'env:BATON_TEST_KEY'
        ThenResolvedKeyTo -BytesFromString 'somekey'
    }
}

Describe 'Resolve-Key.from missing environment variable' {
    It 'should fail' {
        Init
        WhenResolvingKey -FromBase64 'env:BATON_TEST_KEY' -ErrorAction SilentlyContinue
        ThenReturned -Nothing
        $regex = [regex]::Escape('"BATON_TEST_KEY": variable does not exist')
        ThenFailed -WithErrorMatching $regex
    }
}

Describe 'Resolve-Key.from environment variable with no value' {
    It 'should fail' {
        Init
        Mock -Command 'Test-Path' -ModuleName 'Baton' -MockWith { return $true }
        Mock -Command 'Get-Item' -ModuleName 'Baton' -MockWith { [pscustomobject]@{ 'Value' = '' } }
        WhenResolvingKey -FromBase64 'env:BATON_TEST_KEY' -ErrorAction SilentlyContinue
        ThenReturned -Nothing
        $regex = [regex]::Escape('"BATON_TEST_KEY": variable''s value is empty')
        ThenFailed -WithErrorMatching $regex
    }
}

Describe 'Resolve-Key.from invalid certificate file' {
    It 'should load as symmetric key' {
        Init
        GivenFile 'invalid.pfx' -WithContent 'invalidcert'
        WhenResolvingKey -FromFile 'invalid.pfx' -ErrorAction SilentlyContinue
        ThenResolvedKeyTo -BytesFromString 'invalidcert'
    }
}

Describe 'Resolve-Key.from certificate store' {
    $testCases = & {
        @{ 'StoreLocation' = 'CurrentUser'; 'PropertyName' = 'Thumbprint'; 'FromEnvVar' = $true; }
        @{ 'StoreLocation' = 'CurrentUser'; 'PropertyName' = 'Thumbprint'; 'FromEnvVar' = $false; }
        @{ 'StoreLocation' = 'CurrentUser'; 'PropertyName' = 'Subject'; 'FromEnvVar' = $true; }
        @{ 'StoreLocation' = 'CurrentUser'; 'PropertyName' = 'Subject'; 'FromEnvVar' = $false; }
        if( (Test-IsAdministrator) )
        {
            @{ 'StoreLocation' = 'LocalMachine'; 'PropertyName' = 'Thumbprint'; 'FromEnvVar' = $true; }
            @{ 'StoreLocation' = 'LocalMachine'; 'PropertyName' = 'Thumbprint'; 'FromEnvVar' = $false; }
            @{ 'StoreLocation' = 'LocalMachine'; 'PropertyName' = 'Subject'; 'FromEnvVar' = $true; }
            @{ 'StoreLocation' = 'LocalMachine'; 'PropertyName' = 'Subject'; 'FromEnvVar' = $false; }
        }
    }
    AfterEach { Reset }
    $itMsg = 'should resolve using <PropertyName> { FromEnvVar: <FromEnvVar> } when certificate in ' +
                '<StoreLocation>\My store'
    It $itMsg -TestCases $testCases {
        param(
            [String] $StoreLocation,
            [String] $PropertyName,
            [switch] $FromEnvVar
        )

        Init
        Uninstall-TCertificate -Thumbprint $publicCert.Thumbprint

        $errorActionParam = @{}
        $shouldFail = $false
        if( (Test-MyStore -IsSupported -Location $StoreLocation) -and (Test-IsAdministrator) )
        {
            GivenCertificate -InstalledFor $StoreLocation
        }
        else
        {
            $shouldFail = $true
            $errorActionParam['ErrorAction'] = 'SilentlyContinue'
        }

        $certProperty = $publicCert.$PropertyName
        $certValue = $publicCert.$PropertyName
        if( -not $certValue )
        {
            Write-Warning -Message 'Unable to test'
        }
        if( $FromEnvVar )
        {
            $env:BATON_TEST_KEY = $certValue
            $certProperty = 'env:BATON_TEST_KEY'
        }
        
        $Global:Error.Clear()
        WhenResolvingKey -FromCertificate $certProperty @errorActionParam
        if( $shouldFail )
        {
            ThenReturned -Nothing
            ThenFailed -WithErrorMatching "X509 certificate ""$($certValue)"" does not exist"
        }
        else
        {
            ThenResolvedKeyTo -X509Certificate $publicCert
            ThenNoError
        }
    }
}

Describe 'Resolve-Key.from certificate that does not exist' {
    It 'should fail' {
        Init
        WhenResolvingKey -FromCertificate 'doesnotexist' -ErrorAction SilentlyContinue
        ThenReturned -Nothing
        ThenFailed -WithErrorMatching 'X509 certificate "doesnotexist" does not exist'
    }
}

Remove-Item 'env:BATON_TEST_KEY' -ErrorAction Ignore
