
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$script:result = $null
$script:testDir = $null
$script:exportPath = $null
$script:testNum = 0

function Init
{
    $Global:Error.Clear()
    $script:result = $null
    $script:testDir = Join-Path -Path $TestDrive.FullName -ChildPath (++$script:testNum)
    New-Item -Path $script:testDir -ItemType 'Directory'
    $script:exportPath = Join-Path -Path $script:testDir -ChildPath 'baton.json'
}

Describe 'Export-Configuration' {
    It 'should export configuration object with ordered environments, settings, vaults, and secrets and correct types' {
        Init

        $config = New-CfgConfigurationObject
        foreach( $envName in @('E2', 'E1') )
        {
            $config | Add-CfgEnvironment -Name $envName
            foreach( $vaultKey in @('V2', 'V1') )
            {
                $config | Add-CfgVaultSecret -Environment $envName `
                                                    -Key "$($envName)$($vaultKey)" `
                                                    -Name "$($envName)$($vaultKey)zz" `
                                                    -CipherText "$($envName)$($vaultKey)secret2"
                $config | Add-CfgVaultSecret -Environment $envName `
                                                    -Key "$($envName)$($vaultKey)" `
                                                    -Name "$($envName)$($vaultKey)aa" `
                                                    -CipherText "$($envName)$($vaultKey)secret1"
            }
        }
        $env = $config | Add-CfgEnvironment -Name 'E3' -PassThru | Get-CfgEnvironment -Name 'E3'
        # Make sure InheritsFrom gets expored.
        $env.InheritsFrom = 'E1'
        # Make sure KeyDecryptionKey and an empty vault get exported
        $config | Add-CfgVault -Environment 'E3' -Key 'E3V1' -KeyDecryptionKey 'E3V1K2'
        # Make sure an empty environment gets exported.
        $config | Add-CfgEnvironment -Name 'E4'

        $config | Export-CfgConfiguration -LiteralPath $script:exportPath
        $expectedCfg = [pscustomobject]@{
            Environments = @(
                [pscustomobject]@{
                    Name = 'E1';
                    InheritsFrom = '';
                    Settings = [pscustomobject]@{
                    };
                    Vaults = @(
                        [pscustomobject]@{
                            'Key' = 'E1V1';
                            'KeyDecryptionKey' = '';
                            'Secrets' = [pscustomobject]@{
                                'E1V1aa' = 'E1V1secret1';
                                'E1V1zz' = 'E1V1secret2';
                            }
                        },
                        [pscustomobject]@{
                            'Key' = 'E1V2';
                            'KeyDecryptionKey' = '';
                            'Secrets' = [pscustomobject]@{
                                'E1V2aa' = 'E1V2secret1';
                                'E1V2zz' = 'E1V2secret2';
                            }
                        }
                    )
                },
                [pscustomobject]@{
                    Name = 'E2';
                    InheritsFrom = '';
                    Settings = [pscustomobject]@{
                    };
                    Vaults = @(
                        [pscustomobject]@{
                            'Key' = 'E2V1';
                            'KeyDecryptionKey' = '';
                            'Secrets' = [pscustomobject]@{
                                'E2V1aa' = 'E2V1secret1';
                                'E2V1zz' = 'E2V1secret2';
                            }
                        },
                        [pscustomobject]@{
                            'Key' = 'E2V2';
                            'KeyDecryptionKey' = '';
                            'Secrets' = [pscustomobject]@{
                                'E2V2aa' = 'E2V2secret1';
                                'E2V2zz' = 'E2V2secret2';
                            }
                        }
                    )
                },
                [pscustomobject]@{
                    Name = 'E3';
                    InheritsFrom = 'E1';
                    Settings = [pscustomobject]@{};
                    Vaults = @(
                        [pscustomobject]@{
                            'Key' = 'E3V1';
                            'KeyDecryptionKey' = 'E3V1K2';
                            'Secrets' = [pscustomobject]@{}
                        }
                    );
                }
                [pscustomobject]@{
                    Name = 'E4';
                    InheritsFrom = '';
                    Settings = [pscustomobject]@{};
                    Vaults = @();
                }
            )
        }
        $expectedCfgJson = $expectedCfg | ConvertTo-Json -Depth 100
        Write-Debug $expectedCfgJson
        $actualCfgJson = Get-Content -LiteralPath $script:exportPath -Raw
        $actualCfgJson | Write-Debug
        Compare-Object -ReferenceObject $expectedCfgJson -DifferenceObject $actualCfgJson | Out-String | Write-Debug
        $actualCfgJson | Should -Be $expectedCfgJson
    }
}

Describe 'Export-Configuration.when there are no environments' {
    It 'should export an empty array of environments' {
        Init
        New-CfgConfigurationObject | Export-CfgConfiguration -LiteralPath $script:exportPath
        $expectedCfg = [pscustomobject]@{
            'Environments' = @();
        }
        Get-Content -LiteralPath $script:exportPath -Raw | Should -Be ($expectedCfg | ConvertTo-Json)
    }
}
