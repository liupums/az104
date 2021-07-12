targetScope = 'subscription'

@description('Specify the location for the Virtual Network and its related resources')
param location string = 'westus'

@description('Specify the resource group name')
param resoureGroupName string = 'hubSpokeBgp'

@description('Specify the Linux VM cloud-init.txt')
param cloudInit string

@description('Specify the admin public key')
param adminPublicKey string

//TODO use keyvault
@description('Specify the VPN shared key')
@secure()
param sharedKey string

resource azhubspokerg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: resoureGroupName
  location: location
}

var vNetHubDefinitions = {
  name: 'hub'
  location: location
  createUserDefinedRoutes: true
  addressSpacePrefix: '192.168.0.0/20' // 192.168.0.0 - 192.168.15.255
  asn: 65010
  subnets: [
    {
      name: 'AzureFirewallSubnet'    // name is fixed as AzureFirewallSubnet
      subnetPrefix: '192.168.0.0/26' // 192.168.0.0 - 192.168.0.63
    }
    {
      name: 'AzureBastionSubnet'
      subnetPrefix: '192.168.0.64/28' // 192.168.0.64 - 192.168.0.79
    }
    {
      name: 'GatewaySubnet'
      subnetPrefix: '192.168.0.96/27' // 192.168.0.96 - 192.168.0.127
    }
  ]
}

var vNetSpokeDefinitions = [
  {
    name: 'spokeProd'
    location: location
    addressSpacePrefix: '10.0.0.0/16'
    asn: 65020
    subnets: [
      {
        name: 'GatewaySubnet'
        subnetPrefix: '10.0.0.0/27' // 10.0.0.0 - 10.0.0.31
      }
      {
        name: 'subnet1'
        subnetPrefix: '10.0.1.0/24' // 10.0.1.0 - 10.0.1.255
      }
    ]
  }
  {
    name: 'spokeTest'
    location: location
    addressSpacePrefix: '10.1.0.0/16'
    asn: 65030
    subnets: [
      {
        name: 'GatewaySubnet'
        subnetPrefix: '10.1.0.0/27' // 10.1.0.0 - 10.1.0.31
      }
      {
        name: 'subnet1'
        subnetPrefix: '10.1.1.0/24' //10.1.1.0 - 10.1.1.255
      }
    ]
  }
]

// deploy the Hub/Spoke vNET
module vnetHubSpoke './vnet.bicep' = {
  name: 'HubSpokeVnet'
  scope: azhubspokerg
  params: {
    vNetHubDefinitions: vNetHubDefinitions
    vNetSpokeDefinitions: vNetSpokeDefinitions
    sharedKey: sharedKey
  }
}

// Based on output subnets, creating the VMs
var virtualMachineDefinitions = [
  {
    name: 'LinuxProd1'
    subnet: vnetHubSpoke.outputs.vNETSpokeSettings[0].subnets[1].id
    vmSize: 'Standard_A1_v2'
    cloudInit: cloudInit
  }
  {
    name: 'LinuxTest1'
    subnet: vnetHubSpoke.outputs.vNETSpokeSettings[1].subnets[1].id
    vmSize: 'Standard_A1_v2'
    cloudInit: cloudInit
  }
]

module vms '../common/linuxvm.bicep' = {
  name: 'LinuxVms'
  scope: azhubspokerg
  params: {
    virtualMachineDefinitions: virtualMachineDefinitions
    adminUsername: 'azureuser'
    adminPublicKey: adminPublicKey
  }
}
