

#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$environment = 'Verification'
$config = $null
$result = $null
$testDir = $null
$testNum = 0

function GivenSecret
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Named,

        [Parameter(Mandatory)]
        [String] $WithValue,

        [Parameter(Mandatory)]
        [String] $InVault
    )

    $script:config | Add-CfgVaultSecret -Environment $environment -Key $InVault -Name $Named -CipherText $WithValue
}

function Init
{
    $Global:Error.Clear()
    $script:result = $null

    $script:testDir = Join-Path -Path $TestDrive.FullName -ChildPath (++$testNum)
    New-Item -Path $script:testDir -ItemType 'Directory'

    $script:config = New-CfgConfigurationObject
}

function ThenReturned
{
    [CmdletBinding()]
    param(
        [switch] $Nothing,

        [switch] $ConfigurationObject
    )
    
    if( $Nothing )
    {
        $script:result | Should -BeNullOrEmpty
    }

    if( $ConfigurationObject )
    {
        $script:result | Should -Not -BeNullOrEmpty
        $script:result | ShouldBeOfBatonType 'Configuration'
    }
}

function ThenSecret
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Named,

        [Parameter(Mandatory)]
        [STring] $HasValue,

        [Parameter(Mandatory)]
        [String] $InVault
    )

    $script:config |
        Get-CfgVault -Environment $environment |
        Where-Object 'Key' -EQ $InVault |
        Where-Object { $_.Secrets.ContainsKey($Named) } |
        ForEach-Object { $_.Secrets[$Named] } |
        Should -Be $HasValue
}

function ThenFailed {
    [CmdletBinding()]
    param (
        [String] $WithErrorMatching
    )
    
    $Global:Error | Should -Not -BeNullOrEmpty
    if( $WithErrorMatching )
    {
        $Global:Error | Should -Match $WithErrorMatching
    }
}


function WhenAddingSecret
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Secret,

        [Parameter(Mandatory)]
        [String] $WithValue,

        [Parameter(Mandatory)]
        [String] $ToVault,

        [switch] $ReplacingExisting,

        [switch] $WithPassThru
    )

    $optionalParams = @{}
    if( $ReplacingExisting )
    {
        $optionalParams['Overwrite'] = $true
    }

    if( $WithPassThru )
    {
        $optionalParams['PassThru'] = $true
    }

    $script:result =
        $script:config |
        Add-CfgVaultSecret -Environment $environment -Name $Secret -CipherText $WithValue -Key $ToVault @optionalParams
}

Describe 'Add-VaultSecret.when there are no vaults' {
    It 'should add the secret' {
        Init
        WhenAddingSecret 'secret' -WithValue 'protected' -ToVault 'notvaults'
        ThenReturned -Nothing
        ThenSecret 'secret' -InVault 'notvaults' -HasValue 'protected'
    }
}

Describe 'Add-VaultSecret.when a secret already exists' {
    It 'should fail' {
        Init
        GivenSecret 'fubar' -WithValue 'snafu' -InVault 'existing'
        WhenAddingSecret 'fubar' -WithValue 'newsnafu' -ToVault 'existing' -ErrorAction SilentlyContinue
        ThenReturned -Nothing
        ThenFailed -WithErrorMatching '"existing" vault in the Verification environment already contains secret "fubar"'
        ThenSecret 'fubar' -InVault 'existing' -HasValue 'snafu'
    }
}

Describe 'Add-VaultSecret.when overwriting existing secret' {
    It 'should overwrite secret' {
        Init
        GivenSecret 'fubar' -WithValue 'snafu' -InVault 'existing'
        WhenAddingSecret 'fubar' -WithValue 'newsnafu' -ToVault 'existing' -ReplacingExisting
        ThenSecret 'fubar' -InVault 'existing' -HasValue 'newsnafu'
        ThenReturned -Nothing
    }
}

Describe 'Add-VaultSecret.when using -PassThru' {
    It 'should return configuration object' {
        Init
        WhenAddingSecret 'fubar' -WithValue 'newsnafu' -ToVault 'existing' -WithPassThru
        ThenSecret 'fubar' -InVault 'existing' -HasValue 'newsnafu'
        ThenReturned -ConfigurationObject
    }
}