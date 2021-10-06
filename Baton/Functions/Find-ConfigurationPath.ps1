
function Find-ConfigurationPath
{
    <#
    .SYNOPSIS
    Private function that finds the default "baton.json" file to use.

    .DESCRIPTION
    The "Find-ConfigurationPath" function finds the default "baton.json" file to use. `Find-ConfigurationPath`
    looks for a "baton.json" file in the current directory and all parent directories. If no file is found,
    `Find-ConfigurationPath` writes an error.

    .EXAMPLE
    Find-ConfigurationPath

    Demonstrates how to call `Find-ConfigurationPath` to find the appropriate "baton.json" file.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param(
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $filename = 'baton.json'

    Write-Debug "[$($MyInvocation.MyCommand.Name)]"

    $startInPath = (Get-Location).Path

    $foundConfig = $false

    $searchPath = $startInPath
    # Split-Path doesn't handle 'nix paths for items in the root, e.g. for '/some_path' it returns nothing [1]. We have
    # to detect this situation so we can do a check in the / directory. Also, Split-Path throws a terminating error if
    # passed '/' [2].
    # [1] https://github.com/PowerShell/PowerShell/issues/4134
    # [2] https://github.com/PowerShell/PowerShell/issues/10092
    $rootDirs = @( [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar )
    do
    {
        $candidatePath = Join-Path -Path $searchPath -ChildPath $filename
        if( (Test-Path -LiteralPath $candidatePath -PathType Leaf) )
        {
            $foundConfig = $true
            Write-Debug "  -> $($candidatePath)"
            Get-Item -LiteralPath $candidatePath | Select-Object -ExpandProperty 'FullName' | Write-Output
            break
        }

        if( $searchPath -in $rootDirs )
        {
            break
        }

        Write-Debug "     $($candidatePath)"
        $searchPath = $searchPath | Split-Path -ErrorAction Ignore
        if( -not $searchPath -and $candidatePath.Substring(0, 1) -in $rootDirs )
        {
            $searchPath = [IO.Path]::DirectorySeparatorChar
        }
    }
    while( $searchPath )

    if( -not $foundConfig )
    {
        $msg = "Configuration file ""$($filename)"" does not exist in the current directory ""$($startInPath)"" or " +
               'any of its parent directories.'
        Write-Error -Message $msg -ErrorAction $ErrorActionPreference
    }

    Write-Debug "[$($MyInvocation.MyCommand.Name)]"
}
