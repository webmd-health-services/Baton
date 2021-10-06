
function Get-Setting
{
    <#
    .SYNOPSIS
    Gets a setting for an environment from configuration.

    .DESCRIPTION
    The `Get-CfgSetting` function returns the value of a setting in a Baton configuration. By default, `Get-CfgSetting`
    imports configuration from the first "baton.json" file found, starting in the current directory followed by each
    of its parent directories. If the setting isn't found, `Get-CfgSetting` writes an error and nothing is returned.

    Pass the name of the setting to the "Name" parameter and the current environment name to the "Environment"
    parameter. All setting names and environment names are case-insensitive.
    
    Since the configuration file is JSON, `Get-CfgSetting` returns whatever PowerShell's `ConvertFrom-Json` cmdlet
    converts the setting's value to, which can be:

    * a string
    * an integer
    * a decimal
    * $true
    * $false
    * $null
    * a `DateTime` (`ConvertFrom-Json` and `ConvertTo-Json` add date/time values to JSON, which are stored as specially
      formatted strings)
    * an object (see below)
    * an array containing zero or more of the values above

    `Get-CfgSetting` returns a generic object (i.e. `[pscustomobject]`) if the value of a setting is a JSON object. For
    example, if you had this "baton.json":

        {
            "Environments": {
                "Name": "Verification",
                "Settings": {
                    "MyObject": {
                        "PropertyOne": "Value1",
                        "PropertyTwo": "PropertyTwo"
                    }
                }
            }
        }

    Calling `Get-CfgSetting'MyObject' -Environment 'Verification'` would return a `[pscustomobject]` with "PropertyOne"
    and "PropertyTwo" properties:

        > Get-CfgSetting'MyObject' -Environment 'Verification'

        PropertyOne PropertyTwo
        ----------- -----------
        Value1      PropertyTwo

    When looking for a setting, `Get-CfgSetting` looks in the "Settings" hashtable for the environment given by the
    `Environment` parameter. If that environment doesn't have the setting, `Get-CfgSetting` looks in the environment's
    parent environment. (An environment sets its `InheritsFrom` property to the name of its parent environment.)

    If you want to return all the values in the initial environment *and* all its parent environments, use the `-Force`
    switch. By default, `Get-CfgSetting` stops searching when it finds and returns a value.

    To get a setting from a custom configuration file, use the `Import-CfgConfiguration` function to import
    configuration from that file and pipe the `Import-CfgConfiguration` function's output to `Get-CfgSetting`.

    .EXAMPLE
    Get-CfgSetting-Name 'Example' -Environment 'Verification'

    Demonstrates how to get a setting. In this example, the first value of the "Example" setting in the Verification
    or one of its parent environments will be returned.

    .EXAMPLE
    Import-CfgConfiguration 'C:\pipeline-example.json' | Get-CfgSetting-Name 'PipelineExample' -Environment 'Verification'

    Demonstrates how to get a setting from a custom configuration file. In this example, the configuration in the 
    "C:\pipeline-example.json" file is used to return the first value of the "PipelineExample" setting in the
    "Verification" environment or one of its parent environments.
    
    .EXAMPLE
    Get-CfgSetting-Name 'ForcedExample' -Environment 'Verification' -Force

    Demonstrates how to use the `-Force` switch to get a setting value from an environment *and* all its parent
    environments, if any. (The defalt is to only return the first value from an environment and each of its parents.)
    If an environment doesn't have a value, nothing is returned for that environment.
    #>
    [CmdletBinding()]
    param(
        # The name of the setting to return.
        [Parameter(Mandatory, Position=0)]
        [String] $Name,

        # The environment from which the setting should be returned.
        [Parameter(Mandatory, Position=1)]
        [String] $Environment,

        # The configuration to use. The default is to use the configuration in the first "baton.json" file found,
        # starting in the current directory followed by each of its parent directories. Use `Import-CfgConfiguration`
        # to import configurations.
        [Parameter(ValueFromPipeline)]
        [Object] $Configuration,

        # By default, `Get-CfgSetting` returns just the *first* setting value found in the environment or that
        # environment's parent environments. Use the `-Force` switch to return *all* setting values in the environment
        # and its parent environments.
        [switch] $Force
    )

    begin
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        Write-Debug "[$($MyInvocation.MyCommand.Name)]"

        $selectParams = @{ 'First' = 1 }
        if( $Force )
        {
            $selectParams.Clear()
        }
    }

    process
    {
        if( -not $Configuration )
        {
            $Configuration = Import-Configuration
            if( -not $Configuration )
            {
                return
            }
        }

        Write-Debug "  $($Configuration.Path | Resolve-Path -Relative)"
        $foundSetting = $false
        $parentEnvs = [Collections.ArrayList]::New()
        $Configuration |
            Get-Environment -Name $Environment |
            ForEach-Object { [void]$parentEnvs.Add($_.Name) ; $_ | Write-Output } |
            Where-Object {
                $envHasSetting = $_.Settings.ContainsKey($Name)
                $flag = '  '
                if( $envHasSetting )
                {
                    $foundSetting = $true
                    $flag = '->'
                }
                Write-Debug "    $flag $($_.Name)[$($Name)]"
                return $envHasSetting
            } |
            Select-Object @selectParams |
            ForEach-Object { return $_.Settings[$Name] } |
            Write-Output

        if( -not $foundSetting )
        {
            # The first environment isn't a parent environment.
            $parentNames = $parentEnvs | Select-Object -Skip 1
            $parentMsg = ''
            if( $parentNames )
            {
                #              or any of its parent environments: 2 -> 3
                $parentMsg = " or any of its parent environments: $($parentNames -join ' -> ')"
            }
            $msg = "$($Configuration.Path | Resolve-Path -Relative): Setting ""$($Name)"" not found in " +
                    """$($Environment)"" environment$($parentMsg)."
            Write-Error -Message $msg -ErrorAction $ErrorActionPreference
        }
    }

    end
    {
        Write-Debug "[$($MyInvocation.MyCommand.Name)]"
    }
}
