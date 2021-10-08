
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$result = $null
$testDir = $null
$testNum = 0

function Init
{
    $script:result = $null
    $script:testDir = Join-Path -Path $TestDrive.FullName -ChildPath (++$script:testNum)
    New-Item -Path $script:testDir -ItemType 'Directory'
}

function ThenCreatedEnv
{
    [CmdletBinding()]
    param(
        [String] $WithName,

        [String] $ThatInheritsFrom = '',

        [hashtable] $WithSettings = @{}
    )

    $script:result | ShouldBeOfBatonType 'Environment'

    $script:result | Get-Member -Name 'Name' | Should -Not -BeNullOrEmpty
    $script:result.Name | Should -BeOfType [String]
    $script:result.Name | Should -Be $WithName

    $script:result | Get-Member -Name 'InheritsFrom' | Should -Not -BeNullOrEmpty
    $script:result.InheritsFrom | Should -BeOfType [String]
    $script:result.InheritsFrom | Should -Be $ThatInheritsFrom

    $script:result | Get-Member -Name 'Settings' | Should -Not -BeNullOrEmpty
    ,$script:result.Settings | Should -BeOfType [hashtable]
    $script:result.Settings.Count | Should -Be $WithSettings.Count

    foreach( $key in $WithSettings.Keys )
    {
        $script:result.Settings.Contains($key) | Should -BeTrue -Because "setting ""$($key)"" not set"
        $script:result.Settings[$key] | Should -Be $WithSettings[$key]
    }

    $script:result | Get-Member -Name 'Vaults' | Should -Not -BeNullOrEmpty
    ,$script:result.Vaults | Should -BeOfType [Collections.ArrayList]
    $script:result.Vaults | Should -HaveCount 0
}

function WhenCreatingEnv
{
    [CmdletBinding()]
    param(
        [String] $WithName,

        [String] $ThatInheritsFrom,

        [Object] $WithSettings
    )

    $params = @{
        'Name' = $WithName
    }

    if( $PSBoundParameters.ContainsKey('ThatInheritsFrom') )
    {
        $params['InheritsFrom'] = $ThatInheritsFrom
    }

    if( $PSBoundParameters.ContainsKey('WithSettings') )
    {
        $params['Settings'] = $WithSettings
    }

    $script:result = New-CfgEnvironmentObject @params
}

Describe 'New-EnvironmentObject.when called with only mandatory parameters' {
    It 'should set only mandatory properties' {
        Init
        WhenCreatingEnv -WithName 'onlymandatory'
        ThenCreatedEnv -WithName 'onlymandatory'
    }
}


Describe 'New-EnvironmentObject.when called with all parameters' {
    It 'should set all properties' {
        Init
        $settings = @{ 'One' = 1; 'Two' = 2; 'Three' = 3; }
        WhenCreatingEnv -WithName 'all' -ThatInheritsFrom 'onlymandatory' -WithSettings $settings
        ThenCreatedEnv -WithName 'all' -ThatInheritsFrom 'onlymandatory' -WithSettings $settings
    }
}

Describe 'New-EnvironmentObject.when settings is an object' {
    It 'should store property values in settings hashtable' {
        Init
        $settings = @{ 'Four' = 4; 'Five' = 5; 'Six' = 6; }
        WhenCreatingEnv -WithName 'all' -WithSettings ([pscustomobject]$settings)
        ThenCreatedEnv -WithName 'all' -WithSettings $settings
    }
}