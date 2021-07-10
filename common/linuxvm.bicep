@description('Location of the resources')
param location string = resourceGroup().location
param virtualMachineDefinitions array
@description('Specifies a username for the Virtual Machine.')
param adminUsername string

@description('Specifies the SSH rsa public key file as a string. Use "ssh-keygen -t rsa -b 2048" to generate your SSH key pairs.')
param adminPublicKey string

resource publicIPAddressName 'Microsoft.Network/publicIPAddresses@2020-05-01' = [ for (config, i) in virtualMachineDefinitions: {
  name: '${config.name}-pip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
  sku: {
    name: 'Basic'
  }
}]

resource nicNameLinuxResource 'Microsoft.Network/networkInterfaces@2020-05-01' = [for (config, i) in virtualMachineDefinitions: {
  name: config.name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddressName[i].id
          }
          subnet: {
            id: config.subnet
          }
        }
      }
    ]
  }
}]

// see how to use cloud-init
// https://docs.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-automate-vm-deployment
resource vmNameLinuxResource 'Microsoft.Compute/virtualMachines@2019-07-01' = [for (config, i) in virtualMachineDefinitions: {
  name: config.name
  location: location
  dependsOn:[
    nicNameLinuxResource
  ]
  properties: {
    hardwareProfile: {
      vmSize: config.vmSize
    }
    osProfile: {
      computerName: config.name
      adminUsername: adminUsername
      customData: config.cloudInit
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicNameLinuxResource[i].id
        }
      ]
    }
  }
}]
