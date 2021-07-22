<#
.SYNOPSIS
    Common azure scripting functions.     
.DESCRIPTION

.EXAMPLE
    Import into a script as follows.
    Import-Module -Force -Name [BaseName\]Common.psm1
#>

Function ParseIniFile {
    <#
    .SYNOPSIS
        Parse the provided *.ini file if the file is valid.

    .DESCRIPTION
        Parse an *.ini file and return the parsed content in a dictionary. 
        Input file must be an ini file. 

    .PARAMETER $FilePath
        Input file to be parsed

    .NOTES
        An Ini file may have a list of sections: [section_name] 
        and in each section, there is a list of key/value pair: key=value    
    #>
    param (
        [Parameter(Mandatory)] [string] $FilePath
    )

    $ini = [ordered]@{}
    Switch -regex -file $FilePath {
        "^\[(.+)\]" {
            # Section
            $section = $matches[1]
            $ini[$section] = [ordered]@{}
        }
        "^\s*([^#;].+)\s*=\s*(.*)" {
            # Key=Value, '\s' aka whitespace is not included in key or value
            $name, $value = $matches[1..2]
            $ini[$section][$name] = $value
        }
    }

    Return $ini
}

Function GenerateIniFile {
    <#
    .SYNOPSIS
        Generate the content of *.ini file for a given dictionary.

    .DESCRIPTION
        Based on the dictionary, generate the content of an *.ini file. 
        Input file must be an ini file. 

    .PARAMETER $Ini
        Input ordered dictionary  

    .NOTES
        The dictionary is mapped to an Ini file which may have a list of sections: [section_name] 
        and in each section, there is a list of key/value pair: key=value    
    #>
    param (
        [Parameter(Mandatory)] $Ini
    )

    [System.Collections.ArrayList]$content = @()
    $Ini.GetEnumerator() | ForEach-Object {
        $section = $_.key
        [void]$content.Add("[$section]")
        $s = $_.value
        $s.GetEnumerator() | ForEach-Object {
            $line = '{0}={1}' -f $_.key, $_.value
            [void]$content.Add($line)
        }
    }

    $contentStr = $content -join "`n"
    return $contentStr
}

Function InitGlobalVariables
{
    <#
    .SYNOPSIS
        Set global variables.

    .DESCRIPTION
        Set tenant id, subscription id etc

    .PARAMETER $ConfigIniFile
        config.ini contains the global section to override default global variables.
    #>
    param (
        [parameter(Mandatory=$false)][string] $ConfigIniFile = "config.ini"
    )

    $global:MyAccount = "puliu@microsoft.com"
    $global:MySubscription = "uswestcsu_internal"
    $global:MySubscriptionGuid = "ce2c696e-9825-44f7-9a68-f34d153e64ba"
    $global:MyTenent = "72f988bf-86f1-41af-91ab-2d7cd011db47"
    $global:MyResourceGroup = "rgstorage"
    $global:MyLocation="westus"
    #Get-AzLocation | select Location
    $global:MyStorageAcct="az104popstorage"

    #try to read the value from config.ini
    if (Test-Path $ConfigIniFile -PathType Leaf) {
        Write-Host "Read global variables from $ConfigIniFile"
        $ini = ParseIniFile $ConfigIniFile
        if ($ini["global"]) {
            if ($ini["global"]["MyAccount"]) {
                $global:MyAccount = $ini["global"]["MyAccount"]
            }
            if ($ini["global"]["MySubscription"]) {
                $global:MySubscription = $ini["global"]["MySubscription"]
            }
            if ($ini["global"]["MySubscriptionGuid"]) {
                $global:MySubscriptionGuid = $ini["global"]["MySubscriptionGuid"]
            }
            if ($ini["global"]["MyTenent"]) {
                $global:MyTenent = $ini["global"]["MyTenent"]
            }
            if ($ini["global"]["MyResourceGroup"]) {
                $global:MyResourceGroup = $ini["global"]["MyResourceGroup"]
            }
            if ($ini["global"]["MyLocation"]) {
                $global:MyLocation = $ini["global"]["MyLocation"]
            }
            if ($ini["global"]["MyStorageAcct"]) {
                $global:MyStorageAcct = $ini["global"]["MyStorageAcct"]
            }
        }
    }

    Write-Host "Global variables"
    Write-Host "  Accout            :  $global:MyAccount"
    Write-Host "  Subscription      :  $global:MySubscription"
    Write-Host "  Subscription Id   :  $global:MySubscriptionGuid"
    Write-Host "  Tenant            :  $global:MyTenent"
    Write-Host "  Resource Group    :  $global:MyResourceGroup"
    Write-Host "  Location          :  $global:MyLocation"
    Write-Host "  Storage Account   :  $global:MyStorageAcct"
}


Function LoginAzure
{
    <#
    .SYNOPSIS
        Login Azure.

    .DESCRIPTION
        If not Logged in, log in and set the default subscription. Otherwise, no op.
    #>

    $currentAccount = (Get-AzContext).Account.Id
    if (-Not ($currentAccount -like $global:MyAccount))
    {
        Connect-AzAccount -Tenant $global:MyTenent -Subscription $global:MySubscription
    }
    
    $currentSubscription = (Get-AzContext).SubscriptionName
    if (-Not ($currentSubscription -like $global:MySubscription))
    {
        Set-AzContext -Subscription $global:MySubscriptionGuid
    }
}

Function StorageContainerResourceId
{
    <#
    .SYNOPSIS
        Get the resource Id for storage container.

    .DESCRIPTION
        Concat the content for a given storage object

    .PARAMETER $StoreAcctId
        Storage account ID
    .PARAMETER $Name
        Storage object name.
    #>
    param (
        [parameter(Mandatory)][string] $StoreAcctId,
        [parameter(Mandatory)][string] $Name
    )
# https://docs.microsoft.com/en-us/azure/storage/common/storage-auth-aad-rbac-cli
    return $StoreAcctId + "/blobServices/default/containers/" + $Name
}

Function LogoutAzure
{
    <#
    .SYNOPSIS
        Logout Azure.

    .DESCRIPTION
        Logout
    #>

    Disconnect-AzAccount 
}


Export-ModuleMember -Function *

<#
PS C:\Users\puliu\az104-storage> az ad sp create-for-rbac
In a future release, this command will NOT create a 'Contributor' role assignment by default. If needed, use the --role argument to explicitly create a role assignment.
Creating 'Contributor' role assignment under scope '/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba'
The output includes credentials that you must protect. Be sure that you do not include these credentials in your code or check the credentials into your source control. For more information, see https://aka.ms/azadsp-cli
{
  "appId": "9c54b9d3-9856-4533-b036-7f974b489ac5",
  "displayName": "azure-cli-2021-05-29-03-20-43",
  "name": "http://azure-cli-2021-05-29-03-20-43",
  "password": "ruVFW1psaPfaocg.V.CJvh1rurr5JWBCt_",
  "tenant": "72f988bf-86f1-41af-91ab-2d7cd011db47"
}
#>
