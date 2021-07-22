Import-Module -Force -Name ".\Common.psm1"
InitGlobalVariables
LoginAzure
$myVm = "myVM"
$vm = Get-AzVM -ResourceGroupName $global:MyResourceGroup -Name $myVM
if ($vm.Identity.Type -like "SystemAssigned")
{
    $store = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAcct
    $spID = $vm.Identity.principalid
    $scopeId = StorageContainerResourceId -StoreAcctId $store.Id -Name "testcontainer"
    $roles = Get-AzRoleAssignment -ObjectId $spID -Scope $scopeId  | Select-Object RoleDefinitionName
    if ($roles.RoleDefinitionName.Contains("Reader") -and $roles.RoleDefinitionName.Contains("Storage Blob Data Reader"))
    {
        Write-Host "READ roles alread assigned to $scopeId"
        $roles.RoleDefinitionName
    }
    else {
        # Get-AzRoleDefinition | FT Name, Description
        New-AzRoleAssignment -ObjectId $spID -RoleDefinitionName "Reader" -Scope $scopeId
        New-AzRoleAssignment -ObjectId $spID -RoleDefinitionName "Storage Blob Data Reader" -Scope $scopeId        
    }

    if ($roles.RoleDefinitionName.Contains("Storage Blob Data Contributor"))
    {
        Write-Host "WRITE roles alread assigned to $scopeId"
        $roles.RoleDefinitionName
    }
    else {
        # Get-AzRoleDefinition | FT Name, Description
        New-AzRoleAssignment -ObjectId $spID -RoleDefinitionName "Storage Blob Data Contributor" -Scope $scopeId      
    }
}
else
{
    Update-AzVM -ResourceGroupName $global:MyResourceGroup -VM $vm -IdentityType SystemAssigned
}



#see
#https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/qs-configure-powershell-windows-vm
#
#PS C:\Users\puliu\az104-storage> $vm.Identity
#PrincipalId                          TenantId                                       Type UserAssignedIdentities
#-----------                          --------                                       ---- ----------------------
#a744a433-abfe-4059-af1b-04293c07e110 72f988bf-86f1-41af-91ab-2d7cd011db47 SystemAssigned