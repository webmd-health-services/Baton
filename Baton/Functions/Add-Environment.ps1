
function Add-Environment
{
    <#
    .SYNOPSIS
    Adds a new environment to a Baton configuraiton object.

    .DESCRIPTION
    The `Add-CfgEnvironment` function adds a new environment to a Baton configuration object. Pipe the configuration 
    object to the function, or pass it to the `Configuration` parameter. Pass the name of the new environment to the
    `Name` parameter. The environment is added to the configuration's `Environments` property.

    Use the `-PassThru` switch to return the configuration object piped to `Add-CfgEnvironment` or passed to the
    `Configuration` parameter.

    .EXAMPLE
    $config | Add-CfgEnvironment -Name 'Verification'

    Demonstrates how to add an environment by piping a Baton configuration object to `Add-CfgEnvironment`

    .EXAMPLE
    Add-CfgEnvironment -Configuration $config -Name 'Verification'

    Demonstrates how to add an environment to a Baton configuration object by passing it to the `Configuration`
    parameter.

    .EXAMPLE
    $newEnv = $config | Add-CfgEnvironment -Name 'Verification' -PassThru

    Demonstrates how to return the new environment object by using the `-PassThru` switch.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Name,

        [Parameter(Mandatory, ValueFromPipeline)]
        [Object] $Configuration,

        [switch] $PassThru
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        if( ($Configuration | Get-Environment -Name $Name -ErrorAction Ignore) )
        {
            $msg = "Failed to add environment ""$($Name)"": that environment already exists."
            Write-Error -Message $msg -Configuration $Configuration
            return
        }

        $env = New-EnvironmentObject -Name $Name
        [void]$Configuration.Environments.Add($env)
        
        if( $PassThru )
        {
            return $Configuration
        }
    }
}
