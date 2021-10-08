
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$filePath = $null
$result = $null
$testDir = $null
$testNum = 0

function GivenFile
{
    param(
        [String] $Named
    )

    $script:filePath = Join-Path -Path $script:testDir -ChildPath $Named
    New-Item -Path $script:filePath -ItemType 'File'
}

function Init
{
    $script:result = $null
    $script:testDir = Join-Path -Path $TestDrive.FullName -ChildPath (++$script:testNum)
    New-Item -Path $script:testDir -ItemType 'Directory'
}

function ThenConfigCreated
{
    param(
        $WithPath = '',

        $WithConfigRoot = ''
    )

    $script:result | ShouldBeOfBatonType 'Configuration'
    
    $script:result | Get-Member -Name 'Path' | Should -Not -BeNullOrEmpty
    $script:result.Path | Should -Be $WithPath
    $script:result | Get-Member -Name 'ConfigurationRoot' | Should -Not -BeNullOrEmpty
    $script:result.ConfigurationRoot | Should -Be $WithConfigRoot
    $script:result | Get-Member -Name 'Environments' | Should -Not -BeNullOrEmpty
    ,$script:result.Environments | Should -BeOfType [Collections.ArrayList]
    $script:result.Environments | Should -HaveCount 0
}

function ThenFailed
{
    param(
        [String] $WithErrorMatching
    )

    $Global:Error | Should -Not -BeNullOrEmpty
    $script:result | Should -BeNullOrEmpty

    if( $WithErrorMatching )
    {
        $Global:Error | Should -Match $WithErrorMatching
    }
}

function WhenCreatingConfig
{
    [CmdletBinding()]
    param(
        [String] $ForPath
    )

    $params = @{}
    if( $ForPath )
    {
        $params['Path'] = $ForPath
    }

    $script:result = New-CfgConfigurationObject @params
}

Describe 'New-ConfigurationObject.when called with no parameters' {
    It 'should return a configuration object' {
        Init
        WhenCreatingConfig
        ThenConfigCreated
    }
}

Describe 'New-ConfigurationObject.when called with path that does not exist' {
    It 'should fail' {
        Init
        WhenCreatingConfig -ForPath 'SomePath' -ErrorAction SilentlyContinue
        ThenFailed -WithErrorMessageMatching 'does not exist'
    }
}

Describe 'New-ConfigurationObject.when called with path' {
    It 'should return configuration object' {
        Init
        GivenFile -Named 'baton.json'
        WhenCreatingConfig -ForPath $script:filePath
        ThenConfigCreated -WithPath $script:filePath -WithConfigRoot ($script:filePath | Split-Path)
    }
}
