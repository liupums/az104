
// Define Hub vNET
param vNetHubDefinitions object
// Define a list of Spoke vNET
param vNetSpokeDefinitions array

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

// create firewall
var firewallDefinitions = {
  name: 'hub-firewall'
  publicIPAddressName: 'hub-firewall-pip'
  location: vNetHubDefinitions.location
  subnet: vNetsHubResource.properties.subnets[0].id // subnet index 0 for firewall subnet
  allowedOutbound: [ 
    '10.1.0.0/24' 
  ] // hard-coded subnet for SpokeTest
  snatVmIp: '10.1.0.4'
}

module hubFirewall './firewall.bicep' = {
  name: 'hubFirewall'
  params: {
    firewallDefinitions: firewallDefinitions
  }
}

//Create User Defined Route Acc
resource udr 'Microsoft.Network/routeTables@2020-06-01' = if (vNetHubDefinitions.createUserDefinedRoutes) {
  name: 'RouteToFirewall'
  location: vNetHubDefinitions.location
  properties: {
    routes: [
      {
        name: 'udrRouteName'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: hubFirewall.outputs.firewallPrivateIp
        }
      }
    ]
    disableBgpRoutePropagation: false
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
        routeTable: {
          id: udr.id
        }
      }
    }]
  }
}]

// Create vNET peering spoke to hub for each spoke
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-05-01' = [ for (spoke, i) in vNetSpokeDefinitions: {
  name: 'spokeToHub-${spoke.name}'
  parent: vNetSpokeResources[i] // using parent is the best practise
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true // for transitive spoke connection, set this to true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vNetsHubResource.id
    }
  }
}]

// Create vNET peering hub to spoke for each spoke
resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-05-01' = [ for (spoke, i) in vNetSpokeDefinitions: {
  name: 'hubToSpoke-${spoke.name}'
  parent: vNetsHubResource // using parent is the best practise
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true // for transitive spoke connection, set this to true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: vNetSpokeResources[i].id
    }
  }
}]

output properties object = {
  vNetHubId: vNetsHubResource.id
  routeTableId: udr.id
}

output vNETSpokeSettings array = [ for (config, i) in vNetSpokeDefinitions: {
  subnets: vNetSpokeResources[i].properties.subnets
}] 

