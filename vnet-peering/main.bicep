targetScope = 'subscription'

@description('Specify the location for the Virtual Network and its related resources')
param location string = 'westus'

@description('Specify the resource group name')
param resoureGroupName string = 'az104'

@description('Specify the admin public key')
param adminPublicKey string

resource az104rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: resoureGroupName
  location: location
}

// define vNETs
// vNET1 (subnet1) and vNET2 (subnet1)
var vNetsDefinitions = [
  {
    name: 'vNet1'
    location: location
    addressSpacePrefix: '10.0.0.0/16'
    subnets: [
      {
        name: 'subnet1'
        subnetPrefix: '10.0.0.0/24'
      }
    ]
  }
  {
    name: 'vNet2'
    location: location
    addressSpacePrefix: '192.168.0.0/16'
    subnets: [
      {
        name: 'subnet1'
        subnetPrefix: '192.168.0.0/24'
      }
    ]
  }
]

// define peering
// vNET1 --> vNET2
// vNET2 --> vNET1
var vNetsPeeringDefinitions = [
  {
    name: 'vNet1-vNet2'
    myId: 0 // index 0
    remoteId: 1 // index 1
  }
  {
    name: 'vNet2-vNet1'
    myId: 1  // index 1
    remoteId: 0 // index 0
  }
]

// deploy the vNET and peering
module vnets './vnet.bicep' = {
  name: 'vnetname'
  scope: az104rg
  params: {
    vNetsDefinitions: vNetsDefinitions
    vNetsPeeringDefinitions: vNetsPeeringDefinitions
  }
}

// Based on output subnets, creating the VMs
var virtualMachineDefinitions = [
  {
    name: 'LinuxVnet1Subnet1Vm1'
    subnet: vnets.outputs.vNETSettings[0].subnets[0].id
    vmSize: 'Standard_A1_v2'
  }
  {
    name: 'LinuxVnet2Subnet1Vm1'
    subnet: vnets.outputs.vNETSettings[1].subnets[0].id
    vmSize: 'Standard_A1_v2'
  }
]

module vms './vm.bicep' = {
  name: 'vmname'
  scope: az104rg
  params: {
    virtualMachineDefinitions: virtualMachineDefinitions
    adminUsername: 'azureuser'
    adminPublicKey: adminPublicKey
  }
}
