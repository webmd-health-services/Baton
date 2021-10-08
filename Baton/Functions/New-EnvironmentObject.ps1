
function New-EnvironmentObject
{
    <#
    .SYNOPSIS
    Creates a new Baton environment object.

    .DESCRIPTION
    The `New-EnvironmentObject` function creates a new Baton environment object. Use this function to create configurations
    via automation. Pass the name of the environment to the "Name" parameter. You can also pass the environment's parent
    environment name to the "InheritsFrom" parameter, and a hashtable of settings to the "Settings" parameter.

    Returns an object with these properties:

    * `Name`: the name of the environment.
    * `InheritsFrom`: the name of environment's parent environment.
    * `Settings`: a hashtable of the environment's settings.

    .EXAMPLE
    New-EnvironmentObject -Name 'Verification'

    Demonstrates how to use this function to create a new environment configuration object.

    .EXAMPLE
    New-EnvironmentObject -Name 'Verification' -InheritsFrom 'Dev' -Settings @{ 'one' = 1; 'two' = 2; }

    Demonstrates how to set an environment's "InheritsFrom" and "Settings" properties.
    #>
    [CmdletBinding()]
    param(
        # The name of the environment.
        [Parameter(Mandatory)]
        [String] $Name,

        # The name of the environment's parent environment.
        [String] $InheritsFrom,

        # A hashtable of the environment's settings.
        [Object] $Settings = @{}
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $env = [pscustomobject]@{
        'Name' = $Name;
        'InheritsFrom' = $InheritsFrom;
        'Settings' = @{};
        'Vaults' = [Collections.ArrayList]::New();
    }
    $env.pstypenames.Insert(0, 'Baton.Environment')
    
    if( $Settings )
    {
        $Settings | Copy-Object -DestinationObject $env.Settings
    }

    return $env
}
