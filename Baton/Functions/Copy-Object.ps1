
function Copy-Object
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object] $SourceObject,

        [Parameter(Mandatory)]
        [Object] $DestinationObject,

        [String[]] $Property
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        if( $SourceObject -is [Collections.IDictionary] )
        {
            if( $DestinationObject -isnot [Collections.IDictionary] )
            {
                $msg = "Copying ""$($SourceObject)"" to ""$($DestinationObject)"" failed: the destination object isn''t " +
                    "a dictionary, but a [$($DestinationObject.GetType().FullName)]. When the source object passed to " +
                    "$($MyInvocation.MyCommand.Name) is a dictionary, the destination object must also be a dictionary."
                Write-Error -Message $msg -ErrorAction $ErrorActionPreference
            }

            $keysToCopy = $SourceObject.Keys | Where-Object {
                if( -not $Property )
                {
                    return $true
                }

                $key = $_
                return $Property | Where-Object { $key -like $_ }
            }

            foreach( $key in $keysToCopy )
            {
                $DestinationObject[$key] = $SourceObject[$key]
            }
            return
        }

        $propertyTypes = [Management.Automation.PSMemberTypes]::Property -bor `
                         [Management.Automation.PSMemberTypes]::NoteProperty -bor `
                         [Management.Automation.PSMemberTypes]::ScriptProperty
        $propertyNames =
            $SourceObject |
            Get-Member -MemberType $propertyTypes |
            Select-Object -ExpandProperty 'Name' |
            Where-Object {
                if( -not $Property )
                {
                    return $true
                }

                $propertyName = $_
                return $Property | Where-Object { $propertyName -like $_ }
            } |
            Sort-Object

        foreach( $propertyName in $propertyNames )
        {
            if( $DestinationObject -is [Collections.IDictionary] )
            {
                $DestinationObject[$propertyName] = $SourceObject.$propertyName
                continue
            }

            if( -not ($DestinationObject | Get-Member -Name $propertyName) )
            {
                $msg = "Copying ""$($SourceObject)"" to ""$($DestinationObject)"" failed: destination " +
                    "[$($DestinationObject.GetType().FullName)] type doesn't have a ""$($propertyName)""" +
                    'property. Copy-Object expects the destination object to have the same properties as the source ' +
                    'object.'
                Write-Error -Message $msg -ErrorAction $ErrorActionPreference
                continue
            }

            $DestinationObject.$propertyName = $SourceObject.$propertyName
        }
    }
}
