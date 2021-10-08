

#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$result = $null
$testDir = $null
$testNum = 0
$config = $null

function GivenVault
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String] $ForKey,

        [Parameter(Mandatory)]
        [String] $InEnvironment
    )
    
    $script:config | Add-CfgVault -Environment $InEnvironment -Key $ForKey
}

function Init
{
    $Global:Error.Clear()

    $script:result = $null

    $script:testDir = Join-Path -Path $TestDrive.FullName -ChildPath (++$testNum)
    New-Item -Path $script:testDir -ItemType 'Directory'

    $script:config = New-CfgConfigurationObject
}

function ThenAddedVault
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $ForKey,

        [Parameter(Mandatory)]
        [String] $InEnvironment
    )

    $vault = $script:config | Get-CfgVault -Environment $InEnvironment -Key $ForKey
    $vault | Should -Not -BeNullOrEmpty
    $vault.Key | Should -Be $ForKey
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

function ThenNotAddedVault {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String] $ForKey,

        [Parameter(Mandatory)]
        [String] $InEnvironment
    )
    
    $script:config | Get-CfgVault -Environment $InEnvironment -Key $ForKey | Should -HaveCount 1
}

function ThenReturnedVault
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String] $ForKey
    )

    $script:result | Should -Not -BeNullOrEmpty
    $script:result | ShouldBeOfBatonType 'Configuration'
}


function ThenReturnedNothing
{
    $script:result | Should -BeNullOrEmpty
}

function WhenAddingVault
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $ForKey,

        [Parameter(Mandatory)]
        [String] $InEnvironment,

        [switch] $AndUsingPassThru
    )

    $optionalParams = @{}
    if( $AndUsingPassThru )
    {
        $optionalParams['PassThru'] = $AndUsingPassThru
    }

    $script:result = $script:config | Add-CfgVault -Environment $InEnvironment -Key $ForKey @optionalParams
}

Describe 'Add-Vault.when vault does not exist' {
    It 'should create the vault' {
        Init
        WhenAddingVault 'new' -InEnvironment 'E1'
        ThenReturnedNothing
        ThenAddedVault 'new' -InEnvironment 'E1'
    }
}

Describe 'Add-Vault.when vault already exists' {
    It 'should fail' {
        Init
        GivenVault 'existing' -InEnvironment 'E2'
        WhenAddingVault 'existing' -InEnvironment 'E2' -ErrorAction SilentlyContinue
        ThenReturnedNothing
        ThenNotAddedVault 'existing' -InEnvironment 'E2'
        ThenFailed -WithErrorMatching '"existing": a vault using that key already exists'
    }
}

Describe 'Add-Vault.when using PassThru switch' {
    It 'should return configuration object' {
        Init
        WhenAddingVault 'passedthru' -InEnvironment 'E3' -AndUsingPassThru
        ThenReturnedVault 'passedthru'
        ThenAddedVault 'passedthru' -InEnvironment 'E3'
    }
}