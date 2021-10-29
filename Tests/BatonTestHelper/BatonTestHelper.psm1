
function Invoke-ModulePrivateCommand
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $ModuleName,

        [Parameter(Mandatory)]
        [String] $Name,

        [hashtable] $Parameter = @{}
    )

    $Global:MpcName = $Name
    $Global:MpcParameter = $Parameter

    if( $VerbosePreference -eq 'Continue' )
    {
        $Parameter['Verbose'] = $true
    }

    $Parameter['ErrorAction'] = $ErrorActionPreference

    try
    {
        InModuleScope $ModuleName {
            & $MpcName @MpcParameter
        }
    }
    finally
    {
        Remove-Variable -Name 'MpcParameter' -Scope 'Global'
        Remove-Variable -Name 'MpcName' -Scope 'Global'
    }
}

function ShouldBeOfBatonType {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object] $InputObject,

        [Parameter(Mandatory, Position=0)]
        [String] $Named
    )
    
    process
    {
        $InputObject | Should -Not -BeNullOrEmpty
        $InputObject | Should -BeOfType [pscustomobject]
        $InputObject.pstypenames[0] | Should -Be "Baton.$($Named)"
    }
}

function ThenFailed
{
    [CmdletBinding()]
    param(
        [String] $WithErrorMatching,

        [int] $AtIndex = 0
    )

    $Global:Error | Should -Not -BeNullOrEmpty

    if( $WithErrorMatching )
    {
        $Global:Error | Select-Object -Index $AtIndex | Should -Match $WithErrorMatching
    }
}

function ThenNoError
{
    $Global:Error | Should -BeNullOrEmpty
}