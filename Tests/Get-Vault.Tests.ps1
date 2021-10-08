
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$testNum = 0

function GivenConfig
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Value
    )

    $script:configPath = Join-Path -Path $script:testDir -ChildPath 'baton.json'
    Set-Content -Path $script:configPath -Value $Value
}

function Init
{
    $Global:Error.Clear()
    $script:testDir = Join-Path -Path $TestDrive.FullName -ChildPath ($script:testNum++)
    New-Item -Path $script:testDir -ItemType 'Directory'
    $script:result = $null
}

function ThenNoError
{
    $Global:Error | Should -BeNullOrEmpty
}

function ThenNothingReturned
{
    [CmdletBinding()]
    param(
    )

    # Want to make sure we don't get an empty array, but actually nothing.
    ,$script:result | Should -Be $null
}

function ThenReturnedVault 
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String[]] $WithKey
    )

    $script:result | Should -HaveCount $WithKey.Count
    [Object[]]$results = $script:result
    for( $idx = 0; $idx -lt $results.Count; ++$idx )
    {
        $results[$idx].Key | Should -Be $WithKey[$idx]
    }
}

function WhenGetting
{
    [CmdletBinding()]
    param(
        [switch] $FromDefaultConfigFile,

        [String] $ForAsymmetricKey,

        [String] $FromEnvironment = 'Verification'
    )

    if( $FromDefaultConfigFile )
    {
        Mock -CommandName 'Import-Configuration' `
             -ModuleName 'Baton' `
             -ParameterFilter { -not $LiteralPath } `
             -MockWith ([scriptblock]::Create("Import-Configuration -LiteralPath '$($script:configPath)'")) `
             -Verifiable
        $script:result = Get-CfgVault -Environment 'Verification'
        Assert-VerifiableMock
        return
    }

    $optionalParams = @{}
    if( $ForAsymmetricKey )
    {
        $optionalParams['Key'] = $ForAsymmetricKey
    }

    $script:result =
        Import-CfgConfiguration -LiteralPath $script:configPath|
        Get-CfgVault -Environment $FromEnvironment @optionalParams 
}

Describe 'Get-Vault.when there are no vaults' {
    It 'should return nothing' {
        Init
        GivenConfig '{ "Environments": [ { "Name": "Verification", "InheritsFrom": "P" }, { "Name": "P" } ] }'
        WhenGetting
        ThenNothingReturned
        ThenNoError
    }
}

Describe 'Get-Vault.when there are only empty vaults' {
    It 'should return nothing' {
        Init
        GivenConfig @'
{
    "Environments": [
        {
            "Name": "Verification",
            "InheritsFrom": "P",
            "Vaults": [] 
        },
        {
            "Name": "P",
            "InheritsFrom": "PP",
            "Vaults": [] 
        },
        {
            "Name": "PP",
            "Vaults": [] 
        }
    ]
}
'@
        WhenGetting
        ThenNothingReturned
        ThenNoError
    }
}

Describe 'Get-Vault.when first environment has only vault' {
    It 'should return just that vault' {
        Init
        GivenConfig @'
{
    "Environments": [
        {
            "Name": "Verification",
            "InheritsFrom": "P",
            "Vaults": [
                {
                    "Key": "Verification"
                }
            ] 
        },
        {
            "Name": "P",
            "InheritsFrom": "PP",
            "Vaults": [] 
        },
        {
            "Name": "PP",
            "Vaults": [] 
        }
    ]
}
'@
        WhenGetting
        ThenNoError
        ThenReturnedVault "Verification"
    }
}

Describe 'Get-Vault.when last environment has only vault' {
    It 'should return just that vault' {
        Init
        GivenConfig @'
{
    "Environments": [
        {
            "Name": "Verification",
            "InheritsFrom": "P",
            "Vaults": [ ]
        },
        {
            "Name": "P",
            "InheritsFrom": "PP",
            "Vaults": []
        },
        {
            "Name": "PP",
            "Vaults": [
                {
                    "Key": "PP"
                }
           ]
        }
    ]
}
'@
        WhenGetting
        ThenNoError
        ThenReturnedVault "PP"
    }
}

Describe 'Get-Vault.when all environments have vaults' {
    It 'should return all the vaults' {
        Init
        GivenConfig @'
{
    "Environments": [
        {
            "Name": "Verification",
            "InheritsFrom": "P",
            "Vaults": [
                {
                    "Key": "Verification"
                }
           ]
        },
        {
            "Name": "P",
            "InheritsFrom": "PP",
            "Vaults": [
                {
                    "Key": "P"
                }
           ]
        },
        {
            "Name": "PP",
            "Vaults": [
                {
                    "Key": "PP"
                }
           ]
        }
    ]
}
'@
        WhenGetting
        ThenNoError
        ThenReturnedVault "Verification", "P", "PP"
    }
}

Describe 'Get-Vault.when there are multiple number of vaults in each environment' {
    It 'should return all the vaults' {
        Init
        GivenConfig @'
{
    "Environments": [
        {
            "Name": "Verification",
            "InheritsFrom": "P",
            "Vaults": [
                {
                    "Key": "Verification1"
                },
                {
                    "Key": "Verification2"
                }
           ]
        },
        {
            "Name": "P",
            "InheritsFrom": "PP",
            "Vaults": []
        },
        {
            "Name": "PP",
            "Vaults": [
                {
                    "Key": "PP"
                }
           ]
        }
    ]
}
'@
        WhenGetting
        ThenNoError
        ThenReturnedVault "Verification1", "Verification2", "PP"
    }
}

Describe 'Get-Vault.when getting vaults from default config' {
    It 'should return vaults from default config file' {
        Init
        GivenConfig @'
{
    "Environments": [
        {
            "Name": "Verification",
            "Vaults": [
                {
                    "Key": "Verification1"
                },
                {
                    "Key": "Verification2"
                }
           ]
        }
    ]
}
'@
        WhenGetting -FromDefaultConfigFile
        ThenNoError
        ThenReturnedVault "Verification1", "Verification2"
    }
}

Describe 'Get-Vault.when getting vault with specific key thumbprint' {
    It 'should return that vault' {
        Init
        GivenConfig @'
{
    "Environments": [
        {
            "Name": "E1",
            "InheritsFrom": "E2",
            "Vaults": [
                { "Key": "V1" },
                { "Key": "V2" }
            ]
        },
        {
            "Name": "E2",
            "Vaults": [
                { "Key": "V1" },
                { "Key": "V2" }
            ]
        }
    ]
}
'@
        WhenGetting -ForAsymmetricKey 'V1' -FromEnvironment 'E1'
        ThenNoError
        ThenReturnedVault 'V1', 'V1'
    }
}