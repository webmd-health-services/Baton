
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

function ThenVaultCreated
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $WithKey,

        [String] $WithKeyDecryptionKey = '',

        [Object] $WithSecrets = @{}
    )

    $script:result | ShouldBeOfBatonType 'Vault'

    $script:result | Get-Member -Name 'Key' | Should -Not -BeNullOrEmpty
    $script:result.Key | Should -BeOfType [String]
    $script:result.Key | Should -Be $WithKey

    $script:result | Get-Member -Name 'KeyDecryptionKey' | Should -Not -BeNullOrEmpty
    $script:result.KeyDecryptionKey | Should -BeOfType [String]
    $script:result.KeyDecryptionKey | Should -Be $WithKeyDecryptionKey

    $script:result | Get-Member -Name 'Secrets' | Should -Not -BeNullOrEmpty
    $script:result.Secrets | Should -BeOfType [hashtable]
    $script:result.Secrets.Count | Should -Be $WithSecrets.Count
    foreach( $key in $WithSecrets.Keys )
    {
        $script:result.Secrets[$key] | Should -Be $WithSecrets[$key]
    }
}

function WhenCreatingVault
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $WithKey,

        [String] $WithKeyDecryptionKey,

        [Object] $WithSecrets
    )

    $optionalParams = @{}
    if( $PSBoundParameters.ContainsKey('WithKeyDecryptionKey') )
    {
        $optionalParams['KeyDecryptionKey'] = $WithKeyDecryptionKey
    }
    if( $PSBoundParameters.ContainsKey('WithSecrets') )
    {
        $optionalParams['Secrets'] = $WithSecrets
    }

    $script:result = New-CfgVaultObject -Key $WithKey @optionalParams
}

Describe 'New-VaultObject.when creating empty vault' {
    It 'should only set key property' {
        Init
        WhenCreatingVault -WithKey 'YOLO'
        ThenVaultCreated -WithKey 'YOLO'
    }
}

Describe 'New-VaultObject.when creating vault for symmetric encryption with secrets' {
    It 'should set all properties' {
        Init
        $secrets = @{ 'full' = 'aes'; 'second' = 'third' }
        WhenCreatingVault -WithKey 'full' -WithKeyDecryptionKey 'aes' -WithSecrets $secrets
        ThenVaultCreated -WithKey 'full' -WithKeyDecryptionKey 'aes' -WithSecrets $secrets
    }
}

Describe 'New-VaultObject.when secrets is an object' {
    It 'should convert to hashtable' {
        Init
        $secrets = @{ 'object' = 'ok' ; 'fourth' = 'fifth' }
        WhenCreatingVault -WithKey 'pscustomobject' -WithSecrets ([pscustomobject]$secrets)
        ThenVaultCreated -WithKey 'pscustomobject' -WithSecrets $secrets
    }
}