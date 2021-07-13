/*
 Summary: Provisions a Azure DevOps build agent using a VMSS. See sub-modules for further detail.
*/

// Subscription deployemnt of RG, then contained resources as modules
targetScope = 'subscription'


// ============================================================================
// Parameters

@description('Admin username for VMs')
param adminUserName string = 'azureuser'

@description('Administrative SSH key for the VM')
param adminSshPubKey string

@description('Cloud Init file encoded as base64')
param cloudInit string

@description('Name of Key Vault')
param keyVaultName string = 'buildAgentVmssKeyVault'

@description('Location to deploy resources, defaults to deployment location')
param location string = deployment().location

@description('Resource group name')
param resourceGroupName string = 'buildAgentVmssRg'

@description('Storage account name')
param storageAccountName string = 'buildagentvmssstorage'

@description('Storage account SKU, defaults to Standard_LRS, Standard_ZRS is not available everywhere')
param storageAccountSku string = 'Standard_LRS'

@description('VM SKU to use for VM scale set')
param vmSku string = 'Standard_B2ms'

// ============================================================================
// Resources

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

var vNetBuildAgentDefinitions = {
  name: 'buildagentVnet'
  location: location
  addressSpacePrefix: '192.168.128.0/24' // 192.168.128.0 - 192.168.128.255
  subnets: [
    {
      name: 'worker'    
      subnetPrefix: '192.168.128.0/25' // // 192.168.128.0 - 192.168.128.127
    }
    {
      name: 'AzureBastionSubnet' // name is fixed as AzureBastionSubnet
      subnetPrefix: '192.168.128.128/27' // 192.168.128.128 - 192.168.128.159
    }
  ]
}

module vnet 'buildagent.vnet.bicep' = {
  name: 'vnetDeploy'
  scope: rg
  params: {
    vNetBuildAgentDefinitions: vNetBuildAgentDefinitions
  }
}

module vmss './buildagent.vmss.bicep' = {
  name: 'vmssDeploy'
  scope: rg
  params: {
    adminSshPubKey: adminSshPubKey
    adminUserName: adminUserName
    cloudInit: cloudInit
    vmSku: vmSku
    subnetResourceId: vnet.outputs.subnetResourceId[0].id // subnet 'worker' with index 0 is for vmss
  }
}

module stg './buildagent.stg.bicep' = {
  name: 'stgDeploy'
  scope: rg
  params: {
    storageAccountName: storageAccountName
    storageAccountSku: storageAccountSku
    subnetResourceId: vnet.outputs.subnetResourceId[0].id
    vmssPrincipalId: vmss.outputs.principalId
    vnetResourceId: vnet.outputs.vnetResourceId
  }
}

module kv './buildagent.kv.bicep' = {
  name: 'kvDeploy'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    subnetResourceId: vnet.outputs.subnetResourceId[0].id
    vmssPrincipalId: vmss.outputs.principalId
    vnetResourceId: vnet.outputs.vnetResourceId
  }
}

module bastion './buildagent.bastion.bicep' = {
  name: 'bastionDeploy'
  scope: rg
  params: {
    bastionHostName: 'buildagent-bastion'
    subnetResourceId: vnet.outputs.subnetResourceId[1].id
  }
}
