@description('The admin user name for both the Windows and Linux virtual machines.')
param adminUserName string

@description('The admin password for both the Windows and Linux virtual machines.')
@secure()
param adminPassword string

@description('The count of Windows virtual machines to create.')
param windowsVMCount int = 0

@description('The count of Windows virtual machines to create.')
param linuxVMCount int = 0
param vmSize string = 'Standard_A1_v2'
param deployVpnGateway bool = false
param hubNetwork object = {
  name: 'vnet-hub'
  addressPrefix: '10.0.0.0/20'
}
param spokeNetwork object = {
  name: 'vnet-spoke-one'
  addressPrefix: '10.100.0.0/16'
  subnetName: 'snet-spoke-resources'
  subnetPrefix: '10.100.0.0/16'
  subnetNsgName: 'nsg-spoke-one-resources'
}
param spokeNetworkTwo object = {
  name: 'vnet-spoke-two'
  addressPrefix: '10.200.0.0/16'
  subnetName: 'snet-spoke-resources'
  subnetPrefix: '10.200.0.0/16'
  subnetNsgName: 'nsg-spoke-two-resources'
}
param vpnGateway object = {
  name: 'vgw-gateway'
  subnetName: 'GatewaySubnet'
  subnetPrefix: '10.0.2.0/27'
  pipName: 'pip-vgw-gateway'
}
param bastionHost object = {
  name: 'AzureBastionHost'
  publicIPAddressName: 'pip-bastion'
  subnetName: 'AzureBastionSubnet'
  nsgName: 'nsg-hub-bastion'
  subnetPrefix: '10.0.1.0/29'
}
param azureFirewall object = {
  name: 'AzureFirewall'
  publicIPAddressName: 'pip-firewall'
  subnetName: 'AzureFirewallSubnet'
  subnetPrefix: '10.0.3.0/26'
  routeName: 'r-nexthop-to-fw'
}
param workbookDisplayName string = 'Azure Firewall Workbook'
param workbookId string = guid(resourceGroup().id)
param location string = resourceGroup().location

var logAnalyticsWorkspace_var = uniqueString(subscription().subscriptionId, resourceGroup().id)
var peering_name_hub_to_spoke_one = 'hub-to-spoke-one'
var peering_name_hub_to_spoke_two = 'hub-to-spoke-two'
var peering_name_spoke_to_hub_one = 'spoke-one-to-hub'
var peering_name_spoke_to_hub_two = 'spoke-two-to-hub'
var nicNameWindows_var = 'nic-windows-'
var vmNameWindows_var = 'vm-windows-'
var windowsOSVersion = '2016-Datacenter'
var nicNameLinux_var = 'nic-linux-'
var osVersion = '16.04.0-LTS'
var vmNameLinux_var = 'vm-linux-'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: logAnalyticsWorkspace_var
  location: location
  properties: {
    sku: {
      name: 'Free'
    }
  }
}

resource hubNetwork_name 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: hubNetwork.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubNetwork.addressPrefix
      ]
    }
    subnets: [
      {
        name: azureFirewall.subnetName
        properties: {
          addressPrefix: azureFirewall.subnetPrefix
        }
      }
      {
        name: bastionHost.subnetName
        properties: {
          addressPrefix: bastionHost.subnetPrefix
        }
      }
      {
        name: vpnGateway.subnetName
        properties: {
          addressPrefix: vpnGateway.subnetPrefix
        }
      }
    ]
  }
}

resource hubNetwork_name_Microsoft_Insights_default_logAnalyticsWorkspace 'Microsoft.Network/virtualNetworks/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${hubNetwork.name}/Microsoft.Insights/default${logAnalyticsWorkspace_var}'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'VMProtectionAlerts'
        enabled: true
      }
    ]
  }
  dependsOn: [
    hubNetwork_name
  ]
}

resource hubNetwork_name_azureFirewall_subnetName 'Microsoft.Network/virtualNetworks/subnets@2020-05-01' = {
  name: '${hubNetwork.name}/${azureFirewall.subnetName}'
  properties: {
    addressPrefix: azureFirewall.subnetPrefix
  }
  dependsOn: [
    hubNetwork_name
  ]
}

resource azureFirewall_publicIPAddressName 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: azureFirewall.publicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource azureFirewall_name 'Microsoft.Network/azureFirewalls@2020-05-01' = {
  name: azureFirewall.name
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    additionalProperties: {}
    ipConfigurations: [
      {
        name: azureFirewall.name
        properties: {
          publicIPAddress: {
            id: azureFirewall_publicIPAddressName.id
          }
          subnet: {
            id: hubNetwork_name_azureFirewall_subnetName.id
          }
        }
      }
    ]
  }
  dependsOn: [
    hubNetwork_name
  ]
}

resource azureFirewall_name_Microsoft_Insights_default_logAnalyticsWorkspace 'Microsoft.Network/azureFirewalls/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${azureFirewall.name}/Microsoft.Insights/default${logAnalyticsWorkspace_var}'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
      }
    ]
  }
  dependsOn: [
    azureFirewall_name
  ]
}

resource azureFirewall_routeName 'Microsoft.Network/routeTables@2020-05-01' = {
  name: azureFirewall.routeName
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: azureFirewall.routeName
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: reference(azureFirewall_name.id, '2020-05-01').ipConfigurations[0].properties.privateIpAddress
        }
      }
    ]
  }
}

resource spokeNetwork_subnetNsgName 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: spokeNetwork.subnetNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'bastion-in-vnet'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: bastionHost.subnetPrefix
          destinationPortRanges: [
            '22'
            '3389'
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource spokeNetwork_subnetNsgName_Microsoft_Insights_default_logAnalyticsWorkspace 'Microsoft.Network/networkSecurityGroups/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${spokeNetwork.subnetNsgName}/Microsoft.Insights/default${logAnalyticsWorkspace_var}'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
  dependsOn: [
    spokeNetwork_subnetNsgName
  ]
}

resource spokeNetwork_name 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: spokeNetwork.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeNetwork.addressPrefix
      ]
    }
    subnets: [
      {
        name: spokeNetwork.subnetName
        properties: {
          addressPrefix: spokeNetwork.subnetPrefix
          networkSecurityGroup: {
            id: spokeNetwork_subnetNsgName.id
          }
          routeTable: {
            id: azureFirewall_routeName.id
          }
        }
      }
    ]
  }
}

resource spokeNetwork_name_Microsoft_Insights_default_logAnalyticsWorkspace 'Microsoft.Network/virtualNetworks/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${spokeNetwork.name}/Microsoft.Insights/default${logAnalyticsWorkspace_var}'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'VMProtectionAlerts'
        enabled: true
      }
    ]
  }
  dependsOn: [
    spokeNetwork_name
  ]
}

resource spokeNetworkTwo_subnetNsgName 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: spokeNetworkTwo.subnetNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'bastion-in-vnet'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: bastionHost.subnetPrefix
          destinationPortRanges: [
            '22'
            '3389'
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource spokeNetworkTwo_subnetNsgName_Microsoft_Insights_default_logAnalyticsWorkspace 'Microsoft.Network/networkSecurityGroups/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${spokeNetworkTwo.subnetNsgName}/Microsoft.Insights/default${logAnalyticsWorkspace_var}'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
  dependsOn: [
    spokeNetworkTwo_subnetNsgName
  ]
}

resource spokeNetworkTwo_name 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: spokeNetworkTwo.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeNetworkTwo.addressPrefix
      ]
    }
    subnets: [
      {
        name: spokeNetworkTwo.subnetName
        properties: {
          addressPrefix: spokeNetworkTwo.subnetPrefix
          networkSecurityGroup: {
            id: spokeNetworkTwo_subnetNsgName.id
          }
          routeTable: {
            id: azureFirewall_routeName.id
          }
        }
      }
    ]
  }
}

resource spokeNetworkTwo_name_Microsoft_Insights_default_logAnalyticsWorkspace 'Microsoft.Network/virtualNetworks/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${spokeNetworkTwo.name}/Microsoft.Insights/default${logAnalyticsWorkspace_var}'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'VMProtectionAlerts'
        enabled: true
      }
    ]
  }
  dependsOn: [
    spokeNetworkTwo_name
  ]
}

resource hubNetwork_name_peering_name_hub_to_spoke_one 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-05-01' = {
  name: '${hubNetwork.name}/${peering_name_hub_to_spoke_one}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeNetwork_name.id
    }
  }
  dependsOn: [
    hubNetwork_name
  ]
}

resource hubNetwork_name_peering_name_hub_to_spoke_two 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-05-01' = {
  name: '${hubNetwork.name}/${peering_name_hub_to_spoke_two}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeNetworkTwo_name.id
    }
  }
  dependsOn: [
    hubNetwork_name
  ]
}

resource spokeNetwork_name_peering_name_spoke_to_hub_one 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-05-01' = {
  name: '${spokeNetwork.name}/${peering_name_spoke_to_hub_one}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubNetwork_name.id
    }
  }
  dependsOn: [
    spokeNetwork_name
  ]
}

resource spokeNetworkTwo_name_peering_name_spoke_to_hub_two 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-05-01' = {
  name: '${spokeNetworkTwo.name}/${peering_name_spoke_to_hub_two}'
  location: location
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubNetwork_name.id
    }
  }
  dependsOn: [
    spokeNetworkTwo_name
  ]
}

resource bastionHost_publicIPAddressName 'Microsoft.Network/publicIpAddresses@2020-05-01' = {
  name: bastionHost.publicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost_nsgName 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: bastionHost.nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'bastion-in-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'bastion-control-in-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'bastion-in-host'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'bastion-vnet-out-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'bastion-azure-out-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'bastion-out-host'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'bastion-out-deny'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource bastionHost_nsgName_Microsoft_Insights_default_logAnalyticsWorkspace 'Microsoft.Network/networkSecurityGroups/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${bastionHost.nsgName}/Microsoft.Insights/default${logAnalyticsWorkspace_var}'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
  dependsOn: [
    bastionHost_nsgName
  ]
}

resource hubNetwork_name_bastionHost_subnetName 'Microsoft.Network/virtualNetworks/subnets@2020-05-01' = {
  name: '${hubNetwork.name}/${bastionHost.subnetName}'
  properties: {
    addressPrefix: bastionHost.subnetPrefix
    networkSecurityGroup: {
      id: bastionHost_nsgName.id
    }
  }
  dependsOn: [
    hubNetwork_name
  ]
}

resource bastionHost_name 'Microsoft.Network/bastionHosts@2020-06-01' = {
  name: bastionHost.name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: hubNetwork_name_bastionHost_subnetName.id
          }
          publicIPAddress: {
            id: bastionHost_publicIPAddressName.id
          }
        }
      }
    ]
  }
  dependsOn: [
    hubNetwork_name
  ]
}

resource bastionHost_name_Microsoft_Insights_default_logAnalyticsWorkspace 'Microsoft.Network/bastionHosts/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${bastionHost.name}/Microsoft.Insights/default${logAnalyticsWorkspace_var}'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'BastionAuditLogs'
        enabled: true
      }
    ]
  }
  dependsOn: [
    bastionHost_name
  ]
}

resource vpnGateway_pipName 'Microsoft.Network/publicIPAddresses@2019-11-01' = if (deployVpnGateway) {
  name: vpnGateway.pipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vpnGateway_name 'Microsoft.Network/virtualNetworkGateways@2019-11-01' = if (deployVpnGateway) {
  name: vpnGateway.name
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubNetwork.name, vpnGateway.subnetName)
          }
          publicIPAddress: {
            id: vpnGateway_pipName.id
          }
        }
        name: 'vnetGatewayConfig'
      }
    ]
    sku: {
      name: 'Basic'
      tier: 'Basic'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
  }
  dependsOn: [
    hubNetwork_name
  ]
}

resource vpnGateway_name_Microsoft_Insights_default_logAnalyticsWorkspace 'Microsoft.Network/virtualNetworkGateways/providers/diagnosticSettings@2017-05-01-preview' = if (deployVpnGateway) {
  name: '${vpnGateway.name}/Microsoft.Insights/default${logAnalyticsWorkspace_var}'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'GatewayDiagnosticLog'
        enabled: true
      }
      {
        category: 'TunnelDiagnosticLog'
        enabled: true
      }
      {
        category: 'RouteDiagnosticLog'
        enabled: true
      }
      {
        category: 'IKEDiagnosticLog'
        enabled: true
      }
      {
        category: 'P2SDiagnosticLog'
        enabled: true
      }
    ]
  }
  dependsOn: [
    vpnGateway_name
  ]
}

resource nicNameWindows 'Microsoft.Network/networkInterfaces@2020-05-01' = [for i in range(0, windowsVMCount): {
  name: concat(nicNameWindows_var, i)
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', spokeNetwork.name, spokeNetwork.subnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    spokeNetwork_name
  ]
}]

resource vmNameWindows 'Microsoft.Compute/virtualMachines@2019-07-01' = [for i in range(0, windowsVMCount): {
  name: concat(vmNameWindows_var, i)
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: concat(vmNameWindows_var, i)
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', concat(nicNameWindows_var, i))
        }
      ]
    }
  }
  dependsOn: [
    concat(nicNameWindows_var, i)
  ]
}]

resource nicNameLinux 'Microsoft.Network/networkInterfaces@2020-05-01' = [for i in range(0, linuxVMCount): {
  name: concat(nicNameLinux_var, i)
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', spokeNetwork.name, spokeNetwork.subnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    spokeNetwork_name
  ]
}]

resource vmNameLinux 'Microsoft.Compute/virtualMachines@2019-07-01' = [for i in range(0, linuxVMCount): {
  name: concat(vmNameLinux_var, i)
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: concat(vmNameLinux_var, i)
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: osVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', concat(nicNameLinux_var, i))
        }
      ]
    }
  }
  dependsOn: [
    concat(nicNameLinux_var, i)
  ]
}]

resource workbookId_resource 'microsoft.insights/workbooks@2018-06-17-preview' = {
  name: workbookId
  location: location
  kind: 'shared'
  properties: {
    version: '1.0'
    sourceId: logAnalyticsWorkspace.id
    category: 'workbook'
    displayName: workbookDisplayName
    serializedData: '{"version":"Notebook/1.0","items":[{"type":1,"content":{"json":"## Azure Firewall Workbook\\r\\n---\\r\\n"},"name":"text - 23"},{"type":11,"content":{"version":"LinkItem/1.0","style":"tabs","links":[{"cellValue":"selectedTab","linkTarget":"parameter","linkLabel":"Azure Firewall Overview","subTarget":"AFOverview","preText":"Azure Firewall Overview","style":"link"},{"cellValue":"selectedTab","linkTarget":"parameter","linkLabel":"Azure Firewall - Application rule log statitics","subTarget":"AFAppRule","style":"link"},{"cellValue":"selectedTab","linkTarget":"parameter","linkLabel":"Azure Firewall - Network rule log statistics","subTarget":"AFNetRule","style":"link"},{"cellValue":"selectedTab","linkTarget":"parameter","linkLabel":"Azure Firewall - DNS Proxy","subTarget":"AFDNSProxy","style":"link"},{"cellValue":"selectedTab","linkTarget":"parameter","linkLabel":"Azure Firewall - Investigation","subTarget":"AFInvestigate","style":"link"}]},"name":"links - 24"},{"type":9,"content":{"version":"KqlParameterItem/1.0","crossComponentResources":["value::selected"],"parameters":[{"id":"ab7d6c51-d7df-436c-96a2-429163aa50ec","version":"KqlParameterItem/1.0","name":"TimeRange","type":4,"isRequired":true,"value":{"durationMs":2419200000},"typeSettings":{"selectableValues":[{"durationMs":300000},{"durationMs":900000},{"durationMs":1800000},{"durationMs":3600000},{"durationMs":14400000},{"durationMs":43200000},{"durationMs":86400000},{"durationMs":172800000},{"durationMs":259200000},{"durationMs":604800000},{"durationMs":1209600000},{"durationMs":2419200000},{"durationMs":2592000000},{"durationMs":5184000000},{"durationMs":7776000000}],"allowCustom":true}},{"id":"add90eb3-ff5f-4b19-9658-ff15c8043af5","version":"KqlParameterItem/1.0","name":"Workspaces","type":5,"isRequired":true,"multiSelect":true,"quote":"\'","delimiter":",","query":"where type =~ \'microsoft.operationalinsights/workspaces\'\\r\\n| project id, name\\r\\n| order by name desc","crossComponentResources":["value::selected"],"value":["/subscriptions/7b76bfbc-cb1e-4df1-b6e8-b826eef6c592/resourceGroups/SOC/providers/Microsoft.OperationalInsights/workspaces/CyberSecuritySOC"],"typeSettings":{"additionalResourceOptions":["value::100"]},"queryType":1,"resourceType":"microsoft.resourcegraph/resources"},{"id":"5084e141-6c56-4d7f-bd8a-09f7ef9af1bc","version":"KqlParameterItem/1.0","name":"Resource","label":"Azure Firewalls","type":5,"isRequired":true,"multiSelect":true,"quote":"\'","delimiter":",","query":"where type =~ \'Microsoft.Network/azureFirewalls\'\\r\\n| project id, name","crossComponentResources":["value::selected"],"value":["/subscriptions/7b76bfbc-cb1e-4df1-b6e8-b826eef6c592/resourceGroups/SOC-NS/providers/Microsoft.Network/azureFirewalls/SOC-NS-FW"],"typeSettings":{"additionalResourceOptions":["value::all"]},"queryType":1,"resourceType":"microsoft.resourcegraph/resources"}],"style":"pills","queryType":1,"resourceType":"microsoft.resourcegraph/resources"},"name":"parameters - 1"},{"type":1,"content":{"json":"# Azure Firewall - overview"},"conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFOverview"},"name":"Main title"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| where ResourceType == \\"AZUREFIREWALLS\\" \\r\\n| summarize Volume=count() by bin(TimeGenerated, {TimeRange:grain})","size":0,"title":"Events, by time","noDataMessage":"There are no firewall events being feed within the selected workspaces. If you believe the selection is correct, confirm logging has been enabled for the Azure Firewall and feeding into the selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":4,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"timechart"},"customWidth":"25","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFOverview"},"name":"query - 16"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| where ResourceType == \\"AZUREFIREWALLS\\" \\r\\n| summarize Volume=count() by Resource, bin(TimeGenerated, {TimeRange:grain})","size":0,"title":"Events, by firewall over time","noDataMessage":"There are no firewall events being feed within the selected workspaces. If you believe the selection is correct, confirm logging has been enabled for the Azure Firewall and feeding into the selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":4,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","exportParameterName":"TopEvent","exportDefaultValue":"{\\"Resource\\":\\"*\\",\\"ResourceGroup\\":\\"*\\"}","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"linechart","tileSettings":{"titleContent":{"columnMatch":"Resource","formatter":1},"leftContent":{"columnMatch":"amount","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}},"showBorder":true}},"customWidth":"25","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFOverview"},"name":"Firewall per Resource Group"},{"type":3,"content":{"version":"KqlItem/1.0","query":"let AFTI = AzureDiagnostics \\r\\n| where ResourceType == \\"AZUREFIREWALLS\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| where OperationName == \\"AzureFirewallThreatIntelLog\\"\\r\\n| summarize Volume=count() by OperationName\\r\\n| project Category=OperationName, Volume;\\r\\nAzureDiagnostics \\r\\n| where ResourceType == \\"AZUREFIREWALLS\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| where OperationName <> \\"AzureFirewallThreatIntelLog\\"\\r\\n| summarize Volume=count() by Category\\r\\n| union AFTI","size":0,"title":"Events, by category","noDataMessage":"There are no firewall events being feed within the selected workspaces. If you believe the selection is correct, confirm logging has been enabled for the Azure Firewall and feeding into the selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":4,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","exportFieldName":"Category","exportParameterName":"SelectedCategory","exportDefaultValue":"*","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"piechart","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"Category","formatter":1},"leftContent":{"columnMatch":"Volume","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}}},"customWidth":"25","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFOverview"},"name":"Events by category"},{"type":3,"content":{"version":"KqlItem/1.0","query":"let AFTI = AzureDiagnostics \\r\\n| where ResourceType == \\"AZUREFIREWALLS\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| where OperationName == \\"AzureFirewallThreatIntelLog\\"\\r\\n| summarize Volume=count() by OperationName, bin(TimeGenerated, {TimeRange:grain})\\r\\n| project Category=OperationName, Volume, TimeGenerated;\\r\\nAzureDiagnostics \\r\\n| where ResourceType == \\"AZUREFIREWALLS\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| where OperationName <> \\"AzureFirewallThreatIntelLog\\"\\r\\n| summarize Volume=count() by Category, bin(TimeGenerated, {TimeRange:grain})\\r\\n| union AFTI","size":0,"title":"Events categories, by time","noDataMessage":"There are no firewall events being feed within the selected workspaces. If you believe the selection is correct, confirm logging has been enabled for the Azure Firewall and feeding into the selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":4,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"timechart"},"customWidth":"25","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFOverview"},"name":"Events categories by time"},{"type":10,"content":{"chartId":"workbook76864ed5-dd34-42d0-ae35-f3db9f9e8f15","version":"MetricsItem/2.0","size":0,"chartType":2,"resourceType":"microsoft.network/azurefirewalls","metricScope":0,"resourceParameter":"Resource","resourceIds":["{Resource}"],"timeContextFromParameter":"TimeRange","timeContext":{"durationMs":2419200000},"metrics":[{"namespace":"microsoft.network/azurefirewalls","metric":"microsoft.network/azurefirewalls--Throughput","aggregation":4,"splitBy":null,"columnName":"All Firewall Throughput Average"}],"title":"Average Throughput of Firewall Traffic","gridSettings":{"rowLimit":10000}},"customWidth":"50","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFOverview"},"name":"metric - 25"},{"type":10,"content":{"chartId":"workbook76864ed5-dd34-42d0-ae35-f3db9f9e8f15","version":"MetricsItem/2.0","size":0,"chartType":2,"resourceType":"microsoft.network/azurefirewalls","metricScope":0,"resourceParameter":"Resource","resourceIds":["{Resource}"],"timeContextFromParameter":"TimeRange","timeContext":{"durationMs":2419200000},"metrics":[{"namespace":"microsoft.network/azurefirewalls","metric":"microsoft.network/azurefirewalls--SNATPortUtilization","aggregation":4,"splitBy":null}],"title":"SNAT Port Utilization","gridSettings":{"rowLimit":10000}},"customWidth":"50","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFOverview"},"name":"metric - 25 - Copy"},{"type":10,"content":{"chartId":"workbook76864ed5-dd34-42d0-ae35-f3db9f9e8f15","version":"MetricsItem/2.0","size":0,"chartType":2,"resourceType":"microsoft.network/azurefirewalls","metricScope":0,"resourceParameter":"Resource","resourceIds":["{Resource}"],"timeContextFromParameter":"TimeRange","timeContext":{"durationMs":2419200000},"metrics":[{"namespace":"microsoft.network/azurefirewalls","metric":"microsoft.network/azurefirewalls--NetworkRuleHit","aggregation":1,"splitBy":null}],"title":"Network Rule Hitcount (SUM)","gridSettings":{"rowLimit":10000}},"customWidth":"50","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFOverview"},"name":"metric - 25 - Copy - Copy"},{"type":10,"content":{"chartId":"workbook76864ed5-dd34-42d0-ae35-f3db9f9e8f15","version":"MetricsItem/2.0","size":0,"chartType":2,"resourceType":"microsoft.network/azurefirewalls","metricScope":0,"resourceParameter":"Resource","resourceIds":["{Resource}"],"timeContextFromParameter":"TimeRange","timeContext":{"durationMs":2419200000},"metrics":[{"namespace":"microsoft.network/azurefirewalls","metric":"microsoft.network/azurefirewalls--ApplicationRuleHit","aggregation":1,"splitBy":null}],"title":"Application Rule Hitcount (SUM)","gridSettings":{"rowLimit":10000}},"customWidth":"50","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFOverview"},"name":"metric - 25 - Copy - Copy - Copy"},{"type":1,"content":{"json":"---\\r\\n# Azure Firewall - Application rule log statitics"},"conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFAppRule"},"name":"text - 14"},{"type":3,"content":{"version":"KqlItem/1.0","query":"let ActivityData = AzureDiagnostics\\r\\n| where Category == \\"AzureFirewallApplicationRule\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" \\" TempDetails\\r\\n| parse TempDetails with \\"was \\" Action1 \\". Reason: \\" Rule1\\r\\n| parse TempDetails with \\"to \\" FQDN \\":\\" TargetPortInt:int \\". Action: \\" Action2 \\".\\" *\\r\\n| parse TempDetails with * \\". Rule Collection: \\" RuleCollection2a \\". Rule:\\" Rule2a\\r\\n| parse TempDetails with * \\"Deny.\\" RuleCollection2b \\". Proceeding with\\" Rule2b\\r\\n| extend SourcePort = tostring(SourcePortInt)\\r\\n| extend TargetPort = tostring(TargetPortInt)\\r\\n| extend Action1 = case(Action1 == \\"denied\\",\\"Deny\\",\\"Unknown Action\\")\\r\\n| extend Action = case(Action2 == \\"\\",Action1,Action2),Rule = case(Rule2a == \\"\\", case(Rule1 == \\"\\",case(Rule2b == \\"\\",\\"N/A\\", Rule2b),Rule1),Rule2a),  RuleCollection = case(RuleCollection2b == \\"\\",case(RuleCollection2a == \\"\\",\\"No rule matched\\",RuleCollection2a), RuleCollection2b),FQDN = case(FQDN == \\"\\", \\"N/A\\", FQDN),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort)\\r\\n| where Action == \\"Deny\\";\\r\\nActivityData\\r\\n| summarize Amount=count() by SourceIP\\r\\n| join kind = inner\\r\\n(\\r\\n    ActivityData\\r\\n    | make-series Trend = count() default = 0 on bin(TimeGenerated, 1d) from {TimeRange:start} to {TimeRange:end} step {TimeRange:grain} by SourceIP) on SourceIP\\r\\n    | project-away SourceIP1, TimeGenerated\\r\\n    | top 10 by Amount\\r\\n    | sort by Amount","size":1,"title":"Unique Source IP addresses, filterable by SelectedSourceIP","noDataMessage":"There are no Application Rule logs within the selected workspaces. If you believe the selection is correct, confirm Application Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","exportFieldName":"SourceIP","exportParameterName":"SelectedSourceIP","exportDefaultValue":"*","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"tiles","tileSettings":{"titleContent":{"columnMatch":"Amount","formatter":12,"formatOptions":{"showIcon":true}},"subtitleContent":{"columnMatch":"SourceIP","formatter":1,"formatOptions":{"showIcon":true}},"secondaryContent":{"columnMatch":"Trend","formatter":9,"formatOptions":{"showIcon":true}},"showBorder":false}},"customWidth":"50","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFAppRule"},"name":"query - 4"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallApplicationRule\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" \\" TempDetails \\r\\n| parse TempDetails with \\"was \\" Action1 \\". Reason: \\" Rule1 \\r\\n| parse TempDetails with \\"to \\" FQDN \\":\\" TargetPortInt:int \\". Action: \\" Action2 \\".\\" *\\r\\n| parse TempDetails with * \\". Rule Collection: \\" RuleCollection2a \\". Rule:\\" Rule2a \\r\\n| parse TempDetails with * \\"Deny.\\" RuleCollection2b \\". Proceeding with\\" Rule2b \\r\\n| extend SourcePort = tostring(SourcePortInt) \\r\\n| where \'{SelectedSourceIP}\' == SourceIP or \'{SelectedSourceIP}\' == \\"*\\" \\r\\n| extend TargetPort = tostring(TargetPortInt) \\r\\n| extend Action1 = case(Action1 == \\"denied\\",\\"Deny\\",\\"Unknown Action\\") \\r\\n| extend Action = case(Action2 == \\"\\",Action1,Action2),Rule = case(Rule2a == \\"\\", case(Rule1 == \\"\\",case(Rule2b == \\"\\",\\" default action\\", Rule2b),Rule1),Rule2a),  RuleCollection = case(RuleCollection2b == \\"\\",case(RuleCollection2a == \\"\\",\\" No rule matched\\",RuleCollection2a), RuleCollection2b),FQDN = case(FQDN == \\"\\", \\" default action\\", FQDN),TargetPort = case(TargetPort == \\"\\", \\" default action\\", TargetPort)\\r\\n| summarize Count = count(), last_log = datetime_diff(\\"second\\",now(), max(TimeGenerated)) by RuleCollection, Rule\\r\\n\\r\\n\\r\\n","size":1,"title":"Application Rule Usage","noDataMessage":"There are no Application Rule logs within the selected workspaces. If you believe the selection is correct, confirm Application Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","gridSettings":{"formatters":[{"columnMatch":"Count","formatter":8,"formatOptions":{"palette":"whiteBlack"},"numberFormat":{"unit":17,"options":{"style":"decimal","useGrouping":false,"maximumSignificantDigits":4}}},{"columnMatch":"last_log","formatter":8,"formatOptions":{"palette":"greenRed"},"numberFormat":{"unit":24,"options":{"style":"decimal","useGrouping":false}}}]}},"customWidth":"50","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFAppRule"},"name":"query - 36"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics | where Category == \\"AzureFirewallApplicationRule\\" \\r\\n| where Resource in (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" \\" TempDetails | parse TempDetails with \\"was \\" Action1 \\". Reason: \\" Rule1 | parse TempDetails with \\"to \\" FQDN \\":\\" TargetPortInt:int \\". Action: \\" Action2 \\".\\" * | parse TempDetails with * \\". Rule Collection: \\" RuleCollection2a \\". Rule:\\" Rule2a | parse TempDetails with * \\"Deny.\\" RuleCollection2b \\". Proceeding with\\" Rule2b | extend SourcePort = tostring(SourcePortInt) | extend TargetPort = tostring(TargetPortInt) | extend Action1 = case(Action1 == \\"denied\\",\\"Deny\\",\\"Unknown Action\\") | extend Action = case(Action2 == \\"\\",Action1,Action2),Rule = case(Rule2a == \\"\\", case(Rule1 == \\"\\",case(Rule2b == \\"\\",\\"N/A\\", Rule2b),Rule1),Rule2a),  RuleCollection = case(RuleCollection2b == \\"\\",case(RuleCollection2a == \\"\\",\\"No rule matched\\",RuleCollection2a), RuleCollection2b),FQDN = case(FQDN == \\"\\", \\"N/A\\", FQDN),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort)| where Action == \\"Deny\\"\\r\\n| where \'{SelectedSourceIP}\' == SourceIP or \'{SelectedSourceIP}\' == \\"*\\"  \\r\\n| summarize count() by FQDN, bin(TimeGenerated,{TimeRange:grain})","size":0,"title":"Denied FDQN\'s over time","noDataMessage":"There are no Application Rule logs within the selected workspaces. If you believe the selection is correct, confirm Application Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"timechart","tileSettings":{"showBorder":false}},"customWidth":"50","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFAppRule"},"name":"query - 3"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallApplicationRule\\"\\r\\n| where Resource in (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" \\" TempDetails \\r\\n| parse TempDetails with \\"was \\" Action1 \\". Reason: \\" Rule1 \\r\\n| parse TempDetails with \\"to \\" FQDN \\":\\" TargetPortInt:int \\". Action: \\" Action2 \\".\\" * \\r\\n| parse TempDetails with * \\". Rule Collection: \\" RuleCollection2a \\". Rule:\\" Rule2a \\r\\n| parse TempDetails with * \\"Deny.\\" RuleCollection2b \\". Proceeding with\\" Rule2b \\r\\n| extend SourcePort = tostring(SourcePortInt) \\r\\n| extend TargetPort = tostring(TargetPortInt) \\r\\n| extend Action1 = case(Action1 == \\"denied\\",\\"Deny\\",\\"Unknown Action\\") \\r\\n| extend Action = case(Action2 == \\"\\",Action1,Action2),Rule = case(Rule2a == \\"\\", case(Rule1 == \\"\\",case(Rule2b == \\"\\",\\"N/A\\", Rule2b),Rule1),Rule2a),  RuleCollection = case(RuleCollection2b == \\"\\",case(RuleCollection2a == \\"\\",\\"No rule matched\\",RuleCollection2a), RuleCollection2b),FQDN = case(FQDN == \\"\\", \\"N/A\\", FQDN),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort)\\r\\n| where Action == \\"Deny\\"\\r\\n| where \'{SelectedSourceIP}\' == SourceIP or \'{SelectedSourceIP}\' == \\"*\\"  \\r\\n| summarize count() by FQDN\\r\\n| sort by count_ desc\\r\\n","size":0,"showAnalytics":true,"title":"Denied FDQN\'s by count","noDataMessage":"There are no Application Rule logs within the selected workspaces. If you believe the selection is correct, confirm Application Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","showExportToExcel":true,"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"table","gridSettings":{"formatters":[{"columnMatch":"count_","formatter":8,"formatOptions":{"palette":"whiteBlack"},"numberFormat":{"unit":17,"options":{"style":"decimal","useGrouping":false,"maximumSignificantDigits":4}}}]}},"customWidth":"50","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFAppRule"},"name":"query - 7"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallApplicationRule\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" \\" TempDetails \\r\\n| parse TempDetails with \\"was \\" Action1 \\". Reason: \\" Rule1 \\r\\n| parse TempDetails with \\"to \\" FQDN \\":\\" TargetPortInt:int \\". Action: \\" Action2 \\".\\" * \\r\\n| parse TempDetails with * \\". Rule Collection: \\" RuleCollection2a \\". Rule:\\" Rule2a \\r\\n| parse TempDetails with * \\"Deny.\\" RuleCollection2b \\". Proceeding with\\" Rule2b \\r\\n| extend SourcePort = tostring(SourcePortInt)\\r\\n| where \'{SelectedSourceIP}\' == SourceIP or \'{SelectedSourceIP}\' == \\"*\\"   \\r\\n| extend TargetPort = tostring(TargetPortInt)\\r\\n| extend Action1 = case(Action1 == \\"denied\\",\\"Deny\\",\\"Unknown Action\\") \\r\\n| extend Action = case(Action2 == \\"\\",Action1,Action2),Rule = case(Rule2a == \\"\\", case(Rule1 == \\"\\",case(Rule2b == \\"\\",\\"N/A\\", Rule2b),Rule1),Rule2a),  RuleCollection = case(RuleCollection2b == \\"\\",case(RuleCollection2a == \\"\\",\\"No rule matched\\",RuleCollection2a), RuleCollection2b),FQDN = case(FQDN == \\"\\", \\"N/A\\", FQDN),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort) \\r\\n| where Action == \\"Allow\\"\\r\\n| summarize count() by FQDN, bin(TimeGenerated,{TimeRange:grain})\\r\\n","size":0,"title":"Allowed FDQN\'s over time","noDataMessage":"There are no Application Rule logs within the selected workspaces. If you believe the selection is correct, confirm Application Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"timechart"},"customWidth":"50","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFAppRule"},"name":"query - 5"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallApplicationRule\\" \\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" \\" TempDetails | parse TempDetails with \\"was \\" Action1 \\". Reason: \\" Rule1 | parse TempDetails with \\"to \\" FQDN \\":\\" TargetPortInt:int \\". Action: \\" Action2 \\".\\" * | parse TempDetails with * \\". Rule Collection: \\" RuleCollection2a \\". Rule:\\" Rule2a | parse TempDetails with * \\"Deny.\\" RuleCollection2b \\". Proceeding with\\" Rule2b | extend SourcePort = tostring(SourcePortInt) | extend TargetPort = tostring(TargetPortInt) | extend Action1 = case(Action1 == \\"denied\\",\\"Deny\\",\\"Unknown Action\\") | extend Action = case(Action2 == \\"\\",Action1,Action2),Rule = case(Rule2a == \\"\\", case(Rule1 == \\"\\",case(Rule2b == \\"\\",\\"N/A\\", Rule2b),Rule1),Rule2a),  RuleCollection = case(RuleCollection2b == \\"\\",case(RuleCollection2a == \\"\\",\\"No rule matched\\",RuleCollection2a), RuleCollection2b),FQDN = case(FQDN == \\"\\", \\"N/A\\", FQDN),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort) | where Action == \\"Allow\\"\\r\\n| where \'{SelectedSourceIP}\' == SourceIP or \'{SelectedSourceIP}\' == \\"*\\"   \\r\\n| summarize count() by FQDN\\r\\n| sort by count_ desc","size":0,"showAnalytics":true,"title":"Allowed FDQN\'s by count","noDataMessage":"There are no Application Rule logs within the selected workspaces. If you believe the selection is correct, confirm Application Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","showExportToExcel":true,"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"table","gridSettings":{"formatters":[{"columnMatch":"count_","formatter":8,"formatOptions":{"palette":"whiteBlack"},"numberFormat":{"unit":17,"options":{"style":"decimal","useGrouping":false,"maximumSignificantDigits":4}}}]},"sortBy":[]},"customWidth":"50","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFAppRule"},"name":"query - 2"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallApplicationRule\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" \\" TempDetails \\r\\n| parse TempDetails with \\"was \\" Action1 \\". Reason: \\" Rule1 \\r\\n| parse TempDetails with \\"to \\" FQDN \\":\\" TargetPortInt:int \\". Action: \\" Action2 \\".\\" * \\r\\n| parse TempDetails with * \\". Rule Collection: \\" RuleCollection2a \\". Rule:\\" Rule2a \\r\\n| parse TempDetails with * \\"Deny.\\" RuleCollection2b \\". Proceeding with\\" Rule2b\\r\\n| parse msg_s with Protocol_s \'request from \' SourceHost_s \':\' SourcePort_s \'to \' DestinationHost_s \':\' DestinationPort_s \'was\' Action_s \'to\' DNATDestination\\r\\n| parse msg_s with Protocol_S \'request from \' SourceHost_S \':\' SourcePort_S \'to \' DestinationHost_S \':\' DestinationPort_S \'. Action:\' Action_S\\r\\n| extend Protocol = strcat(Protocol_s, Protocol_S), SourceHost = strcat(SourceHost_s, SourceHost_S),SourcePort = strcat(SourcePort_s, SourcePort_S), DestinationHost = strcat(DestinationHost_s, DestinationHost_S), DestinationPort = strcat(DestinationPort_s, DestinationPort_S), Action = strcat(Action_s, Action_S)\\r\\n| extend SourcePort = tostring(SourcePortInt) \\r\\n| extend TargetPort = tostring(TargetPortInt)\\r\\n| extend Action1 = case(Action1 == \\"denied\\",\\"Deny\\",\\"Unknown Action\\") \\r\\n| extend Action = case(Action2 == \\"\\",Action1,Action2),Rule = case(Rule2a == \\"\\", case(Rule1 == \\"\\",case(Rule2b == \\"\\",\\" default action\\", Rule2b),Rule1),Rule2a),  RuleCollection = case(RuleCollection2b == \\"\\",case(RuleCollection2a == \\"\\",\\"No rule matched\\",RuleCollection2a), RuleCollection2b),FQDN = case(FQDN == \\"\\", \\" default action\\", FQDN),TargetPort = case(TargetPort == \\"\\", \\" default action\\", TargetPort)\\r\\n| where \'{SelectedSourceIP}\' == SourceIP or \'{SelectedSourceIP}\' == \\"*\\"  \\r\\n| summarize by TimeGenerated, FQDN, Protocol, Action, SourceIP, SourcePort, TargetPort, SourceHost , DestinationPort , ResourceId , ResourceGroup , RuleCollection, Rule, SubscriptionId\\r\\n","size":0,"showAnalytics":true,"title":"All IP addresses events","noDataMessage":"There are no Application Rule logs within the selected workspaces. If you believe the selection is correct, confirm Application Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","showExportToExcel":true,"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"gridSettings":{"filter":true}},"conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFAppRule"},"name":"query - 9"},{"type":1,"content":{"json":"---\\r\\n# Azure Firewall - Network rule log statistics"},"conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFNetRule"},"name":"text - 14"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallNetworkRule\\"\\r\\n| where OperationName <> \\"AzureFirewallThreatIntelLog\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" to \\" TargetIP \\":\\" TargetPortInt:int * \\r\\n| parse msg_s with * \\". Action: \\" Action1a \\r\\n| parse msg_s with * \\"was \\" Action1b \\" to \\" NatDestination \\r\\n| parse msg_s with Protocol2 \\" request from \\" SourceIP2 \\" to \\" TargetIP2 \\". Action:\\" Action2 \\r\\n| extend SourcePort = tostring(SourcePortInt),TargetPort = tostring(TargetPortInt) \\r\\n| extend Action = case(Action1a == \\"\\", case(Action1b == \\"\\",Action2,Action1b), Action1a),Protocol = case(Protocol == \\"\\", Protocol2, Protocol),SourceIP = case(SourceIP == \\"\\", SourceIP2, SourceIP),TargetIP = case(TargetIP == \\"\\", TargetIP2, TargetIP),SourcePort = case(SourcePort == \\"\\", \\"N/A\\", SourcePort),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort),NatDestination = case(NatDestination == \\"\\", \\"N/A\\", NatDestination)  \\r\\n| summarize count() by Action","size":3,"title":"Rule actions, filterable by RuleAction","noDataMessage":"There are no Network Rule logs within the selected workspaces. If you believe the selection is correct, confirm Network Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","exportFieldName":"series","exportParameterName":"RuleAction","exportDefaultValue":"*","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"piechart"},"customWidth":"33","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFNetRule"},"name":"query - 7"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallNetworkRule\\"\\r\\n| where OperationName <> \\"AzureFirewallThreatIntelLog\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" to \\" TargetIP \\":\\" TargetPortInt:int * \\r\\n| parse msg_s with * \\". Action: \\" Action1a \\r\\n| parse msg_s with * \\"was \\" Action1b \\" to \\" NatDestination \\r\\n| parse msg_s with Protocol2 \\" request from \\" SourceIP2 \\" to \\" TargetIP2 \\". Action: \\" Action2 \\r\\n| extend SourcePort = tostring(SourcePortInt),TargetPort = tostring(TargetPortInt) \\r\\n| extend Action = case(Action1a == \\"\\", case(Action1b == \\"\\",Action2,Action1b), Action1a),Protocol = case(Protocol == \\"\\", Protocol2, Protocol),SourceIP = case(SourceIP == \\"\\", SourceIP2, SourceIP),TargetIP = case(TargetIP == \\"\\", TargetIP2, TargetIP),SourcePort = case(SourcePort == \\"\\", \\"N/A\\", SourcePort),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort), NatDestination = case(NatDestination == \\"\\", \\"N/A\\", NatDestination)  \\r\\n| summarize Count=count() by TargetPort","size":3,"title":"Target ports, filterable by TargetPort","noDataMessage":"There are no Network Rule logs within the selected workspaces. If you believe the selection is correct, confirm Network Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","exportFieldName":"series","exportParameterName":"TargetPort","exportDefaultValue":"*","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"piechart"},"customWidth":"33","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFNetRule"},"name":"query - 10"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallNetworkRule\\"\\r\\n| where OperationName <> \\"AzureFirewallThreatIntelLog\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" to \\" TargetIP \\":\\" TargetPortInt:int * \\r\\n| parse msg_s with * \\". Action: \\" Action1a \\r\\n| parse msg_s with * \\"was \\" Action1b \\" to \\" NatDestination\\r\\n| parse msg_s with Protocol2 \\" request from \\" SourceIP2 \\" to \\" TargetIP2 \\". Action:\\" Action2 \\r\\n| extend SourcePort = tostring(SourcePortInt),TargetPort = tostring(TargetPortInt) \\r\\n| extend Action = case(Action1a == \\"\\", \\r\\ncase(Action1b == \\"\\",Action2,Action1b), Action1a),\\r\\nProtocol = case(Protocol == \\"\\", Protocol2, Protocol),\\r\\nSourceIP = case(SourceIP == \\"\\", SourceIP2, SourceIP),\\r\\nTargetIP = case(TargetIP == \\"\\", TargetIP2, TargetIP),\\r\\nSourcePort = case(SourcePort == \\"\\", \\"N/A\\", SourcePort),\\r\\nTargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort),\\r\\nNatDestination = case(NatDestination == \\"\\", \\"N/A\\", NatDestination)  \\r\\n| where Action == \\"DNAT\'ed\\"\\r\\n| summarize Amount=count() by NatDestination\\r\\n","size":3,"title":"DNAT actions, filterable by NatDestination","noDataMessage":"There are no Network Rule logs within the selected workspaces. If you believe the selection is correct, confirm Network Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","exportFieldName":"series","exportParameterName":"NatDestination","exportDefaultValue":"*","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"piechart"},"customWidth":"33","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFNetRule"},"name":"query - 12"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallNetworkRule\\"\\r\\n| where OperationName <> \\"AzureFirewallThreatIntelLog\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" to \\" TargetIP \\":\\" TargetPortInt:int * \\r\\n| parse msg_s with * \\". Action: \\" Action1a \\r\\n| parse msg_s with * \\"was \\" Action1b \\" to \\" NatDestination\\r\\n| parse msg_s with Protocol2 \\" request from \\" SourceIP2 \\" to \\" TargetIP2 \\". Action:\\" Action2 \\r\\n| extend SourcePort = tostring(SourcePortInt),TargetPort = tostring(TargetPortInt) \\r\\n| extend Action = case(Action1a == \\"\\", \\r\\ncase(Action1b == \\"\\",Action2,Action1b), Action1a),\\r\\nProtocol = case(Protocol == \\"\\", Protocol2, Protocol),\\r\\nSourceIP = case(SourceIP == \\"\\", SourceIP2, SourceIP),\\r\\nTargetIP = case(TargetIP == \\"\\", TargetIP2, TargetIP),\\r\\nSourcePort = case(SourcePort == \\"\\", \\"N/A\\", SourcePort),\\r\\nTargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort),\\r\\nNatDestination = case(NatDestination == \\"\\", \\"N/A\\", NatDestination)\\r\\n//| extend Action = iif(Action contains \\"DNAT\'ed\\", Action=\\"Nah\\", Action)\\r\\n| where \'{TargetPort}\' == TargetPort or \'{TargetPort}\' == \\"*\\"\\r\\n| where \\"{RuleAction}\\" == Action or \\"{RuleAction}\\" == \\"*\\"\\r\\n| where \'{NatDestination}\' == NatDestination or \'{NatDestination}\' == \\"*\\" \\r\\n| summarize amount = count() by Action , SourceIP\\r\\n| sort by amount desc","size":0,"title":"Rule actions, by IP addresses","noDataMessage":"There are no Network Rule logs within the selected workspaces. If you believe the selection is correct, confirm Network Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"table","gridSettings":{"formatters":[{"columnMatch":"Action","formatter":5},{"columnMatch":"amount","formatter":3,"formatOptions":{"palette":"whiteBlack"},"numberFormat":{"unit":17,"options":{"style":"decimal","maximumSignificantDigits":4}}},{"columnMatch":"eventCount","formatter":3,"formatOptions":{"min":0,"palette":"blue"}}],"rowLimit":10000,"filter":true,"hierarchySettings":{"treeType":1,"groupBy":["Action"],"expandTopLevel":false,"finalBy":"Action"}}},"customWidth":"33","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFNetRule"},"name":"query - 8"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallNetworkRule\\"\\r\\n| where OperationName <> \\"AzureFirewallThreatIntelLog\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" to \\" TargetIP \\":\\" TargetPortInt:int * \\r\\n| parse msg_s with * \\". Action: \\" Action1a \\r\\n| parse msg_s with * \\"was \\" Action1b \\" to \\" NatDestination \\r\\n| parse msg_s with Protocol2 \\" request from \\" SourceIP2 \\" to \\" TargetIP2 \\". Action: \\" Action2 \\r\\n| extend SourcePort = tostring(SourcePortInt),TargetPort = tostring(TargetPortInt) \\r\\n| extend Action = case(Action1a == \\"\\", \\r\\ncase(Action1b == \\"\\",Action2,Action1b), Action1a),Protocol = case(Protocol == \\"\\", \\r\\nProtocol2, Protocol),SourceIP = case(SourceIP == \\"\\", SourceIP2, SourceIP),\\r\\nTargetIP = case(TargetIP == \\"\\", TargetIP2, TargetIP),\\r\\nSourcePort = case(SourcePort == \\"\\", \\"N/A\\", SourcePort),\\r\\nTargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort), \\r\\nNatDestination = case(NatDestination == \\"\\", \\r\\n\\"N/A\\", NatDestination)\\r\\n| where \'{TargetPort}\' == TargetPort or \'{TargetPort}\' == \\"*\\"\\r\\n| where \\"{RuleAction}\\" == Action or \\"{RuleAction}\\" == \\"*\\"\\r\\n| where \'{NatDestination}\' == NatDestination or \'{NatDestination}\' == \\"*\\"   \\r\\n| summarize AMOUNT=count() by TargetPort, SourceIP\\r\\n| sort by AMOUNT desc","size":0,"title":"Target ports, by Source IP","noDataMessage":"There are no Network Rule logs within the selected workspaces. If you believe the selection is correct, confirm Network Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"TargetPort","formatter":5},{"columnMatch":"AMOUNT","formatter":3,"formatOptions":{"palette":"whiteBlack"},"numberFormat":{"unit":17,"options":{"style":"decimal","useGrouping":false,"maximumSignificantDigits":4}}}],"rowLimit":10000,"filter":true,"hierarchySettings":{"treeType":1,"groupBy":["TargetPort"],"finalBy":"TargetPort"}}},"customWidth":"33","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFNetRule"},"name":"query - 11"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallNetworkRule\\"\\r\\n| where OperationName <> \\"AzureFirewallThreatIntelLog\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" to \\" TargetIP \\":\\" TargetPortInt:int * \\r\\n| parse msg_s with * \\". Action: \\" Action1a \\r\\n| parse msg_s with * \\"was \\" Action1b \\" to \\" NatDestination\\r\\n| parse msg_s with Protocol2 \\" request from \\" SourceIP2 \\" to \\" TargetIP2 \\". Action:\\" Action2 \\r\\n| extend SourcePort = tostring(SourcePortInt),TargetPort = tostring(TargetPortInt) \\r\\n| extend Action = case(Action1a == \\"\\", \\r\\ncase(Action1b == \\"\\",Action2,Action1b), Action1a),\\r\\nProtocol = case(Protocol == \\"\\", Protocol2, Protocol),\\r\\nSourceIP = case(SourceIP == \\"\\", SourceIP2, SourceIP),\\r\\nTargetIP = case(TargetIP == \\"\\", TargetIP2, TargetIP),\\r\\nSourcePort = case(SourcePort == \\"\\", \\"N/A\\", SourcePort),\\r\\nTargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort),\\r\\nNatDestination = case(NatDestination == \\"\\", \\"N/A\\", NatDestination)  \\r\\n| where Action == \\"DNAT\'ed\\"\\r\\n| where \'{TargetPort}\' == TargetPort or \'{TargetPort}\' == \\"*\\"\\r\\n| where \\"{RuleAction}\\" == Action or \\"{RuleAction}\\" == \\"*\\"\\r\\n| where \'{NatDestination}\' == NatDestination or \'{NatDestination}\' == \\"*\\"\\r\\n| summarize Amount=count() by NatDestination, TimeGenerated\\r\\n","size":0,"title":"DNAT\'ed over time","noDataMessage":"There are no Network Rule logs within the selected workspaces. If you believe the selection is correct, confirm Network Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"timechart"},"customWidth":"33","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFNetRule"},"name":"query - 13"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"AzureFirewallNetworkRule\\"\\r\\n| where OperationName <> \\"AzureFirewallThreatIntelLog\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from\\" SourceIP \\":\\" SourcePortInt:int \\" to\\" TargetIP \\":\\" TargetPortInt:int *\\r\\n| parse msg_s with * \\". Action: \\" Action1a\\r\\n| parse msg_s with * \\" was \\" Action1b \\" to \\" NatDestination\\r\\n| parse msg_s with Protocol2 \\" request from\\" SourceIP2 \\" to\\" TargetIP2 \\". Action:\\" Action2\\r\\n| extend SourcePort = tostring(SourcePortInt),TargetPort = tostring(TargetPortInt)\\r\\n| extend Action = case(Action1a == \\"\\", case(Action1b == \\"\\",Action2,Action1b), Action1a),Protocol = case(Protocol == \\"\\", Protocol2, Protocol),SourceIP = case(SourceIP == \\"\\", SourceIP2, SourceIP),TargetIP = case(TargetIP == \\"\\", TargetIP2, TargetIP),SourcePort = case(SourcePort == \\"\\", \\"N/A\\", SourcePort),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort),NatDestination = case(NatDestination == \\"\\", \\"N/A\\", NatDestination)\\r\\n| where \'{TargetPort}\' == TargetPort or \'{TargetPort}\' == \\"*\\"\\r\\n| where \\"{RuleAction}\\" == Action or \\"{RuleAction}\\" == \\"*\\"\\r\\n| where \'{NatDestination}\' == NatDestination or \'{NatDestination}\' == \\"*\\"\\r\\n| summarize count() by Action, bin(TimeGenerated, {TimeRange:grain})\\r\\n","size":0,"title":"Actions, by time","noDataMessage":"There are no Network Rule logs within the selected workspaces. If you believe the selection is correct, confirm Network Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","timeBrushParameterName":"ActionsByTimeBrush","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"timechart"},"conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFNetRule"},"name":"query - 15"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"AzureFirewallNetworkRule\\"\\r\\n| where OperationName <> \\"AzureFirewallThreatIntelLog\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from\\" SourceIP \\":\\" SourcePortInt:int \\" to\\" TargetIP \\":\\" TargetPortInt:int *\\r\\n| parse msg_s with * \\". Action: \\" Action1a\\r\\n| parse msg_s with * \\" was \\" Action1b \\" to \\" NatDestination\\r\\n| parse msg_s with Protocol2 \\" request from\\" SourceIP2 \\" to\\" TargetIP2 \\". Action:\\" Action2\\r\\n| parse msg_s with Protocol_s \'request from \' SourceHost_s \':\' SourcePort_s \'to \' DestinationHost_s \':\' DestinationPort_s \'was\' Action_s \'to\' DNATDestination\\r\\n| parse msg_s with Protocol_S \'request from \' SourceHost_S \':\' SourcePort_S \'to \' DestinationHost_S \':\' DestinationPort_S \'. Action:\' Action_S\\r\\n| extend Protocol = strcat(Protocol_s, Protocol_S), SourceHost = strcat(SourceHost_s, SourceHost_S),SourcePort = strcat(SourcePort_s, SourcePort_S), DestinationHost = strcat(DestinationHost_s, DestinationHost_S), DestinationPort = strcat(DestinationPort_s, DestinationPort_S), Action = strcat(Action_s, Action_S)\\r\\n| extend SourcePort = tostring(SourcePortInt),TargetPort = tostring(TargetPortInt)\\r\\n| extend Action = case(Action1a == \\"\\", case(Action1b == \\"\\",Action2,Action1b), Action1a),Protocol = case(Protocol == \\"\\", Protocol2, Protocol),SourceIP = case(SourceIP == \\"\\", SourceIP2, SourceIP),TargetIP = case(TargetIP == \\"\\", TargetIP2, TargetIP),SourcePort = case(SourcePort == \\"\\", \\"N/A\\", SourcePort),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort),NatDestination = case(NatDestination == \\"\\", \\"N/A\\", NatDestination)\\r\\n| where \'{TargetPort}\' == TargetPort or \'{TargetPort}\' == \\"*\\"\\r\\n| where \\"{RuleAction}\\" == Action or \\"{RuleAction}\\" == \\"*\\"\\r\\n| where \'{NatDestination}\' == NatDestination or \'{NatDestination}\' == \\"*\\"\\r\\n| summarize by TimeGenerated,Protocol, Action, SourcePort, TargetPort, SourceHost , DestinationHost , DestinationPort , NatDestination, ResourceId , ResourceGroup , SubscriptionId","size":0,"showAnalytics":true,"title":"All IP addresses events","noDataMessage":"There are no Network Rule logs within the selected workspaces. If you believe the selection is correct, confirm Network Rule logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":0},"timeContextFromParameter":"ActionsByTimeBrush","showExportToExcel":true,"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"gridSettings":{"filter":true}},"conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFNetRule"},"name":"query - 22"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"AzureFirewallDnsProxy\\"\\r\\n| parse msg_s with \\"DNS Request: \\" ClientIP \\":\\" ClientPort \\" - \\" QueryID \\" \\" Request_Type \\" \\" Request_Class \\" \\" Request_Name \\". \\" Request_Protocol \\" \\" Request_Size \\" \\" EDNSO_DO \\" \\" EDNS0_Buffersize \\" \\" Responce_Code \\" \\" Responce_Flags \\" \\" Responce_Size \\" \\" Response_Duration\\r\\n| project-away msg_s\\r\\n| summarize count() by Resource, bin(TimeGenerated,{TimeRange:grain})\\r\\n","size":0,"title":"DNSProxy Traffic by count per Firewall","noDataMessage":"There are no DNS Proxy logs within the selected workspaces. If you believe the selection is correct, confirm DNS Proxy logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","timeBrushParameterName":"DNSTimeBrush","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"linechart","gridSettings":{"formatters":[{"columnMatch":"count_","formatter":8,"formatOptions":{"palette":"whiteBlack"},"numberFormat":{"unit":17,"options":{"style":"decimal","useGrouping":false,"maximumSignificantDigits":4}}}]}},"conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFDNSProxy"},"name":"query - 30 - Copy - Copy"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"AzureFirewallDnsProxy\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with \\"DNS Request: \\" ClientIP \\":\\" ClientPort \\" - \\" QueryID \\" \\" Request_Type \\" \\" Request_Class \\" \\" Request_Name \\". \\" Request_Protocol \\" \\" Request_Size \\" \\" EDNSO_DO \\" \\" EDNS0_Buffersize \\" \\" Responce_Code \\" \\" Responce_Flags \\" \\" Responce_Size \\" \\" Response_Duration\\r\\n| project-away msg_s\\r\\n| summarize count() by Request_Name\\r\\n| sort by count_ desc","size":0,"title":"DNSProxy count by Request Name, filterable by Request_Name","noDataMessage":"There are no DNS Proxy logs within the selected workspaces. If you believe the selection is correct, confirm DNS Proxy logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":0},"timeContextFromParameter":"DNSTimeBrush","exportFieldName":"Request_Name","exportParameterName":"DNSRequestName","exportDefaultValue":"*","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"count_","formatter":8,"formatOptions":{"palette":"whiteBlack"},"numberFormat":{"unit":17,"options":{"style":"decimal","useGrouping":false,"maximumSignificantDigits":4}}}]}},"customWidth":"25","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFDNSProxy"},"name":"query - 30 - Copy"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"AzureFirewallDnsProxy\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with \\"DNS Request: \\" ClientIP \\":\\" ClientPort \\" - \\" QueryID \\" \\" Request_Type \\" \\" Request_Class \\" \\" Request_Name \\". \\" Request_Protocol \\" \\" Request_Size \\" \\" EDNSO_DO \\" \\" EDNS0_Buffersize \\" \\" Responce_Code \\" \\" Responce_Flags \\" \\" Responce_Size \\" \\" Response_Duration\\r\\n| project-away msg_s\\r\\n| where \'{DNSRequestName}\' == Request_Name or \'{DNSRequestName}\' == \\"*\\"\\r\\n| summarize count() by ClientIP\\r\\n| sort by count_ desc","size":0,"title":"DNSProxy Request count by ClientIP, filterable by ClientIP","noDataMessage":"There are no DNS Proxy logs within the selected workspaces. If you believe the selection is correct, confirm DNS Proxy logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":0},"timeContextFromParameter":"DNSTimeBrush","exportFieldName":"ClientIP","exportParameterName":"DNSClientIP","exportDefaultValue":"*","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"count_","formatter":8,"formatOptions":{"palette":"whiteBlack"},"numberFormat":{"unit":17,"options":{"style":"decimal","useGrouping":false,"maximumSignificantDigits":4}}}]}},"customWidth":"25","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFDNSProxy"},"name":"query - 30 - Copy"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"AzureFirewallDnsProxy\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with \\"DNS Request: \\" ClientIP \\":\\" ClientPort \\" - \\" QueryID \\" \\" Request_Type \\" \\" Request_Class \\" \\" Request_Name \\". \\" Request_Protocol \\" \\" Request_Size \\" \\" EDNSO_DO \\" \\" EDNS0_Buffersize \\" \\" Responce_Code \\" \\" Responce_Flags \\" \\" Responce_Size \\" \\" Response_Duration\\r\\n| project-away msg_s\\r\\n| where \'{DNSClientIP}\' == ClientIP or \'{DNSClientIP}\' == \\"*\\"\\r\\n| where \'{DNSRequestName}\' == Request_Name or \'{DNSRequestName}\' == \\"*\\"\\r\\n| summarize count() by ClientIP, bin(TimeGenerated, {TimeRange:grain})\\r\\n","size":0,"title":"DNS Proxy Request over time by ClientIP","noDataMessage":"There are no DNS Proxy logs within the selected workspaces. If you believe the selection is correct, confirm DNS Proxy logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":0},"timeContextFromParameter":"DNSTimeBrush","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"visualization":"linechart"},"customWidth":"50","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFDNSProxy"},"name":"query - 30 - Copy"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"AzureFirewallDnsProxy\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with \\"DNS Request: \\" ClientIP \\":\\" ClientPort \\" - \\" QueryID \\" \\" Request_Type \\" \\" Request_Class \\" \\" Request_Name \\". \\" Request_Protocol \\" \\" Request_Size \\" \\" EDNSO_DO \\" \\" EDNS0_Buffersize \\" \\" Responce_Code \\" \\" Responce_Flags \\" \\" Responce_Size \\" \\" Response_Duration\\r\\n| project-away msg_s\\r\\n| where \'{DNSClientIP}\' == ClientIP or \'{DNSClientIP}\' == \\"*\\"\\r\\n| where \'{DNSRequestName}\' == Request_Name or \'{DNSRequestName}\' == \\"*\\"\\r\\n| summarize by TimeGenerated, ResourceId, ClientIP, ClientPort, QueryID, Request_Type, Request_Class, Request_Name, Request_Protocol, Request_Size, EDNSO_DO, EDNS0_Buffersize, Responce_Code, Responce_Flags, Responce_Size, Response_Duration, SubscriptionId","size":0,"showAnalytics":true,"title":"DNS Proxy Information","noDataMessage":"There are no DNS Proxy logs within the selected workspaces. If you believe the selection is correct, confirm DNS Proxy logs are enabled for the Azure Firewall and feeding into this selected workspace. Reference Docs: https://docs.microsoft.com/en-us/azure/firewall/","noDataMessageStyle":2,"timeContext":{"durationMs":0},"timeContextFromParameter":"DNSTimeBrush","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"gridSettings":{"filter":true}},"conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFDNSProxy"},"name":"query - 30"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where Category == \\"AzureFirewallApplicationRule\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" \\" TempDetails \\r\\n| parse TempDetails with \\"was \\" Action1 \\". Reason: \\" Rule1 \\r\\n| parse TempDetails with \\"to \\" FQDN \\":\\" TargetPortInt:int \\". Action: \\" Action2 \\".\\" * \\r\\n| parse TempDetails with * \\". Rule Collection: \\" RuleCollection2a \\". Rule:\\" Rule2a \\r\\n| parse TempDetails with * \\"Deny.\\" RuleCollection2b \\". Proceeding with\\" Rule2b \\r\\n| extend SourcePort = tostring(SourcePortInt) \\r\\n| extend TargetPort = tostring(TargetPortInt) \\r\\n| extend Action1 = case(Action1 == \\"denied\\",\\"Deny\\",\\"Unknown Action\\") \\r\\n| extend Action = case(Action2 == \\"\\",Action1,Action2),Rule = case(Rule2a == \\"\\", case(Rule1 == \\"\\",case(Rule2b == \\"\\",\\"N/A\\", Rule2b),Rule1),Rule2a),  RuleCollection = case(RuleCollection2b == \\"\\",case(RuleCollection2a == \\"\\",\\"No rule matched\\",RuleCollection2a), RuleCollection2b),FQDN = case(FQDN == \\"\\", \\"N/A\\", FQDN),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort)\\r\\n| where Action == \\"Deny\\" or Action == \\"Allow\\"\\r\\n| summarize count() by FQDN, Action\\r\\n| sort by count_ desc","size":0,"title":"FQDN Traffic by Count, filterable by FQDN","timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","exportFieldName":"FQDN","exportParameterName":"FullName","exportDefaultValue":"*","showExportToExcel":true,"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"Action","formatter":5},{"columnMatch":"count_","formatter":8,"formatOptions":{"palette":"whiteBlack"},"numberFormat":{"unit":17,"options":{"style":"decimal","useGrouping":false,"minimumIntegerDigits":1,"maximumFractionDigits":1,"maximumSignificantDigits":4}}}],"rowLimit":10000,"filter":true,"hierarchySettings":{"treeType":1,"groupBy":["Action"],"expandTopLevel":true}}},"customWidth":"30","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFInvestigate"},"name":"query - 29 - Copy"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"AzureFirewallApplicationRule\\"\\r\\n| where msg_s contains \\"{FullName:label}\\" or \'{FullName}\' == \\"*\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" \\" TempDetails\\r\\n| parse TempDetails with \\"was \\" Action1 \\". Reason: \\" Rule1 \\r\\n| parse TempDetails with \\"to \\" FQDN \\":\\" TargetPortInt:int \\". Action: \\" Action2 \\".\\" * \\r\\n| parse TempDetails with * \\". Rule Collection: \\" RuleCollection2a \\". Rule:\\" Rule2a \\r\\n| parse TempDetails with * \\"Deny.\\" RuleCollection2b \\". Proceeding with\\" Rule2b \\r\\n| extend SourcePort = tostring(SourcePortInt) \\r\\n| extend TargetPort = tostring(TargetPortInt) \\r\\n| extend Action1 = case(Action1 == \\"denied\\",\\"Deny\\",\\"Unknown Action\\") \\r\\n| extend Action = case(Action2 == \\"\\",Action1,Action2),Rule = case(Rule2a == \\"\\", case(Rule1 == \\"\\",case(Rule2b == \\"\\",\\"N/A\\", Rule2b),Rule1),Rule2a),  RuleCollection = case(RuleCollection2b == \\"\\",case(RuleCollection2a == \\"\\",\\"No rule matched\\",RuleCollection2a), RuleCollection2b),FQDN = case(FQDN == \\"\\", \\"N/A\\", FQDN),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort)\\r\\n| where Action == \\"Deny\\" or Action == \\"Allow\\"\\r\\n| where SourceIP <> \\"\\"\\r\\n| summarize count() by SourceIP, SubscriptionId\\r\\n| sort by count_","size":0,"title":"SourceIP Address, filterable","timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","exportedParameters":[{"fieldName":"SourceIP","parameterName":"InvestigateIP","parameterType":1,"defaultValue":"privateIPAddress"},{"fieldName":"SourceIP","parameterName":"InvestigateIPWC","parameterType":1,"defaultValue":"*"},{"fieldName":"SubscriptionId","parameterName":"SelectedSubscriptionId","parameterType":1,"defaultValue":"-"}],"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"SubscriptionId","formatter":5},{"columnMatch":"count_","formatter":8,"formatOptions":{"palette":"whiteBlack"},"numberFormat":{"unit":17,"options":{"style":"decimal","useGrouping":false,"maximumSignificantDigits":4}}}],"filter":true},"tileSettings":{"titleContent":{"columnMatch":"SourceIP","formatter":4,"formatOptions":{"palette":"orange"},"numberFormat":{"unit":0,"options":{"style":"decimal","useGrouping":false}}},"showBorder":true,"size":"auto"}},"customWidth":"10","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFInvestigate"},"name":"query - 33"},{"type":3,"content":{"version":"KqlItem/1.0","query":"Resources\\r\\n| where type =~ \'microsoft.network/networkinterfaces\'\\r\\n| where properties contains \\"{InvestigateIP}\\"\\r\\n| where properties contains \'{SelectedSubscriptionId}\'\\r\\n| extend NSG = properties[\'networkSecurityGroup\'][\'id\']\\r\\n| parse NSG with \\"/subscriptions/\\" NetworkSecurityGroup_Sub \\"/resourceGroups/\\" NetworkSecurityGroup_rg \\"/providers/Microsoft.Network/networkSecurityGroups/\\" NetworkSecurityGroup_Name\\r\\n| project id, PrivateIPAddress = tostring(properties[\'ipConfigurations\'][0][\'properties\'][\'privateIPAddress\']),  PublicIPAddress = tostring(properties[\'ipConfigurations\'][0][\'properties\'][\'publicIPAddress\'][\'id\']), VirtualMachine = tostring(properties[\'virtualMachine\'][\'id\']), subnet = tostring(properties[\'ipConfigurations\'][0][\'properties\'][\'subnet\'][\'id\']), NetworkSecurityGroup = NetworkSecurityGroup_Name, properties, subscriptionId, tenantId","size":0,"title":"SourceIPAddress Resource Lookup","exportFieldName":"id","exportParameterName":"Testid","exportDefaultValue":"*","queryType":1,"resourceType":"microsoft.resourcegraph/resources","crossComponentResources":["value::selected"],"gridSettings":{"formatters":[{"columnMatch":"properties","formatter":5}],"filter":true},"tileSettings":{"titleContent":{"columnMatch":"SourceIP","formatter":4,"formatOptions":{"palette":"orange"},"numberFormat":{"unit":0,"options":{"style":"decimal","useGrouping":false}}},"showBorder":true,"size":"auto"}},"customWidth":"60","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFInvestigate"},"name":"query - 33 - Copy"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"AzureFirewallApplicationRule\\"\\r\\n| where msg_s contains \\"{FullName:label}\\" or \'{FullName}\' == \\"*\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from \\" SourceIP \\":\\" SourcePortInt:int \\" \\" TempDetails\\r\\n| where msg_s contains \\"{InvestigateIPWC:label}\\" or \'{InvestigateIPWC}\' == \\"*\\"\\r\\n| parse TempDetails with \\"was \\" Action1 \\". Reason: \\" Rule1 \\r\\n| parse TempDetails with \\"to \\" FQDN \\":\\" TargetPortInt:int \\". Action: \\" Action2 \\".\\" * \\r\\n| parse TempDetails with * \\". Rule Collection: \\" RuleCollection2a \\". Rule:\\" Rule2a \\r\\n| parse TempDetails with * \\"Deny.\\" RuleCollection2b \\". Proceeding with\\" Rule2b\\r\\n| parse msg_s with Protocol_s \'request from \' SourceHost_s \':\' SourcePort_s \'to \' DestinationHost_s \':\' DestinationPort_s \'was\' Action_s \'to\' DNATDestination\\r\\n| parse msg_s with Protocol_S \'request from \' SourceHost_S \':\' SourcePort_S \'to \' DestinationHost_S \':\' DestinationPort_S \'. Action:\' Action_S\\r\\n| extend Protocol = strcat(Protocol_s, Protocol_S), SourceHost = strcat(SourceHost_s, SourceHost_S),SourcePort = strcat(SourcePort_s, SourcePort_S), DestinationHost = strcat(DestinationHost_s, DestinationHost_S), DestinationPort = strcat(DestinationPort_s, DestinationPort_S), Action = strcat(Action_s, Action_S)\\r\\n| extend SourcePort = tostring(SourcePortInt) \\r\\n| extend TargetPort = tostring(TargetPortInt)\\r\\n| extend Action1 = case(Action1 == \\"denied\\",\\"Deny\\",\\"Unknown Action\\") \\r\\n| extend Action = case(Action2 == \\"\\",Action1,Action2),Rule = case(Rule2a == \\"\\", case(Rule1 == \\"\\",case(Rule2b == \\"\\",\\"N/A\\", Rule2b),Rule1),Rule2a),  RuleCollection = case(RuleCollection2b == \\"\\",case(RuleCollection2a == \\"\\",\\"No rule matched\\",RuleCollection2a), RuleCollection2b),FQDN = case(FQDN == \\"\\", \\"N/A\\", FQDN),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort)\\r\\n| summarize by TimeGenerated, FQDN, Protocol, Action, SourceIP, SourcePort, TargetPort, SourceHost , DestinationPort , ResourceId , ResourceGroup , RuleCollection, Rule, SubscriptionId\\r\\n\\r\\n","size":0,"title":"FQDN Lookup logs","timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"gridSettings":{"filter":true}},"customWidth":"100","conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFInvestigate"},"name":"query - 33"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"AzureFirewallNetworkRule\\"\\r\\n| where OperationName == \\"AzureFirewallThreatIntelLog\\"\\r\\n| where Resource in~ (split(\\"{Resource:label}\\", \\", \\"))\\r\\n| parse msg_s with Protocol \\" request from\\" SourceIP \\":\\" SourcePortInt:int \\" to\\" TargetIP \\":\\" TargetPortInt:int *\\r\\n| where msg_s contains \\"{InvestigateIPWC:label}\\" or \'{InvestigateIPWC}\' == \\"*\\"\\r\\n| parse msg_s with * \\". Action: \\" Action1a\\r\\n| parse msg_s with * \\" was \\" Action1b \\" to \\" NatDestination\\r\\n| parse msg_s with Protocol2 \\" request from\\" SourceIP2 \\" to\\" TargetIP2 \\". Action:\\" Action2\\r\\n| parse msg_s with Protocol_s \'request from \' SourceHost_s \':\' SourcePort_s \'to \' DestinationHost_s \':\' DestinationPort_s \'was\' Action_s \'to\' DNATDestination\\r\\n| parse msg_s with Protocol_S \'request from \' SourceHost_S \':\' SourcePort_S \'to \' DestinationHost_S \':\' DestinationPort_S \'. Action:\' Action_S\\r\\n| extend Protocol = strcat(Protocol_s, Protocol_S), SourceHost = strcat(SourceHost_s, SourceHost_S),SourcePort = strcat(SourcePort_s, SourcePort_S), DestinationHost = strcat(DestinationHost_s, DestinationHost_S), DestinationPort = strcat(DestinationPort_s, DestinationPort_S), Action = strcat(Action_s, Action_S)\\r\\n| extend SourcePort = tostring(SourcePortInt),TargetPort = tostring(TargetPortInt)\\r\\n| extend Action = case(Action1a == \\"\\", case(Action1b == \\"\\",Action2,Action1b), Action1a),Protocol = case(Protocol == \\"\\", Protocol2, Protocol),SourceIP = case(SourceIP == \\"\\", SourceIP2, SourceIP),TargetIP = case(TargetIP == \\"\\", TargetIP2, TargetIP),SourcePort = case(SourcePort == \\"\\", \\"N/A\\", SourcePort),TargetPort = case(TargetPort == \\"\\", \\"N/A\\", TargetPort),NatDestination = case(NatDestination == \\"\\", \\"N/A\\", NatDestination)\\r\\n| summarize by TimeGenerated,Protocol, Action, SourcePort, TargetPort, SourceHost , DestinationHost , DestinationPort , NatDestination, ResourceId , ResourceGroup , SubscriptionId","size":0,"title":"Azure Firewall Threat Intel","noDataMessage":"There is no Azure Firewall Threat Intel for your filtered results","timeContext":{"durationMs":2419200000},"timeContextFromParameter":"TimeRange","showExportToExcel":true,"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{Workspaces}"],"gridSettings":{"filter":true}},"conditionalVisibility":{"parameterName":"selectedTab","comparison":"isEqualTo","value":"AFInvestigate"},"name":"query - 29"}],"isLocked":false,"fallbackResourceIds":["/subscriptions/7b76bfbc-cb1e-4df1-b6e8-b826eef6c592/resourcegroups/soc/providers/microsoft.operationalinsights/workspaces/cybersecuritysoc"],"fromTemplateId":"sentinel-AzureFirewall"}'
  }
}
