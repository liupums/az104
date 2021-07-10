targetScope = 'subscription'

@description('Specify the location for the Virtual Network and its related resources')
param location string = 'westus'

@description('Specify the resource group name')
param resoureGroupName string = 'hubSpokeNva'

@description('Specify the admin public key')
param adminPublicKey string

@description('Specify the Linux VM cloud-init.txt')
param cloudInit string

resource azhubspokerg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: resoureGroupName
  location: location
}


// https://raw.githubusercontent.com/mspnp/samples/master/solutions/azure-hub-spoke/bicep/main.bicep

// define vNETs
// Address Spaces
// https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-faq#what-address-ranges-can-i-use-in-my-vnets
// 10.0.0.0 - 10.255.255.255 (10/8 prefix)
// 172.16.0.0 - 172.31.255.255 (172.16/12 prefix)
// 192.168.0.0 - 192.168.255.255 (192.168/16 prefix)
// https://www.subnet-calculator.org/cidr.php


var vNetHubDefinitions = {
  name: 'hub'
  location: location
  createUserDefinedRoutes: true
  addressSpacePrefix: '192.168.0.0/20' // 192.168.0.0 - 192.168.15.255
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
    subnets: [
      {
        name: 'subnet1'
        subnetPrefix: '10.0.0.0/24'
      }
    ]
  }
  {
    name: 'spokeTest'
    location: location
    addressSpacePrefix: '10.1.0.0/16'
    subnets: [
      {
        name: 'subnet1'
        subnetPrefix: '10.1.0.0/24'
      }
    ]
  }
]

// deploy the Hub/Spoke vNET
module vnetHubSpoke '../common/vnethubspoke.bicep' = {
  name: 'vnetname'
  scope: azhubspokerg
  params: {
    vNetHubDefinitions: vNetHubDefinitions
    vNetSpokeDefinitions: vNetSpokeDefinitions
  }
}

// Based on output subnets, creating the VMs
var virtualMachineDefinitions = [
  {
    name: 'LinuxProd1'
    subnet: vnetHubSpoke.outputs.vNETSpokeSettings[0].subnets[0].id
    vmSize: 'Standard_A1_v2'
    cloudInit: cloudInit
  }
  {
    name: 'LinuxTest1'
    subnet: vnetHubSpoke.outputs.vNETSpokeSettings[1].subnets[0].id
    vmSize: 'Standard_A1_v2'
    cloudInit: cloudInit
  }
]

module vms '../common/linuxvm.bicep' = {
  name: 'linuxVms'
  scope: azhubspokerg
  params: {
    virtualMachineDefinitions: virtualMachineDefinitions
    adminUsername: 'azureuser'
    adminPublicKey: adminPublicKey
  }
}

