
function Find-ConfigurationFile
{
    <#
    .SYNOPSIS
    Finds the "baton.json" file to use.

    .DESCRIPTION
    The "Find-ConfigurationFile" function finds the "baton.json" file to use. The Baton module is designed to be placed
    in and imported from your code's repository, so `Find-ConfigurationFile` looks for a "baton.json" file in the
    currently imported Baton module's parent directory and continues to look in parent  directories until it finds a
    "baton.json" file or it reaches the root directory. If no file is found, `Find-ConfigurationFile` writes an error.

    To start looking for a "baton.json" file in a different directory, pass the path to that directory to the `-Path`
    parameter.

    To load a specific "baton.json" file, pass the path to that file to the `-Path` parameter.

    .EXAMPLE
    Find-ConfigurationFile

    Demonstrates the typical way to call `Find-ConfigurationFile` to find the appropriate "baton.json" file.

    .EXAMPLE
    Find-ConfigurationFile -Path 'C:\Start\In\This\Directory'

    Demonstrates how to find a "baton.json" file by starting in a specific directory.

    .EXAMPLE
    Find-ConfigurationFile -Path 'C:\Use\this\baton.json'

    Demonstrates how to get a specific "baton.json" file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [String] $Path = ($moduleRoot | Split-Path)
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $filename = 'baton.json'

    $msgPrefix = "[$($MyInvocation.MyCommand.Name)]  "

    $fullPaths = Resolve-Path -Path $Path -ErrorAction Ignore | Select-Object -ExpandProperty 'ProviderPath'
    if( -not $fullPaths )
    {
        $msg = "Path ""$($Path)"" does not exist."
        Write-Error -Message $msg -ErrorAction $ErrorActionPreference
        return
    }

    foreach( $fullPath in $fullPaths )
    {
        if( (Test-Path -LiteralPath $fullPath -PathType Leaf) )
        {
            Write-Debug "$($msgPrefix)+ $($fullPath)"
            Get-Item -LiteralPath $fullPath | Write-Output
            continue
        }

        $foundConfig = $false

        $searchPath = $fullPath
        do
        {
            $candidatePath = Join-Path -Path $searchPath -ChildPath $filename
            if( (Test-Path -LiteralPath $candidatePath -PathType Leaf) )
            {
                $foundConfig = $true
                Write-Debug "$($msgPrefix)+ $($candidatePath)"
                Get-Item -LiteralPath $candidatePath | Write-Output
                break
            }

            Write-Debug "$($msgPrefix)  $($candidatePath)"
            $searchPath = $searchPath | Split-Path
        }
        while( $searchPath )

        if( -not $foundConfig )
        {
            $fullPathRelative = Resolve-Path -LiteralPath $fullPath -Relative
            $pathMsg = """$($fullPathRelative)"""
            if( $fullPathRelative -eq (Resolve-Path -LiteralPath ($moduleRoot | Split-Path) -Relative) )
            {
                $pathMsg = 'the current directory'
            }
            $msg = "Configuration file ""$($filename)"" does not exist in $($pathMsg) or any of its parent directories."
            Write-Error -Message $msg -ErrorAction $ErrorActionPreference
        }
    }
}
