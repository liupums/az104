// Define Hub vNET
param vNetHubDefinitions object
// Define a list of Spoke vNET
param vNetSpokeDefinitions array

@description('The shared key used to establish connection between the two vNet Gateways.')
@secure()
param sharedKey string

var location = resourceGroup().location

// Create vNET resources based on vNET definition above
resource vNetsHubResource 'Microsoft.Network/virtualNetworks@2020-05-01' =  {
  name: vNetHubDefinitions.name
  location: vNetHubDefinitions.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetHubDefinitions.addressSpacePrefix
      ]
    }
    subnets: [ for s in vNetHubDefinitions.subnets: {
      name: s.name
      properties: {
        addressPrefix: s.subnetPrefix
      }
    }]
  }
}

// Create Spoke vNET resources
resource vNetSpokeResources 'Microsoft.Network/virtualNetworks@2020-05-01' = [ for (spoke, i) in vNetSpokeDefinitions: {
  name: spoke.name
  location: spoke.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke.addressSpacePrefix
      ]
    }
    subnets: [ for s in spoke.subnets: {
      name: s.name
      properties: {
        addressPrefix: s.subnetPrefix
      }
    }]
  }
}]

var gatewaySku = 'Standard'

resource vNetHub_gatewayPublicIPName 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: 'HubGatewayPublicIPName'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vNetSpokeGatewayPublicIPName 'Microsoft.Network/publicIPAddresses@2020-05-01' =  [ for (spoke, i) in vNetSpokeDefinitions: {
  name: '${spoke.name}_GatewayPublicIPName'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}]

resource vNetHubGatewayName 'Microsoft.Network/virtualNetworkGateways@2020-05-01' = {
  name: 'vNetHubGatewayName'
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetHubDefinitions.name, 'GatewaySubnet')
          }
          publicIPAddress: {
            id: vNetHub_gatewayPublicIPName.id
          }
        }
        name: 'vNet1GatewayConfig'
      }
    ]
    gatewayType: 'Vpn'
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    vpnType: 'RouteBased'
    enableBgp: true
    bgpSettings: {
      asn: vNetHubDefinitions.asn
    }
  }
  dependsOn: [
    vNetsHubResource
  ]
}

resource vNetSpokeGatewayName 'Microsoft.Network/virtualNetworkGateways@2020-05-01' = [ for (spoke, i) in vNetSpokeDefinitions: {
  name: '${spoke.name}_gatewayName'
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', spoke.name, 'GatewaySubnet')
          }
          publicIPAddress: {
            id: vNetSpokeGatewayPublicIPName[i].id
          }
        }
        name: '${spoke.name}_gatewayConfig'
      }
    ]
    gatewayType: 'Vpn'
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    vpnType: 'RouteBased'
    enableBgp: true
    bgpSettings: {
      asn: spoke.asn
    }
  }
  dependsOn: [
    vNetSpokeResources[i]
  ]
}]

resource vNetHubToSpokeConnectionName 'Microsoft.Network/connections@2020-05-01' = [ for (spoke, i) in vNetSpokeDefinitions: {
  name: 'HubTo${spoke.name}_ConnectionName'
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: vNetHubGatewayName.id
      properties: {
      }
    }
    virtualNetworkGateway2: {
      id: vNetSpokeGatewayName[i].id
      properties: {
      }
    }
    connectionType: 'Vnet2Vnet'
    routingWeight: 3
    sharedKey: sharedKey
    enableBgp: true
  }
}]

resource vNetSpokeToHubConnectionName 'Microsoft.Network/connections@2020-05-01' = [ for (spoke, i) in vNetSpokeDefinitions: {
  name: '${spoke.name}ToHub_ConnectionName'
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: vNetSpokeGatewayName[i].id
      properties: {
      }
    }
    virtualNetworkGateway2: {
      id: vNetHubGatewayName.id
      properties: {       
      }
    }
    connectionType: 'Vnet2Vnet'
    routingWeight: 3
    sharedKey: sharedKey
    enableBgp: true
  }
}]

output vNETSpokeSettings array = [ for (config, i) in vNetSpokeDefinitions: {
  subnets: vNetSpokeResources[i].properties.subnets
}] 
