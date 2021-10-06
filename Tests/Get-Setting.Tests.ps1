
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$script:configPath = $null
$script:result = $null
$script:testDir = $null

function GivenConfig
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Content
    )

    $script:configPath = Join-Path -Path $testDir -ChildPath 'baton.json'
    Set-Content -LiteralPath $script:configPath -Value $Content
}


function Init
{
    $Global:Error.Clear()
    $script:configPath = $null
    $script:result = $null
    $script:testDir = Join-Path -Path $TestDrive.FullName -ChildPath ([IO.Path]::GetRandomFileName())
    New-Item -Path $testDir -ItemType 'Directory'
}

function ThenFailed
{
    [CmdletBinding()]
    param(
        [String] $WithErrorMatching
    )

    $Global:Error | Should -Not -BeNullOrEmpty
    $Global:Error | Should -Match $WithErrorMatching
}

function ThenNoErrors
{
    $Global:Error | Should -BeNullOrEmpty
}

function ThenNothingReturned
{
    $script:result | Should -BeNullOrEmpty
}

function ThenReturned
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [Object] $Value
    )

    $script:result | Should -Be $Value
}

function WhenGetting
{
    [CmdletBinding()]
    param(
        [String] $Named,

        [switch] $FromDefaultConfigFile,

        [switch] $FromAllEnvironments
    )

    if( $FromDefaultConfigFile )
    {
        Mock -CommandName 'Import-Configuration' `
             -ModuleName 'Baton' `
             -ParameterFilter { -not $LiteralPath } `
             -MockWith ([scriptblock]::Create("Import-Configuration -LiteralPath '$($script:configPath)'")) `
             -Verifiable
        $script:result = Get-CfgSetting -Environment 'Verification' -Name $Named
        Assert-VerifiableMock
        return
    }

    $forceParam = @{}
    if( $FromAllEnvironments )
    {
        $forceParam['Force'] = $true
    }

    $script:result =
        Import-CfgConfiguration -LiteralPath $script:configPath |
        Get-CfgSetting -Environment 'Verification' -Name $Named @forceParam
}

Describe 'Get-Setting.when setting does not exist' {
    It 'should fail' {
        Init
        GivenConfig '{ "Environments": { "Name": "Verification", "Settings": { } } }'
        WhenGetting 'Fubar' -ErrorAction SilentlyContinue
        ThenNothingReturned
        ThenFailed '"Fubar" not found in "Verification" environment\.'
    }
}

Describe 'Get-Setting.when setting does not exist in environment or any parent environment' {
    It 'should fail' {
        Init
        GivenConfig @'
{
    "Environments": [
        { "Name": "3" },
        { "Name": "2", "InheritsFrom": "3" },
        { "Name": "Verification", "InheritsFrom": "2" }
    ]
}
'@
        WhenGetting 'missing' -ErrorAction SilentlyContinue
        ThenNothingReturned
        $expectedPattern = 
            '"missing" not found in "Verification" environment or any of its parent environments: 2 -> 3.'
        ThenFailed ([regex]::Escape($expectedPattern))
    }
}

Describe 'Get-Setting.when setting exists' {
    It 'should return vaule' {
        Init
        GivenConfig '{ "Environments": { "Name": "Verification", "Settings": { "Setting": "Value" } } }'
        WhenGetting 'Setting'
        ThenNoErrors
        ThenReturned 'Value'
    }
}

Describe 'Get-Setting.when value evaluates to false' {
    $values = @{
        '""' = '';
        '0' = 0;
        'false' = $false;
        'null' = $null;
    }
    foreach( $key in $values.Keys )
    {
        $config =
            "{ ""Environments"": { ""Name"": ""Verification"", ""Settings"": { ""FalseValue"": $($key) } } }"
        Context $key {
            It 'should still return the value' {
                Init
                GivenConfig $config
                WhenGetting 'FalseValue'
                ThenNoErrors
                ThenReturned $values[$key]
            }
        }
    }
}

Describe 'Get-Setting.when setting is in parent environment' {
    It 'should return the value' {
        Init
        GivenConfig @'
{
    "Environments": [
        { "Name": "3", "Settings": { "Parent": "V3" } },
        { "Name": "2", "InheritsFrom": "3" },
        { "Name": "Verification", "InheritsFrom": "2" }
    ]
}
'@
        WhenGetting 'Parent'
        ThenNoErrors
        ThenReturned 'V3'
    }
}

Describe 'Get-Setting.when value is in an environment and parent environment' {
    It 'should return the value from the child environment' {
        Init
        GivenConfig @'
{
    "Environments": [
        { "Name": "3", "Settings": { "Parent": "V3" } },
        { "Name": "2", "InheritsFrom": "3", "Settings": { "Parent": "V2" } },
        { "Name": "Verification", "InheritsFrom": "2", "Settings": { "Parent": "V1" } }
    ]
}
'@
        WhenGetting 'Parent'
        ThenNoErrors
        ThenReturned 'V1'
    }
}

Describe 'Get-Setting.when not passing the configuration to search' {
    It 'should load the default config' {
        Init
        GivenConfig '{ "Environments": { "Name": "Verification", "Settings": { "DefaultConfig": "True" } } }'
        WhenGetting 'DefaultConfig' -FromDefaultConfigFile
        ThenNoErrors
        ThenReturned 'True'
    }
}

Describe 'Get-Setting.when forcing return of all values' {
    It 'should return values from all environments' {
        Init
        GivenConfig @'
{
    "Environments": [
        { "Name": "3", "Settings": { "Forced": "E3" } },
        { "Name": "2", "InheritsFrom": "3" },
        { "Name": "Verification", "InheritsFrom": "2", "Settings": { "Forced": "E1" } }
    ]
}
'@
        WhenGetting 'Forced' -FromAllEnvironments
        ThenNoErrors
        ThenReturned 'E1', 'E3'
    }
}