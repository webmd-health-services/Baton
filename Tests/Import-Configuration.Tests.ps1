
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$path = $null
$result = $null

function GivenConfigJson
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String] $Json,

        $InFileNamed
    )

    if( $InFileNamed )
    {
        $script:path = Join-Path -Path ($path | Split-Path) -ChildPath $InFileNamed
    }

    $Json | Set-Content -LiteralPath $path
}

function Init
{
    $Global:Error.Clear()
    $script:path = Join-Path -Path $TestDrive.FullName -ChildPath "$([IO.Path]::GetRandomFileName()).json"
    $script:result = $null
}

function ThenConfigReturned
{
    [CmdletBinding()]
    param(
        [int] $WithEnvironmentCount
    )

    $result | Should -HaveCount 1
    $result | Should -BeOfType ('{}' | ConvertFrom-Json).GetType()
    $result | Get-Member -Name 'Environments' | Should -Not -BeNullOrEmpty
    ,$result.Environments | Should -BeOfType (@()).GetType()
    $result | Get-Member -Name 'Path' | Should -Not -BeNullOrEmpty
    $result.Path | Should -BeOfType [string]
    $result.Path | Should -Be $path

    $result.Environments.Count | Should -Be $WithEnvironmentCount
}

function ThenEnvironment
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [String] $Named,

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
        [String] $WithThumbprint,

        [Parameter(ParameterSetName='Vault')]
        [String] $WithSymmetricKey = '',

        [Parameter(ParameterSetName='Vault')]
        [hashtable] $WithSecrets = @{}
    )

    
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
        $env.Settings | Should -BeOfType [hashtable]
        $env.Settings.Count | Should -Be $WithSettings.Count
        foreach( $name in $WithSettings.Keys )
        {
            $env.Settings[$name] | Should -Be $WithSettings[$name]
        }
    }

    foreach( $vault in $env.Vaults )
    {
        $vault | Should -Not -BeNullOrEmpty
        $vault | Get-Member -Name 'KeyThumbprint' | Should -Not -BeNullOrEmpty
        $vault.KeyThumbprint | Should -BeOfType [String]
        $vault | Get-Member -Name 'Key' | Should -Not -BeNullOrEmpty
        $vault.Key | Should -BeOfType [String]
        $vault | Get-Member -Name 'Secrets' | Should -Not -BeNullOrEmpty
        $vault.Secrets | Should -BeOfType [hashtable]
    }

    if( $HasVault )
    {
        $vault = $env.Vaults | Where-Object 'KeyThumbprint' -EQ $WithThumbprint
        $vault | Should -Not -BeNullOrEmpty
        $vault | Should -BeOfType [pscustomobject]

        $vault | Get-Member -Name 'Key' | Should -Not -BeNullOrEmpty
        $vault.Key | Should -Be $WithSymmetricKey

        $vault | Get-Member -Name 'Secrets' | Should -Not -BeNullOrEmpty
        $vault.Secrets | Should -BeOfType [hashtable]
        $vault.Secrets.Count | Should -Be $WithSecrets.Count
        foreach( $name in $WithSecrets.Keys )
        {
            $vault.Secrets[$name] | Should -Be $WithSecrets[$name]
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
        [String] $Path = $script:path
    )

    $script:result = Import-CfgConfiguration -LiteralPath $Path
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
                    "KeyThumbprint": "minus3",
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
                    "KeyThumbprint": "deadbee",
                    "Key": "symmetrickey",
                    "Secrets": {
                        "five": "six",
                        "seven": "eight"
                    }
                },
                {
                    "KeyThumbprint": "eebdaed",
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
        ThenEnvironment 'Verification' -HasVault -WithThumbprint 'minus3' -WithSecrets @{ 'minus4' = 'minus5' }
        ThenEnvironment 'Two' `
                        -Exists `
                        -InheritsFrom "Verification" `
                        -WithSettings @{ "One" = "Two"; "Three" = "Four" } `
                        -HasVaultCount 2
        ThenEnvironment 'Two' `
                        -HasVault `
                        -WithThumbprint 'deadbee' `
                        -WithSymmetricKey 'symmetrickey' `
                        -WithSecrets @{ 'five' = 'six' ; 'seven' = 'eight' }
        ThenEnvironment 'Two' -HasVault -WithThumbprint 'eebdaed' -WithSecrets @{ 'nine' = 'ten' }
        
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
        ThenFailed -WithErrorMessageMatching 'vault must have a "KeyThumbprint" property'
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
            "KeyThumbprint": "yolo",
            "Key": "symmetrickey",
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
                        -WithThumbprint 'yolo' `
                        -WithSymmetricKey 'symmetrickey' `
                        -WithSecrets @{ 'hello' = 'world' }
    }
}