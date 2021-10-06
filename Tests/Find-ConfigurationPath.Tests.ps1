
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-Test.ps1' -Resolve)

$script:mockFs = $null
$script:result = $null
$script:targetConfigPath = $null
$invalidPathCharRegex = "(:|$([regex]::Escape([IO.Path]::DirectorySeparatorChar))|" +
                        "$([regex]::Escape([IO.Path]::AltDirectorySeparatorChar))|" +
                        "$(([IO.Path]::InvalidPathChars | ForEach-Object { [regex]::Escape($_) }) -join '|'))"
Write-Debug "  [Invalid Path Chars Regex]  $($invalidPathCharRegex)"

function GivenFile
{
    [CmdletBinding()]
    param(
        [String] $Path
    )

    New-Item -Path $Path -ItemType 'File'
}

function GivenMockFile
{
    [CmdletBinding()]
    param(
        [String] $Path
    )

    $filename = $Path -replace $invalidPathCharRegex, '_'
    $targetPath = Join-Path -Path $TestDrive.FullName -ChildPath $filename
    Write-Debug "  [Mock]  [FS]  $($Path)  =>  $($targetPath)"
    New-Item -Path $targetPath -ItemType 'File'
    $script:mockFs[$Path] = $targetPath
    $script:targetConfigPath = $targetPath
}

function Init
{
    $Global:Error.Clear()
    $script:result = $null
    $script:targetConfigPath = $null
    $script:mockFs = @{}
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

function ThenFoundFile
{
    [CmdletBinding()]
    param(
        [String] $Path = $script:targetConfigPath
    )

    $script:result | Should -Not -BeNullOrEmpty
    ,$script:result | Should -BeOfType [String]]
    $script:result | Should -Be $Path
}

function ThenNoError
{
    $Global:Error | Should -BeNullOrEmpty
}

function ThenNothingReturned
{
    $result | Should -BeNullOrEmpty
}

function WhenFinding
{
    [CmdletBinding()]
    param(
        [String] $In,

        [String] $Path
    )

    $pathParam = @{}
    if( $In )
    {
        $pathParam['Path'] = $In
    }

    if( $Path )
    {
        $pathParam['Path'] = $Path
    }

    $Global:BCfgFindParam = $pathParam
    $Global:BCfgErrorActionPreference = $ErrorActionPreference
    $Global:BCfgResult = $null
    $Global:BCfgFS = $script:mockFs
    try
    {
        $mockFSFilter = {
            # For some reason, $BCfgFS.ContainsKey always returns $false.
            if( $Global:BCfgFS[$LiteralPath] )
            {
                return $true
            }
            return $false
         }
        Mock -CommandName 'Test-Path' `
             -ModuleName 'Baton' `
             -ParameterFilter $mockFSFilter `
             -MockWith { return $true }

        Mock -CommandName 'Get-Item' `
             -ModuleName 'Baton' `
             -ParameterFilter $mockFSFilter `
             -MockWith { return Get-Item -LiteralPath $Global:BCfgFS[$LiteralPath] }

        $script:result = InModuleScope 'Baton' {
            $ErrorActionPreference = $Global:BCfgErrorActionPreference
            $Global:BCfgResult = Find-ConfigurationPath @Global:BCfgFindParam
        }
    }
    finally
    {
        $script:result = $Global:BCfgResult
        Remove-Variable -Name 'BCfgFS' -Scope 'Global'
        Remove-Variable -Name 'BCfgFindParam' -Scope 'Global'
        Remove-Variable -Name 'BCfgErrorActionPreference' -Scope 'Global'
        Remove-Variable -Name 'BCfgResult' -Scope 'Global'
    }
}

Describe 'Find-ConfigurationPath.when there is no file' {
    It 'should fail' {
        Init
        WhenFinding -ErrorAction SilentlyContinue
        ThenNothingReturned
        ThenFailed 'does not exist in .* or any of its parent directories'
    }
}

Describe 'Find-ConfigurationPath.when there is no file but ignoring the error' {
    It 'should not fail' {
        Init
        WhenFinding -ErrorAction Ignore
        ThenNothingReturned
        ThenNoError
    }
}

Describe 'Find-ConfigurationPath.when a file exists in every directory' {
    It 'should return first file found' {
        Init
        $candidateDir = (Get-Location).Path
        do
        {
            $filePath = Join-Path -Path $candidateDir -ChildPath 'baton.json'
            GivenMockFile $filePath
            $candidateDir = $candidateDir | Split-Path -ErrorAction Ignore
        }
        while( $candidateDir )
        WhenFinding
        ThenFoundFile $script:mockFs[(Join-Path -Path (Get-Location).Path -ChildPath 'baton.json')]
    }
}

Describe 'Find-ConfigurationPath.when file exists in parent directory' {
    It 'should return first file found' {
        Init
        $filePath = Join-Path -Path ((Get-Location).Path | Split-Path) -ChildPath 'baton.json'
        GivenMockFile $filePath
        WhenFinding
        ThenFoundFile
    }
}

Describe 'Find-ConfigurationPath.when file exists in top-most directory' {
    It 'should return first file found' {
        Init
        $root = (Get-Location).Path | Split-Path -Qualifier -ErrorAction Ignore
        if( -not $root )
        {
            $root = '/'
        }
        $filePath = Join-Path -Path $root -ChildPath 'baton.json'
        GivenMockFile $filePath
        WhenFinding
        ThenFoundFile
    }
}