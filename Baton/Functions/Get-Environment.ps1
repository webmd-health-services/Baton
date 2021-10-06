
function Get-Environment
{
    <#
    .SYNOPSIS
    Gets an environment from a baton.json file.

    .DESCRIPTION
    The `Get-CfgEnvironment` function gets an environment *and* all its parent environments from a "baton.json"
    file. By default, `Get-CfgEnvironment` imports and returns environments from the first "baton.json" file found,
    starting in the current directory followed by each of its parent directories. To get an enviornment from a custom
    configuration file, call the `Import-batonuration` function and pipe that function's output to
    `Get-CfgEnvironment`.

    Pass the name of the environment to the "Environment" parameter. `Get-CfgEnvironment` will return objects for that
    environment, and each of its parent environments. Environment names are case-insensitive.

    An environment can inherit from another environment by setting its "InheritsFrom" property set to the name of the
    parent environment. `Get-CfgEnvironment` returns each environment in inheritance order. For example, with this
    "baton.json" file:

        {
            "Environments": [
                {
                    "Name": "Child",
                    "InheritsFrom": "Parent"
                },
                {
                    "Name": "Parent",
                    "InheritsFrom": "GrandParent"
                },
                {
                    "Name": "GrandParent"
                }
            ]
        }

    `Get-CfgEnvironment 'Child'` call would return environment "Child" followed by environment "Parent" followed by
    environment "GrandParent". Calling `Get-CfgEnvironment 'Parent'` would return the "Parent" and "GrandParent"
    environments and calling `Get-CfgEnvironment 'GrandParent'` would return just the "GrandParent" environment.

    .EXAMPLE
    Get-CfgEnvironment 'Verification'

    Demonstrates how to call `Get-CfgEnvironment` to get an environment. In this example, the 'Verification' environment
    is returned first, followed by its parent environment and the parent environment's parent environment until an
    environment with no parent is reached.

    .EXAMPLE
    Import-batonuration -LiteralPath 'C:\Start\Here' | Get-CfgEnvironment 'Verification'

    Demonstrates how to customize the configuration `Get-CfgEnvironment` uses by using `Import-batonuration` to
    import a custom configuration file and piping that configuration to `Get-CfgEnvironment`.
    #>
    [CmdletBinding()]
    param(
        # The name of the environment to get. The environment's parent environments are returned, too.
        [Parameter(Mandatory)]
        [String] $Name,

        [Parameter(Mandatory)]
        [String] $Path
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        $pathArg = @{}
        if( $Path )
        {
            $pathArg['Path'] = $Path
        }

        $config = Find-ConfigurationFile @pathArg | Import-Configuration
        if( -not $config )
        {
            return
        }

        $configRelPath = $config.Path | Resolve-Path -Relative
        $envs = $config.Environments
        $envName = $Name
        $childEnvName = ''
        $inheritanceChain = [Collections.ArrayList]::New()
        do
        {
            if( $envName -in $inheritanceChain )
            {
                $msg = "$($configRelPath): Circular environment inheritance detected: $($inheritanceChain -join ' -> ') -> " +
                    "$($envName)."
                Write-Error -Message $msg -ErrorAction $ErrorActionPreference
                break
            }

            $env = $envs | Where-Object 'Name' -EQ $envName
            if( -not $env )
            {
                $inheritsMsg = ''
                if( $childEnvName )
                {
                    $inheritsMsg = ", inherited by environment ""$($childEnvName)"","
                }
                $msg = "$($configRelPath): Environment ""$($envName)""$($inheritsMsg) does not exist."
                Write-Error -Message $msg -ErrorAction $ErrorActionPreference
                return
            }
            $env | Write-Output
            [void]$inheritanceChain.Add($envName)
            $childEnvName = $envName
            $envName = $env.InheritsFrom
        }
        while( $envName )
    }
}