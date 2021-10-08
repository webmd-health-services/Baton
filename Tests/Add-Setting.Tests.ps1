
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$result = $null
$testDir = $null
$testNum = 0
$config = $null

function GivenSetting
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Named,

        [Parameter(Mandatory)]
        [String] $WithValue,

        [String] $InEnvironment = 'Verification'
    )

    $script:config | Add-CfgSetting -Environment $InEnvironment -Name $Named -Value $WithValue
}

function Init
{
    $Global:Error.Clear()

    $script:result = $null

    $script:testDir = Join-Path -Path $TestDrive.FullName -ChildPath (++$testNum)
    New-Item -Path $script:testDir -ItemType 'Directory'

    $script:config = New-CfgConfigurationObject
}

function ThenConfigReturned
{
    [CmdletBinding()]
    param(
    )

    $script:result | Should -Not -BeNullOrEmpty
    $script:result | ShouldBeOfBatonType 'Configuration'
}

function ThenEnv
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Named,

        [Parameter(Mandatory)]
        [switch] $Exists
    )

    $script:config | Get-CfgEnvironment -Name $Named | Should -Not -BeNullOrEmpty
}

function ThenFailed
{
    [CmdletBinding()]
    param(
        [String] $WithErrorMatching
    )

    $Global:Error | Should -Not -BeNullOrEmpty
    if( $WithErrorMatching )
    {
        $Global:Error | Should -Match $WithErrorMatching
    }
}

function ThenNoError
{
    $Global:Error | Should -BeNullOrEmpty
}

function ThenNothingReturned
{
    $script:result | Should -BeNullOrEmpty
}

function ThenSetting
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Named,

        [Parameter(Mandatory)]
        [String] $HasValue,

        [String] $InEnvironment = 'Verification'
    )

    $value = $script:config | Get-CfgSetting -Environment $InEnvironment -Name $Named
    $value | Should -Be $HasValue
}

function WhenAddingSetting
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Named,

        [Parameter(Mandatory)]
        [String] $ToValue,

        [String] $ToEnvironment = 'Verification',

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
        $script:config | Add-CfgSetting -Environment $ToEnvironment -Name $Named -Value $ToValue @optionalParams
}



Describe 'Add-Setting.when environment does not exist' {
    It 'should create environment' {
        Init
        WhenAddingSetting 'one' -ToValue 'two' -ToEnvironment 'Verification'
        ThenNothingReturned
        ThenEnv 'Verification' -Exists
        ThenSetting 'one' -HasValue 'two' -InEnvironment 'Verification'
    }
}

Describe 'Add-Setting.when setting already exists' {
    It 'should fail' {
        Init
        GivenSetting 'three' -WithValue 'four'
        WhenAddingSetting 'three' -ToValue 'five' -ErrorAction SilentlyContinue
        ThenNothingReturned
        ThenSetting 'three' -HasValue 'four'
        ThenFailed -WithErrorMatching '"three" already exists'
    }
}

Describe 'Add-Setting.when setting already exists and forcing' {
    It 'should overwrite setting value' {
        Init
        GivenSetting 'six' -WithValue 'seven'
        WhenAddingSetting 'six' -ToValue 'eight' -ReplacingExisting
        ThenNothingReturned
        ThenSetting 'six' -HasValue 'eight'
        ThenNoError
    }
}

Describe 'Add-Setting.when using PassThru switch' {
    It 'should return configuration object' {
        Init
        WhenAddingSetting 'nine' -ToValue 'ten' -WithPassThru
        ThenSetting 'nine' -HasValue 'ten'
        ThenNoError
        ThenConfigReturned
    }
}