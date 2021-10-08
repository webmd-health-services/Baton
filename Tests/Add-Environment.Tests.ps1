

#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$result = $null
$testDir = $null
$testNum = 0
$config = $null

function GivenEnvironment
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String] $Named
    )
    
    $script:config | Add-CfgEnvironment -Name $Named
}

function Init
{
    $Global:Error.Clear()

    $script:result = $null

    $script:testDir = Join-Path -Path $TestDrive.FullName -ChildPath (++$testNum)
    New-Item -Path $script:testDir -ItemType 'Directory'

    $script:config = New-CfgConfigurationObject
}

function ThenAddedEnv
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Named
    )

    $env = $script:config | Get-CfgEnvironment -Name $Named
    $env | Should -Not -BeNullOrEmpty
    $env.Name | Should -Be $Named
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

function ThenNotAddedEnv {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String] $Named
    )
    
    $script:config | Get-CfgEnvironment -Name $Named | Should -HaveCount 1
}

function ThenReturnedEnv
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String] $Named
    )

    $script:result | Should -Not -BeNullOrEmpty
    $script:result | ShouldBeOfBatonType 'Configuration'
}


function ThenReturnedNothing
{
    $script:result | Should -BeNullOrEmpty
}

function WhenAddingEnv
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Named,

        [switch] $AndUsingPassThru
    )

    $optionalParams = @{}
    if( $AndUsingPassThru )
    {
        $optionalParams['PassThru'] = $AndUsingPassThru
    }

    $script:result = $script:config | Add-CfgEnvironment -Name $Named @optionalParams
}

Describe 'Add-Environment.when environment does not exist' {
    It 'should create the environment' {
        Init
        WhenAddingEnv 'new'
        ThenReturnedNothing
        ThenAddedEnv 'new'
    }
}

Describe 'Add-Environment.when environment already exists' {
    It 'should fail' {
        Init
        GivenEnvironment 'existing'
        WhenAddingEnv 'existing' -ErrorAction SilentlyContinue
        ThenReturnedNothing
        ThenNotAddedEnv 'existing'
        ThenFailed -WithErrorMatching '"existing": that environment already exists'
    }
}

Describe 'Add-Environment.when using PassThru switch' {
    It 'should return configuration object' {
        Init
        WhenAddingEnv 'passedthru' -AndUsingPassThru
        ThenReturnedEnv 'passedthru'
        ThenAddedenv 'passedthru'
    }
}