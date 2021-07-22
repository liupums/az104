
Import-Module -Force -Name ".\Common.psm1"
InitGlobalVariables
LoginAzure

$resourceGroup=$global:MyResourceGroup
$location=$global:MyLocation
$storageAcct=$global:MyStorageAcct

$rg = Get-AzResourceGroup -Name $resourceGroup -ErrorAction Ignore
if (-Not $rg)
{
    Write-Debug "Create new Resource Group $resourceGroup"
    New-AzResourceGroup -Name $resourceGroup -Location $location
}

$store = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAcct -ErrorAction Ignore
if (-Not $store)
{
    Write-Debug "Create new Storage account $storageAcc in Resource group  $resourceGroup"
    $store = New-AzStorageAccount -ResourceGroupName $resourceGroup `
        -Name $storageAcct `
        -Location $location `
        -SkuName Standard_RAGRS `
        -Kind StorageV2
}

Write-Host "storage account $($store.StorageAccountName) in $($store.ResourceGroupName)"
$myContainer = "testcontainer"
# create a container 
# https://docs.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-powershell

# Retrieve the Context from the Storage Account
$storageContext = $store.Context

$container = Get-AzStorageContainer -Name $myContainer -Context $storageContext -ErrorAction Ignore
if (-Not $container)
{
    $container = New-AzStorageContainer -Name $myContainer -Context $storageContext -Permission Off
}

$myBolb = "newblob.txt"
$blob = Get-AzStorageBlob -Container $myContainer -Context $storageContext -Blob $myBolb -ErrorAction Ignore

if (-Not $blob)
{
    # upload a file to the Hot access tier
    Set-AzStorageBlobContent -File "common.psm1" `
    -Container $myContainer `
    -Blob $myBolb `
    -Context $storageContext `
    -StandardBlobTier Hot
}

Write-Host "list blob in the container $myContainer"
Get-AzStorageBlob -Container $myContainer -Context $storageContext | Select-Object Name

LogoutAzure