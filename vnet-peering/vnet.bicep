
// Define vNETs
param vNetsDefinitions array

// Define peering configuration
param vNetsPeeringDefinitions array 


// Create vNET resources based on vNET definition above
resource vNetsResources 'Microsoft.Network/virtualNetworks@2020-05-01' = [ for (config, i) in vNetsDefinitions: {
  name: config.name
  location: config.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        config.addressSpacePrefix
      ]
    }
    subnets: [ for s in config.subnets: {
      name: s.name
      properties: {
        addressPrefix: s.subnetPrefix
      }
    }]
  }
}]

// Create vNET peering
resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-05-01' = [ for (config, i) in vNetsPeeringDefinitions: {
  name: config.name
  parent: vNetsResources[config.myId]
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vNetsResources[config.remoteId].id
    }
  }
}]

output subnets array = [ for (config, i) in vNetsDefinitions: {
  subnets: vNetsResources[i].properties.subnets
}] 
