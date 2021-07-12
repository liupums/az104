@description('The shared key used to establish connection between the two vNet Gateways.')
@secure()
param sharedKey string

@description('Location of the resources')
param location string = resourceGroup().location

var vNet1 = {
  name: 'vNet1-${location}'
  addressSpacePrefix: '10.0.0.0/23'
  subnetName: 'subnet1'
  subnetPrefix: '10.0.0.0/24'
  gatewayName: 'vNet1-Gateway'
  gatewaySubnetPrefix: '10.0.1.224/27'
  gatewayPublicIPName: 'gw1pip${uniqueString(resourceGroup().id)}'
  connectionName: 'vNet1-to-vNet2'
  asn: 65010
}
var vNet2 = {
  name: 'vNet2-${location}'
  addressSpacePrefix: '10.0.2.0/23'
  subnetName: 'subnet1'
  subnetPrefix: '10.0.2.0/24'
  gatewayName: 'vNet2-Gateway'
  gatewaySubnetPrefix: '10.0.3.224/27'
  gatewayPublicIPName: 'gw2pip${uniqueString(resourceGroup().id)}'
  connection1Name: 'vNet2-to-vNet1'
  connection2Name: 'vNet2-to-vNet3'
  asn: 65020
}
var vNet3 = {
  name: 'vNet3-${location}'
  addressSpacePrefix: '10.0.4.0/23'
  subnetName: 'subnet1'
  subnetPrefix: '10.0.4.0/24'
  gatewayName: 'vNet3-Gateway'
  gatewaySubnetPrefix: '10.0.5.224/27'
  gatewayPublicIPName: 'gw3pip${uniqueString(resourceGroup().id)}'
  connectionName: 'vNet3-to-vNet2'
  asn: 65030
}
var gateway1SubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', vNet1.name, 'GatewaySubnet')
var gateway2SubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', vNet2.name, 'GatewaySubnet')
var gateway3SubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', vNet3.name, 'GatewaySubnet')
var gatewaySku = 'Standard'

resource vNet1_name 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: vNet1.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNet1.addressSpacePrefix
      ]
    }
    subnets: [
      {
        name: vNet1.subnetName
        properties: {
          addressPrefix: vNet1.subnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: vNet1.gatewaySubnetPrefix
        }
      }
    ]
  }
}

resource vNet2_name 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: vNet2.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNet2.addressSpacePrefix
      ]
    }
    subnets: [
      {
        name: vNet2.subnetName
        properties: {
          addressPrefix: vNet2.subnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: vNet2.gatewaySubnetPrefix
        }
      }
    ]
  }
}

resource vNet3_name 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: vNet3.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNet3.addressSpacePrefix
      ]
    }
    subnets: [
      {
        name: vNet3.subnetName
        properties: {
          addressPrefix: vNet3.subnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: vNet3.gatewaySubnetPrefix
        }
      }
    ]
  }
}

resource vNet1_gatewayPublicIPName 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: vNet1.gatewayPublicIPName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vNet2_gatewayPublicIPName 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: vNet2.gatewayPublicIPName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vNet3_gatewayPublicIPName 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: vNet3.gatewayPublicIPName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vNet1_gatewayName 'Microsoft.Network/virtualNetworkGateways@2020-05-01' = {
  name: vNet1.gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gateway1SubnetRef
          }
          publicIPAddress: {
            id: vNet1_gatewayPublicIPName.id
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
      asn: vNet1.asn
    }
  }
  dependsOn: [
    vNet1_name
  ]
}

resource vNet2_gatewayName 'Microsoft.Network/virtualNetworkGateways@2020-05-01' = {
  name: vNet2.gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gateway2SubnetRef
          }
          publicIPAddress: {
            id: vNet2_gatewayPublicIPName.id
          }
        }
        name: 'vNet2GatewayConfig'
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
      asn: vNet2.asn
    }
  }
  dependsOn: [
    vNet2_name
  ]
}

resource vNet3_gatewayName 'Microsoft.Network/virtualNetworkGateways@2020-05-01' = {
  name: vNet3.gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gateway3SubnetRef
          }
          publicIPAddress: {
            id: vNet3_gatewayPublicIPName.id
          }
        }
        name: 'vNet3GatewayConfig'
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
      asn: vNet3.asn
    }
  }
  dependsOn: [
    vNet3_name
  ]
}

resource vNet1_connectionName 'Microsoft.Network/connections@2020-05-01' = {
  name: vNet1.connectionName
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: vNet1_gatewayName.id
    }
    virtualNetworkGateway2: {
      id: vNet2_gatewayName.id
    }
    connectionType: 'Vnet2Vnet'
    routingWeight: 3
    sharedKey: sharedKey
    enableBgp: true
  }
}

resource vNet2_connection1Name 'Microsoft.Network/connections@2020-05-01' = {
  name: vNet2.connection1Name
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: vNet2_gatewayName.id
    }
    virtualNetworkGateway2: {
      id: vNet1_gatewayName.id
    }
    connectionType: 'Vnet2Vnet'
    routingWeight: 3
    sharedKey: sharedKey
    enableBgp: true
  }
}

resource vNet2_connection2Name 'Microsoft.Network/connections@2020-05-01' = {
  name: vNet2.connection2Name
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: vNet2_gatewayName.id
    }
    virtualNetworkGateway2: {
      id: vNet3_gatewayName.id
    }
    connectionType: 'Vnet2Vnet'
    routingWeight: 3
    sharedKey: sharedKey
    enableBgp: true
  }
}

resource vNet3_connectionName 'Microsoft.Network/connections@2020-05-01' = {
  name: vNet3.connectionName
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: vNet3_gatewayName.id
    }
    virtualNetworkGateway2: {
      id: vNet2_gatewayName.id
    }
    connectionType: 'Vnet2Vnet'
    routingWeight: 3
    sharedKey: sharedKey
    enableBgp: true
  }
}