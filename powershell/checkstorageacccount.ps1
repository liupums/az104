Import-Module -Force -Name ".\Common.psm1"
InitGlobalVariables
LoginAzure
# https://docs.microsoft.com/en-us/azure/network-watcher/
# https://docs.microsoft.com/en-us/azure/network-watcher/diagnose-vm-network-routing-problem-powershell

$rgName = $global:MyResourceGroup
$sourceVMName = "myVM"

$VM1 = Get-AzVM -ResourceGroupName $rgName | Where-Object -Property Name -EQ $sourceVMName
$networkWatcher = Get-AzNetworkWatcher | Where-Object -Property Location -EQ -Value $VM1.Location

$store = Get-AzStorageAccount -ResourceGroupName $rgName -Name $global:MyStorageAcct
$container = Get-AzStorageContainer -Name testcontainer -Context $store.Context
$testuri = $container.CloudBlobContainer.Uri.AbsoluteUri

<#
PS C:\Users\puliu\az104-storage> nslookup az104popstorage.blob.core.windows.net

Server:  UnKnown
Address:  192.168.86.1

Non-authoritative answer:
Name:    blob.by3prdstr08a.store.core.windows.net
Address:  20.150.35.132
Aliases:  az104popstorage.blob.core.windows.net
#>
Write-Host "test outbound to storage"
Test-AzNetworkWatcherConnectivity -NetworkWatcher $networkWatcher -SourceId $VM1.Id `
    -DestinationAddress $testuri -DestinationPort 443

$nic = Get-AzNetworkInterface -name "myNic"
$myprivateip = $nic.IpConfigurations[0].PrivateIpAddress
Write-Host "Test routing to www.google.com"
Get-AzNetworkWatcherNextHop `
  -NetworkWatcher $networkWatcher `
  -TargetVirtualMachineId $VM1.Id `
  -SourceIPAddress $myprivateip `
  -DestinationIPAddress 172.217.6.36