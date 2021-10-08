
function Add-Setting
{
    <#
    .SYNOPSIS
    Adds a setting to an environment.

    .DESCRIPTION
    The `Add-CfgSetting` function adds a setting to an environment in a Baton configuration object. Pipe the
    configuration to the function, or pass it to the `Configuration` object. Pass the setting's environment to the
    `Environment` parameter, the setting's name to the `Name` parameter, the setting's value to the `Value` parameter.
    If a setting with that name already exists in that environment, an error is written on no change is made. Otherwise,
    the setting is added to the environment.

    To overwrite any existing setting, use the `-Overwrite` switch.

    Use the `-PassThru` switch to return the configuration object that was piped to `Add-CfgSetting` or passed to its
    `Configuration` parameter.

    .EXAMPLE
    $config | Add-CfgSetting -Environment 'Verification' -Name 'setting' -Value 'value'

    Demonstrates how to add a setting to an environment by piping a Baton configuration object to `Add-CfgSetting`.

    .EXAMPLE
    Add-CfgSetting -Configuration $Configuration -Environment 'Verification' -Name 'setting' -Value 'value'
    
    Demonstrates how to add a setting to an environment by passing a Baton configuration object to the `Configuration`
    parameter

    .EXAMPLE
    $config | Add-CfgSetting -Environment 'Verification' -Name 'existingsetting' -Value 'value' -Overwrite

    Demonstrates how to overwrite an existing setting in an environment by using the `-Overwrite` switch.

    .EXAMPLE
    $config | Add-CfgSetting -Environment 'Verification' -Name 'existingsetting' -Value 'value' -PassThru

    Demonstrates how to use the `-PassThru` switch to return the Baton configuration object being updated.
    #>
    [CmdletBinding()]
    param(
        # The setting's environment.
        [Parameter(Mandatory)]
        [String] $Environment,

        # The settting's name.
        [Parameter(Mandatory)]
        [String] $Name,

        # The setting's value.
        [Parameter(Mandatory)]
        [String] $Value,

        # The Baton configuration object to use. May be piped to the function or passed to this parameter.
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object] $Configuration,

        # If set, overwrites any existing setting. The default is to write an error if the setting already exists.
        [switch] $Overwrite,

        # If set, returns the Baton configuration object passed to the `Configuration` parameter or piped to the
        # function.
        [switch] $PassThru
    )
    
    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        $env = $Configuration | Get-Environment -Name $Environment -ErrorAction Ignore
        if( -not $env )
        {
            $env = $Configuration | Add-Environment -Name $Environment -PassThru | Get-Environment -Name $Environment
        }

        if( -not $Overwrite -and $env.Settings.ContainsKey($Name) )
        {
            $msg = "environment ""$($Environment)"": setting ""$($Name)"" already exists. Use the -Overwrite " +
                   'parameter to overwrite the existing value.'
            Write-Error -Message $msg -Configuration $Configuration
            return
        }

        $env.Settings[$Name] = $Value

        if( $PassThru )
        {
            return $Configuration
        }
    }
}