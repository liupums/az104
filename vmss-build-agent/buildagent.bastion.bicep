@description('Bastion host name')
param bastionHostName string

@description('Full resource id of the virtual network in which to create the private endpoint')
param subnetResourceId string

var location = resourceGroup().location

resource publicIp 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: '${bastionHostName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2020-06-01' = {
  name: bastionHostName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: subnetResourceId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}
