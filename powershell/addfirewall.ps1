Import-Module -Force -Name ".\Common.psm1"
InitGlobalVariables
LoginAzure
# https://docs.microsoft.com/en-us/azure/firewall/deploy-ps
<#
$myVnet = "myVNET"
$myVnetAddress = "192.168.0.0/16"
$mySubnet = "mySubnet"
$mySubnetAddress = "192.168.1.0/24"
AzureBastionSubnet 192.168.0.0/27 (192.168.0.0 - 192.168.0.31)
AzureFirewallSubnet 192.168.0.64/26 (192.168.0.64 - 192.168.0.127)
#>

$myNic = "myNic"
$myVnet = "myVNET"
$vnet = Get-AzVirtualNetwork -Name $myVnet -ResourceGroupName $global:MyResourceGroup -ErrorAction Ignore

if (-Not $vnet)
{
    Write-Host "Please create the VNET $myVnet first"
    return
}

$Bastionsub = Get-AzVirtualNetworkSubnetConfig -Name AzureBastionSubnet -VirtualNetwork $vnet  -ErrorAction Ignore
If (-Not $Bastionsub)
{
    Write-Host "Create bastion subnet with reserved name AzureBastionSubnet "
    Add-AzVirtualNetworkSubnetConfig -Name AzureBastionSubnet -VirtualNetwork $vnet -AddressPrefix "192.168.0.0/27"
    $vnet | Set-AzVirtualNetwork
}

Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet | Select-Object Name, AddressPrefix

$BastionPip = "Bastion-pip"
$pip = Get-AzPublicIpAddress -Name $BastionPip -ErrorAction Ignore
if (-Not $pip)
{
    # Create a public IP address and specify a DNS name
    $pip = New-AzPublicIpAddress `
        -ResourceGroupName $global:MyResourceGroup `
        -Location $global:MyLocation `
        -AllocationMethod Static `
        -Sku Standard `
        -IdleTimeoutInMinutes 4 `
        -Name $BastionPip
}

$bastion = "Bastion-01"
$bas = Get-AzBastion -ResourceGroupName $global:MyResourceGroup -Name $bastion -ErrorAction Ignore
if (-Not $bas)
{
    Write-Host "Create bastion"
    $bas= New-AzBastion -ResourceGroupName $global:MyResourceGroup -Name $bastion `
        -PublicIpAddress $pip -VirtualNetwork $vnet
}

# Get-AzEffectiveNetworkSecurityGroup : 
# A network interface must be attached to a running virtual machine to get effective security groups
Get-AzEffectiveNetworkSecurityGroup -ResourceGroupName $global:MyResourceGroup -NetworkInterfaceName $myNic
Get-AzNetworkInterface -ResourceGroupName rgstorage -Name $myNic | Select-Object Id, MacAddress
# MAC address OUI 00-22-48 is assigned to Microsoft


# create az firewall if not created yet
# check subnet
$Fiewwallsub = Get-AzVirtualNetworkSubnetConfig -Name AzureFirewallSubnet -VirtualNetwork $vnet  -ErrorAction Ignore
If (-Not $Fiewwallsub)
{
    Write-Host "Create firewall subnet with reserved name AzureFirewallSubnet 192.168.0.64/26, 59 + 5 address "
    Add-AzVirtualNetworkSubnetConfig -Name AzureFirewallSubnet -VirtualNetwork $vnet -AddressPrefix "192.168.0.64/26"
    Set-AzVirtualNetwork -VirtualNetwork $vnet
}

Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet | Select-Object Name, AddressPrefix

#public ip
$FirewallPip = "fw-pip"
$fwpip = Get-AzPublicIpAddress -Name $FirewallPip -ErrorAction Ignore
if (-Not $fwpip)
{
    # Create a public IP address and specify a DNS name
    $fwpip = New-AzPublicIpAddress `
        -ResourceGroupName $global:MyResourceGroup `
        -Location $global:MyLocation `
        -AllocationMethod Static `
        -Sku Standard `
        -IdleTimeoutInMinutes 4 `
        -Name $FirewallPip
}

$myFirewall = "MyFireWall"
$Azfw = Get-AzFirewall -ResourceGroupName $global:MyResourceGroup -Name $myFirewall -ErrorAction Ignore
if (-Not $Azfw)
{
    $Azfw = New-AzFirewall -Name $myFirewall `
        -ResourceGroupName $global:MyResourceGroup `
        -Location $global:MyLocation `
        -VirtualNetwork $vnet `
        -PublicIpAddress $fwpip
}

$AzfwPrivateIP = $Azfw.IpConfigurations.privateipaddress
Write-host "firewall private ip $AzfwPrivateIP"

# route table
$MyRoutTable = "MyFirewallRouteTable"
$routeTableDG = Get-AzRouteTable -ResourceGroupName $global:MyResourceGroup -Name $MyRoutTable -ErrorAction Ignore
if (-Not $routeTableDG)
{
    $routeTableDG = New-AzRouteTable `
        -Name $MyRoutTable `
        -ResourceGroupName $global:MyResourceGroup `
        -Location $global:MyLocation `
        -DisableBgpRoutePropagation
}

$MyRouteRule = "MyFWRouteRule"
$routerule = Get-AzRouteConfig -RouteTable $routeTableDG -Name $MyRouteRule -ErrorAction Ignore
if (-Not $routerule)
{
    #Create a route
    $routerule = Add-AzRouteConfig `
        -Name $MyRouteRule `
        -RouteTable $routeTableDG `
        -AddressPrefix 0.0.0.0/0 `
        -NextHopType "VirtualAppliance" `
        -NextHopIpAddress $AzfwPrivateIP
    Set-AzRouteTable -RouteTable $routerule
}

#Associate the route table to the subnet
$mySubnet = "mySubnet"
$mySubnetAddress = "192.168.1.0/24"
Set-AzVirtualNetworkSubnetConfig `
  -VirtualNetwork $vnet `
  -Name $mySubnet `
  -AddressPrefix $mySubnetAddress `
  -RouteTable $routeTableDG | Set-AzVirtualNetwork

$NeedUpdateAzFirewall = $false

# in order to allow storage access, create a firewall rule
# https://docs.microsoft.com/en-us/azure/virtual-network/service-tags-overview
# $networkrules = $Azfw.GetNetworkRuleCollectionByName("WorkLoadRules")
$networkrules = $Azfw.NetworkRuleCollections | Where-Object { $_.Name -like "WorkLoadRules" }
if (-Not $networkrules)
{
    $ruleStorage = New-AzFirewallNetworkRule -Name "AllowStorage" -Description "Allow access to Azure Storage)" `
    -SourceAddress "192.168.1.0/24" `
    -DestinationAddress "Storage.westus" -DestinationPort * -Protocol Any
    # NOTE
    # You can also create a service endpoint (Microsoft.Storage) in the workload subnet "192.168.1.0/24"
    # This will add a new route rule
    <#
    PS C:\Users\puliu\az104-storage> Get-AzEffectiveRouteTable -NetworkInterfaceName myNic `
    >>   -ResourceGroupName rgStorage | Format-Table
    Default VirtualNetworkServiceEndpoint
    #>
    $networkrules = New-AzFirewallNetworkRuleCollection -Name "WorkLoadRules" -Priority 100 -Rule $ruleStorage -ActionType Allow
    $Azfw.NetworkRuleCollections.add($networkrules)
    $NeedUpdateAzFirewall = $true
}

$apprules = $Azfw.ApplicationRuleCollections | Where-Object { $_.Name -like "WorkLoadAppRules" }
if (-Not $apprules)
{
    $ruleWww = New-AzFirewallApplicationRule -Name "AllowWww" -Description "Allow VM to access www.google.com)" `
        -SourceAddress 192.168.1.0/24 `
        -Protocol http, https -TargetFqdn www.google.com

    # NOTE
    # You can also create a network rule to allow access to FQDN www.google.com but with extra work to enable DNS for firewall
    #>
    $apprules = New-AzFirewallApplicationRuleCollection -Name "WorkLoadAppRules" -Priority 110 -Rule $ruleWww -ActionType Allow
    $Azfw.ApplicationRuleCollections.add($apprules)
    $NeedUpdateAzFirewall = $true
}

# use nat to allow public www access to the nginx service in the vm
# http://104.45.216.37/ --> firewall public ip
# http://192.168.1.4/ --> VM private ip
# the DNAT rule will transfer the http://104.45.216.37/ to http://192.168.1.4/
$natrules = $Azfw.NatRuleCollections | Where-Object { $_.Name -like "wwwAccess" }
if (-Not $natrules)
{
    $fwpip = Get-AzPublicIpAddress -Name $FirewallPip -ErrorAction Ignore
    if (-Not $fwpip)
    {
        Write-Host "please add public ip to the firewall"
        return
    }
    $address = $fwpip.IpAddress
    $nic = Get-AzNetworkInterface -name $myNic -ErrorAction Ignore
    $vmip = $nic.IpConfigurations.PrivateIpAddress
    $fwnatrule1 = New-AzFirewallNatRule -Name "DNAT1" -Protocol "TCP" `
        -SourceAddress "*" `
        -DestinationAddress $address -DestinationPort "80" `
        -TranslatedAddress $vmip -TranslatedPort "80"
    $fwnatrulecollection1 = New-AzFirewallNatRuleCollection -Name wwwAccess -Priority 200 -Rule $fwnatrule1
    $Azfw.NatRuleCollections = $fwnatrulecollection1    
    $NeedUpdateAzFirewall = $true
}

if ($NeedUpdateAzFirewall)
{
    Set-AzFirewall -AzureFirewall $Azfw
}

