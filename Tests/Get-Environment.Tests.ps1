
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

    $script:configPath = Join-Path -Path $script:testDir -ChildPath 'baton.json'

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

function ThenEnvReturned
{
    [CmdletBinding()]
    param(
        [String[]] $Named
    )

    $script:result | Should -Not -BeNullOrEmpty
    $script:result | Should -HaveCount $Named.Length

    for( $idx = 0; $idx -lt $Named.Length; ++$idx )
    {
        $actualEnv = $script:result[$idx]
        $expectedEnvName = $Named[$idx]

        $actualEnv | Get-Member -Name 'Name' | Should -Not -BeNullOrEmpty
        $actualEnv.Name | Should -Be $expectedEnvName
    }
}

function ThenError
{
    [CmdletBinding()]
    param(
        [String] $WithErrorMatching
    )

    $Global:Error | Should -Not -BeNullOrEmpty
    $Global:Error | Should -Match $WithErrorMatching
}

function ThenNoError
{
    $Global:Error | Should -BeNullOrEmpty
}

function ThenNothingReturned
{
    $script:result | Should -BeNullOrEmpty
}

function WhenGettingEnv
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [String] $Named,

        [switch] $FromDefaultConfigFile
    )

    if( $FromDefaultConfigFile )
    {
        $script:result = Get-CfgEnvironment -Name $Named
        return
    }

    $script:result = Import-CfgConfiguration -LiteralPath $script:configPath | Get-CfgEnvironment -Name $Named
}

Describe 'Get-Environment.when environment does not exist' {
    It 'should fail' {
        Init
        GivenConfig '{ "Environments": { "Name": "Verification" } }'
        WhenGettingEnv 'Snafu' -ErrorAction SilentlyContinue
        ThenNothingReturned
        ThenFailed '"Snafu" does not exist'
    }
}

Describe 'Get-Environment.when environment does not exist and ignoring errors' {
    It 'should not fail' {
        Init
        GivenConfig '{ "Environments": { "Name": "Verification" } }'
        WhenGettingEnv 'Snafu' -ErrorAction Ignore
        ThenNothingReturned
        ThenNoError
    }
}

Describe 'Get-Environment.when environment exists' {
    It 'should return the item' {
        Init
        GivenConfig '{ "Environments": { "Name": "Verification" } }'
        WhenGettingEnv 'Verification'
        ThenNoError
        ThenEnvReturned 'Verification'
    }
}

Describe 'Get-Environment.when environment inherits from another environment' {
    It 'should return the item' {
        Init
        GivenConfig @'
{ 
    "Environments": [
        {
            "Name": "YAE"
        },
        {
            "Name": "Verification",
            "InheritsFrom": "SomeOtherEnv"
        },
        {
            "Name": "SomeOtherEnv",
            "InheritsFrom": "YAE"
        }
    ]
}
'@
        WhenGettingEnv 'Verification'
        ThenNoError
        ThenEnvReturned 'Verification', 'SomeOtherEnv', 'YAE'
    }
}

Describe 'Get-Environment.when parent environment does not exist' {
    It 'should fail and return child environments' {
        Init
        GivenConfig @'
{ 
    "Environments": [
        {
            "Name": "Verification",
            "InheritsFrom": "SomeOtherEnv"
        },
        {
            "Name": "SomeOtherEnv",
            "InheritsFrom": "YAE"
        }
    ]
}
'@
        WhenGettingEnv 'Verification' -ErrorAction SilentlyContinue
        ThenFailed
        ThenEnvReturned 'Verification', 'SomeOtherEnv'
        ThenError '"YAE", inherited by environment "SomeOtherEnv", does not exist'
    }
}

Describe 'Get-Environment.when environment inheritance is circular' {
    It 'should fail and return child environments' {
        Init
        GivenConfig @'
{ 
    "Environments": [
        {
            "Name": "Verification",
            "InheritsFrom": "SomeOtherEnv"
        },
        {
            "Name": "SomeOtherEnv",
            "InheritsFrom": "YAE"
        },
        {
            "Name": "YAE",
            "InheritsFrom": "Verification"
        }
    ]
}
'@
        WhenGettingEnv 'Verification' -ErrorAction SilentlyContinue
        ThenFailed
        ThenEnvReturned 'Verification', 'SomeOtherEnv', 'YAE'
        ThenError ([regex]::Escape('Verification -> SomeOtherEnv -> YAE -> Verification'))
    }
}

Describe 'Get-Environment.when not piping configuration object' {
    It 'should return default configuration' {
        Init
        GivenConfig '{ "Environments": [ { "Name": "Pipe1" }, { "Name": "Pipe2" } ] }'
        Mock -CommandName 'Import-Configuration' `
             -ModuleName 'Baton' `
             -ParameterFilter { -not $LiteralPath } `
             -MockWith ([scriptblock]::Create("Import-Configuration -LiteralPath '$($script:configPath)'")) `
             -Verifiable
        WhenGettingEnv 'Pipe2' -FromDefaultConfigFile
        Assert-VerifiableMock
        ThenNoError
        ThenEnvReturned 'Pipe2'
    }
}