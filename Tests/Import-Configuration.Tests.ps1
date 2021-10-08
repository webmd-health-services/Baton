
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$path = $null
$result = $null
$testDir = $null
$testNum = 0

function GivenConfigJson
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $Json,

        $InFileNamed = 'baton.json'
    )

    $script:path = Join-Path -Path $script:testDir -ChildPath $InFileNamed

    $parentDir = $script:path | Split-Path
    if( -not (Test-Path -Path $parentDir -PathType Container) )
    {
        New-Item -Path $parentDir -ItemType 'Directory' -Force
    }

    $Json | Set-Content -LiteralPath $path
}

function Init
{
    $Global:Error.Clear()
    $script:testDir = Join-Path -Path $TestDrive.FullName -ChildPath ($testNum++)
    New-Item -Path $script:testDir -ItemType 'Directory'
    $script:path = Join-Path -Path $script:testDir -ChildPath "baton.json"
    $script:result = $null
}

function ThenConfigReturned
{
    [CmdletBinding()]
    param(
        [int] $WithEnvironmentCount,

        [Parameter(ValueFromPipeline)]
        [Object] $InputObject = $script:result,

        [String] $FromFileNamed
    )

    process
    {
        if( $FromFileNamed )
        {
            $expectedPath = Join-Path -Path $script:testDir -ChildPath $FromFileNamed
        }
        else
        {
            $expectedPath = $script:path
        }
        $InputObject | Should -HaveCount 1
        $InputObject | Should -BeOfType [pscustomobject]
        $InputObject | Get-Member -Name 'Environments' | Should -Not -BeNullOrEmpty
        ,$InputObject.Environments | Should -BeOfType [Collections.ArrayList]
        $InputObject | Get-Member -Name 'Path' | Should -Not -BeNullOrEmpty
        $InputObject.Path | Should -BeOfType [String]
        $InputObject.Path | Should -Be $expectedPath
        $InputObject.ConfigurationRoot | Should -BeOfType [String]
        $InputObject.ConfigurationRoot | Should -Be ($expectedPath | Split-Path)

        $InputObject.Environments.Count | Should -Be $WithEnvironmentCount
    }
}

function ThenEnvironment
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [String] $Named,

        [Parameter(ValueFromPipeline)]
        [Object] $InputObject = $script:result,

        [Parameter(Mandatory, ParameterSetName='Environment')]
        [switch] $Exists,

        [Parameter(ParameterSetName='Environment')]
        [String] $InheritsFrom = '',

        [Parameter(ParameterSetName='Environment')]
        [hashtable] $WithSettings = @{},

        [Parameter(ParameterSetName='Environment')]
        [int] $HasVaultCount = 0,

        [Parameter(Mandatory, ParameterSetName='Vault')]
        [switch] $HasVault,

        [Parameter(Mandatory, ParameterSetName='Vault')]
        [String] $WithKey,

        [Parameter(ParameterSetName='Vault')]
        [String] $WithSymmetricKeyDecryptionKey = '',

        [Parameter(ParameterSetName='Vault')]
        [hashtable] $WithSecrets = @{}
    )

    process
    {
        $env = $result.Environments | Where-Object 'Name' -EQ $Named
        $env | Should -Not -BeNullOrEmpty
        $env | Should -HaveCount 1

        $env | Get-Member -Name 'Vaults' | Should -Not -BeNullOrEmpty

        if( $Exists )
        {
            $env.Vaults | Should -HaveCount $HasVaultCount

            $env | Get-Member -Name 'InheritsFrom' | Should -Not -BeNullOrEmpty
            $env.InheritsFrom | Should -BeOfType [String]
            $env.InheritsFrom | Should -Be $InheritsFrom
            
            $env | Get-Member -Name 'Settings' | Should -Not -BeNullOrEmpty
            $env.Settings | Should -BeOfType [Collections.IDictionary]
            $env.Settings.Count | Should -Be $WithSettings.Count
            foreach( $name in $WithSettings.Keys )
            {
                $env.Settings[$name] | Should -Be $WithSettings[$name]
            }
        }

        foreach( $vault in $env.Vaults )
        {
            $vault | Should -Not -BeNullOrEmpty
            $vault | Get-Member -Name 'Key' | Should -Not -BeNullOrEmpty
            $vault.Key | Should -BeOfType [String]
            $vault | Get-Member -Name 'KeyDecryptionKey' | Should -Not -BeNullOrEmpty
            $vault.KeyDecryptionKey | Should -BeOfType [String]
            $vault | Get-Member -Name 'Secrets' | Should -Not -BeNullOrEmpty
            $vault.Secrets | Should -BeOfType [Collections.IDictionary]
        }

        if( $HasVault )
        {
            $vault = $env.Vaults | Where-Object 'Key' -EQ $WithKey
            $vault | Should -Not -BeNullOrEmpty
            $vault | Should -BeOfType [pscustomobject]

            $vault | Get-Member -Name 'KeyDecryptionKey' | Should -Not -BeNullOrEmpty
            $vault.KeyDecryptionKey | Should -Be $WithSymmetricKeyDecryptionKey

            $vault | Get-Member -Name 'Secrets' | Should -Not -BeNullOrEmpty
            $vault.Secrets | Should -BeOfType [Collections.IDictionary]
            $vault.Secrets.Count | Should -Be $WithSecrets.Count
            foreach( $name in $WithSecrets.Keys )
            {
                $vault.Secrets[$name] | Should -Be $WithSecrets[$name]
            }
        }
    }
}

function ThenFailed
{
    [CmdletBinding()]
    param(
        [String] $WithErrorMessageMatching
    )

    $result | Should -BeNullOrEmpty
    $Global:Error | Should -Not -BeNullOrEmpty

    if( $WithErrorMessageMatching )
    {
        $Global:Error | Select-Object -First 1 | Should -Match ([regex]::Escape($WithErrorMessageMatching))
    }
}

function WhenImporting
{
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName='FromExplicitPath', Position=0)]
        [String] $Path = $script:path,

        [Parameter(Mandatory, ParameterSetName='FromDefaultPath')]
        [switch] $FromDefaultConfigFile,

        [Parameter(Mandatory, ParameterSetName='FromPipeline')]
        [Object[]]$FromPipelineWithTheseObjects
    )

    if( $FromPipelineWithTheseObjects )
    {
        $script:result = $FromPipelineWithTheseObjects | Import-CfgConfiguration
        return
    }

    $literalPathParam = @{}
    if( -not $FromDefaultConfigFile )
    {
        $literalPathParam['LiteralPath'] = $Path
    }
    $script:result = Import-CfgConfiguration @literalPathParam
}

Describe 'Import-Configuration.when passed an empty file' {
    It 'should return an object with default properties' {
        Init
        GivenConfigJson ''
        WhenImporting
        ThenConfigReturned -WithEnvironmentCount 0
    }
}

Describe 'Import-Configuration.when file does not exist' {
    It 'should fail' {
        Init
        WhenImporting -ErrorAction SilentlyContinue
        ThenFailed -WithErrorMessageMatching 'does not exist'
    }
}

Describe 'Import-Configuation.when file has wildcard characters in name' {
    It 'should load configuration' {
        Init
        GivenConfigJson '' -InFileNamed '[].json'
        WhenImporting
        ThenConfigReturned -WithEnvironmentCount 0
    }
}

Describe 'Import-Configuation.when passed relative path' {
    It 'should load configuration' {
        Init
        GivenConfigJson ''
        $parentDir = $path | Split-Path | Split-Path -Leaf
        $grandParentDir = $path | Split-Path | Split-Path | Split-Path -Leaf
        Push-Location -Path ($path | Split-Path | Split-Path | Split-Path)
        try
        {
            WhenImporting "$($grandParentDir)\$($parentDir)\$($path | Split-Path -Leaf)"
            ThenConfigReturned -WithEnvironmentCount 0
        }
        finally
        {
            Pop-Location
        }
    }
}

Describe 'Import-Configuration.when file contains invalid JSON' {
    It 'should fail' {
        Init
        GivenConfigJson '{'
        WhenImporting -ErrorAction SilentlyContinue
        ThenFailed -WithErrorMessageMatching 'error parsing JSON'
    }
}

Describe 'Import-Configuration.when file doesn''t contain JSON object' {
    It 'should fail' {
        Init
        GivenConfigJson '"bad"'
        WhenImporting -ErrorAction SilentlyContinue
        ThenFailed -WithErrorMessageMatching 'expected to get an object after parsing'
    }
}

Describe 'Import-Configuration.when environment has no name' {
    It 'should fail' {
        Init
        GivenConfigJson '{ "Environments": [ { } ] }'
        WhenImporting -ErrorAction SilentlyContinue
        ThenFailed -WithErrorMessageMatching 'Environment 1 doesn''t have a "Name" property'
    }
}

Describe 'Import-Configuration.when environment only has a name' {
    It 'should return object with all properties set to sensible defaults' {
        Init
        GivenConfigJson '{ "Environments": [ { "Name": "Verification" } ] }'
        WhenImporting
        ThenConfigReturned -WithEnvironmentCount 1
        ThenEnvironment "Verification" -Exists
    }
}

Describe 'Import-Configuration.when configuration is full' {
    It 'should return full object' {
        Init
        GivenConfigJson @'
{
    "Environments": [
        {
            "Name": "Verification",
            "Settings": {
                "Minus1": "Minus2"
            },
            "Vaults": [
                {
                    "Key": "minus3",
                    "Secrets": {
                        "minus4": "minus5"
                    }
                }
            ]
        },
        {
            "Name" : "Two",
            "InheritsFrom": "Verification",
            "Settings": {
                "One": "Two",
                "Three": "Four"
            },
            "Vaults": [
                {
                    "Key": "symmetrickey",
                    "KeyDecryptionKey": "deadbee",
                    "Secrets": {
                        "five": "six",
                        "seven": "eight"
                    }
                },
                {
                    "Key": "eebdaed",
                    "Secrets": {
                        "nine": "ten"
                    }
                }
            ]
        }
    ]
}
'@
        WhenImporting
        ThenConfigReturned -WithEnvironmentCount 2
        ThenEnvironment "Verification" -Exists -WithSettings @{"Minus1" = "Minus2" } -HasVaultCount 1
        ThenEnvironment 'Verification' -HasVault -WithKey 'minus3' -WithSecrets @{ 'minus4' = 'minus5' }
        ThenEnvironment 'Two' `
                        -Exists `
                        -InheritsFrom "Verification" `
                        -WithSettings @{ "One" = "Two"; "Three" = "Four" } `
                        -HasVaultCount 2
        ThenEnvironment 'Two' `
                        -HasVault `
                        -WithSymmetricKeyDecryptionKey 'deadbee' `
                        -WithKey 'symmetrickey' `
                        -WithSecrets @{ 'five' = 'six' ; 'seven' = 'eight' }
        ThenEnvironment 'Two' -HasVault -WithKey 'eebdaed' -WithSecrets @{ 'nine' = 'ten' }
        
    }
}

Describe 'Import-Configuration.when a vault is missing its key' {
    It 'should return full object' {
        Init
        GivenConfigJson @'
{
    "Environments": [
        {
            "Name": "Verification",
            "Settings": { },
            "Vaults": [
                {
                    "Secrets": { }
                }
            ]
        }
    ]
}
'@
        WhenImporting -ErrorAction SilentlyContinue
        ThenFailed -WithErrorMessageMatching 'vault must have a "Key" property'
    }
}

Describe 'Import-Configuration.when Environments and Vaults are single objects' {
    It 'should parse json' {
        Init
        GivenConfigJson @'
{
    "Environments": {
        "Name": "Verification",
        "InheritsFrom": "Default",
        "Vaults": {
            "Key": "symmetrickey",
            "KeyDecryptionKey": "yolo",
            "Secrets": {
                "hello": "world"
            }
        }
    }
}
'@
        WhenImporting
        ThenEnvironment 'Verification' -Exists -InheritsFrom 'Default' -HasVaultCount 1
        ThenEnvironment 'Verification' `
                        -HasVault `
                        -WithSymmetricKeyDecryptionKey 'yolo' `
                        -WithKey 'symmetrickey' `
                        -WithSecrets @{ 'hello' = 'world' }
    }
}

Describe 'Importing-Configuration.when importing default baton.json' {
    It 'should return configuration from file in current directory' {
        Init
        GivenConfigJson '{ "Environments": { "Name": "DefaultConfig" } }'
        Mock -CommandName 'Find-ConfigurationPath' `
             -ModuleName 'Baton' `
             -MockWith ([scriptblock]::Create("return '$($script:path)'")) `
             -Verifiable
        WhenImporting -FromDefaultConfigFile
        Assert-VerifiableMock
        ThenConfigReturned -WithEnvironmentCount 1
        ThenEnvironment 'DefaultConfig' -Exists
    }
}

Describe 'Importing-Configuration.when importing specific files and directories' {
    It 'should return configuration objects for each file and baton JSON files in directories' {
        Init
        GivenConfigJson '{ "Environments": { "Name": "CustomJson" } }' -InFileNamed 'custom.json'
        GivenConfigJson '{ "Environments": { "Name": "Deprecated" } }' -InFileNamed 'deprecated.json'
        GivenConfigJson '{ "Environments": { "Name": "InDir1" } }' -InFileNamed 'dir1\baton.json'
        GivenConfigJson '{ "Environments": { "Name": "InDir2" } }' -InFileNamed 'dir2\baton.json'
        $itemsToPipe = & {
            Get-ChildItem -Path $script:testdir -Filter '*.json'
            Get-ChildItem -Path $script:testdir -Filter 'dir*'
        }
        WhenImporting -FromPipelineWithTheseObjects $itemsToPipe
        $script:result | Should -HaveCount 4

        $customConfig = $script:result | Select-Object -First 1
        $customConfig | ThenConfigReturned -WithEnvironmentCount 1 -FromFileNamed 'custom.json'
        $customConfig | ThenEnvironment 'CustomJson' -Exists

        $deprecatedConfig = $script:result | Select-Object -Skip 1 | Select-Object -First 1
        $deprecatedConfig | ThenConfigReturned -WithEnvironmentCount 1 -FromFileNamed 'deprecated.json'
        $deprecatedConfig | ThenEnvironment 'Deprecated' -Exists

        $dir1Config = $script:result | Select-Object -Skip 2 | Select-Object -First 1
        $dir1Config | ThenEnvironment 'InDir1' -Exists
        $dir1Config | ThenConfigReturned -WithEnvironmentCount 1 -FromFileNamed 'dir1\baton.json'

        $dir1Config = $script:result | Select-Object -Last 1
        $dir1Config | ThenConfigReturned -WithEnvironmentCount 1 -FromFileNamed 'dir2\baton.json'
        $dir1Config | ThenEnvironment 'InDir2' -Exists
    }
}
