// Define firewalls
param firewallDefinitions object

// public IP is required for firewall
// https://docs.microsoft.com/en-us/azure/firewall/firewall-faq#can-i-deploy-azure-firewall-without-a-public-ip-address
resource pipFirewall 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: firewallDefinitions.publicIPAddressName
  location: firewallDefinitions.location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2020-05-01' = {
  name: firewallDefinitions.name
  location: firewallDefinitions.location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: firewallDefinitions.name
        properties: {
          publicIPAddress: {
            id: pipFirewall.id
          }
          subnet: {
            id: firewallDefinitions.subnet
          }
        }
      }
    ]
    networkRuleCollections: [
      {
        name: 'Allow-test-outbound'
        properties: {
          priority: 200
          action: {
            type: 'Allow'
          }
          rules:[
            {
              name: 'allow-subnet-outbound'
              protocols: [
                'Any'
              ]
              sourceAddresses: firewallDefinitions.allowedOutbound  // allowed outbound for subnet
              destinationAddresses: [
                '*'
              ]
              destinationPorts: [
                '*'
              ]
            }
          ]
        }
      }
    ]
    natRuleCollections: [
      {
        name: 'allowSSH'
        properties: {
          priority: 200
          action: {
            type: 'Dnat'
          }
          rules: [
            {
              name: 'allowSshToTest'
              protocols: [
                'TCP'
              ]
              translatedAddress: firewallDefinitions.snatVmIp
              translatedPort: '22'
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                pipFirewall.properties.ipAddress
              ]
              destinationPorts: [
                '22'
              ]
            }
          ]
        }
      }
    ]
  }
}

// output firewall's private ip for route table applied to spoke vnet subnets

output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
