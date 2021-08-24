
az login
az account set --subscription ce2c696e-9825-44f7-9a68-f34d153e64ba

1. create MHSM
az group create --name "ContosoResourceGroup" --location eastus2

az ad signed-in-user show --query objectId -o tsv
91448210-9c62-4ea4-b436-50134fd9c830

az keyvault create --hsm-name "az400popMHSM" --resource-group "ContosoResourceGroup" --location "East US 2" --administrators 91448210-9c62-4ea4-b436-50134fd9c830 --retention-days 28
    "hsmUri": "https://az400popmhsm.managedhsm.azure.net/"
    "softDeleteRetentionInDays": 28,
    "statusMessage": "The Managed HSM is provisioned and ready to use.",
    "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47"

2. activate MHSM
PS C:\Users\puliu\managedhsm> cat .\openssl.cnf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
C = US
ST = WA
L = Redmond
O = Contoso
OU = MHSM
CN = www.Contoso.com
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = www.Contoso.com
DNS.2 = Contoso.com
DNS.3 = www.Contoso.net
DNS.4 = Contoso.net

openssl req -newkey rsa:2048 -nodes -keyout cert_1.key -x509 -days 365 -out cert_1.cer -config openssl.cnf
openssl req -newkey rsa:2048 -nodes -keyout cert_2.key -x509 -days 365 -out cert_2.cer -config openssl.cnf
openssl req -newkey rsa:2048 -nodes -keyout cert_3.key -x509 -days 365 -out cert_3.cer -config openssl.cnf

az keyvault security-domain download --hsm-name az400popMHSM --sd-wrapping-keys ./cert_1.cer ./cert_2.cer ./cert_3.cer --sd-quorum 2 --security-domain-file az400popMHSM-SD.json

C:\Users\puliu\managedhsm>az keyvault security-domain download --hsm-name az400popMHSM --sd-wrapping-keys ./cert_1.cer ./cert_2.cer ./cert_3.cer --sd-quorum 2 --security-domain-file az400popMHSM-SD.json
{
  "status": "Success",
  "statusDetails": "The resource is active."
}


3. assing roles
--list all roles
az keyvault role definition list --hsm-name az400popmhsm
-- assign "Managed HSM Crypto User" role
az keyvault role assignment create --hsm-name az400popMHSM --role "Managed HSM Crypto User" --assignee puliu@microsoft.com  --scope /

--create and list the key

az keyvault key create --hsm-name az400popMHSM --name myrsakey --ops wrapKey unwrapKey --kty RSA-HSM --size 3072
az keyvault key create --hsm-name az400popMHSM --name myaeskey --ops encrypt decrypt  --tags --kty oct-HSM --size 256

az keyvault key list --id https://az400popmhsm.managedhsm.azure.net/

https://docs.microsoft.com/en-us/azure/key-vault/managed-hsm/key-management
az keyvault key import --hsm-name az400popMHSM --name mypemrsakey --pem-file mycert2.pem

PS C:\Users\puliu\managedhsm> az keyvault key import --hsm-name az400popMHSM --name mypemrsakey --pem-file mycert2.pem
az keyvault key show --id https://az400popmhsm.managedhsm.azure.net/keys/mypemrsakey

az keyvault key backup --hsm-name az400popMHSM --name mypemrsakey --file mypemrsakey.backup
az keyvault key delete --hsm-name az400popMHSM --name mypemrsakey
az keyvault key purge --hsm-name az400popMHSM --name mypemrsakey
az keyvault key restore --hsm-name az400popMHSM --file mypemrsakey.bakup


4. private link

C:\Users\puliu\mhsm>az group show --resource-group ContosoResourceGroup
{
  "id": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup",
  "location": "eastus2",
  "managedBy": null,
  "name": "ContosoResourceGroup",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}


https://docs.microsoft.com/en-us/azure/key-vault/managed-hsm/private-link

az login                                                                   # Login to Azure CLI
az account set --subscription {SUBSCRIPTION ID}                            # Select your Azure Subscription
az group create -n {RESOURCE GROUP} -l {REGION}                            # Create a new Resource Group
az provider register -n Microsoft.KeyVault                                 # Register KeyVault as a provider
az keyvault update-hsm --hsm-name {HSM NAME} -g {RG} --default-action deny # Turn on firewall
az network vnet create -g {RG} -n {vNet NAME} --location {REGION}           # Create a Virtual Network

    # Create a Subnet
az network vnet subnet create -g {RG} --vnet-name {vNet NAME} --name {subnet NAME} --address-prefixes {addressPrefix}

    # Disable Virtual Network Policies
az network vnet subnet update --name {subnet NAME} --resource-group {RG} --vnet-name {vNet NAME} --disable-private-endpoint-network-policies true

    # Create a Private DNS Zone
az network private-dns zone create --resource-group {RG} --name privatelink.managedhsm.azure.net

    # Link the Private DNS Zone to the Virtual Network
az network private-dns link vnet create --resource-group {RG} --virtual-network {vNet NAME} --zone-name privatelink.managedhsm.azure.net --name {dnsZoneLinkName} --registration-enabled true


C:\Users\puliu\managedhsm>az provider register -n Microsoft.KeyVault

C:\Users\puliu\managedhsm>az keyvault update-hsm --hsm-name az400popMHSM -g ContosoResourceGroup --default-action deny
{
  "id": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup/providers/Microsoft.KeyVault/managedHSMs/az400popMHSM",
  "location": "eastus2",
  "name": "az400popMHSM",
  "properties": {
    "createMode": null,
    "enablePurgeProtection": false,
    "enableSoftDelete": true,
    "hsmUri": "https://az400popmhsm.managedhsm.azure.net/",
    "initialAdminObjectIds": [
      "91448210-9c62-4ea4-b436-50134fd9c830"
    ],
    "networkAcls": {
      "bypass": "AzureServices",
      "defaultAction": "Deny",
      "ipRules": [],
      "virtualNetworkRules": []
    },
    "privateEndpointConnections": null,
    "provisioningState": "Succeeded",
    "publicNetworkAccess": "Enabled",
    "scheduledPurgeDate": null,
    "softDeleteRetentionInDays": 28,
    "statusMessage": "The Managed HSM is provisioned and ready to use.",
    "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47"
  },
  "resourceGroup": "ContosoResourceGroup",
  "sku": {
    "family": "B",
    "name": "Standard_B1"
  },
  "systemData": {
    "createdAt": "1970-01-19T20:36:37.310000+00:00",
    "createdBy": "puliu@microsoft.com",
    "createdByType": "User",
    "lastModifiedAt": "1970-01-19T20:42:17.934000+00:00",
    "lastModifiedBy": "puliu@microsoft.com",
    "lastModifiedByType": "User"
  },
  "tags": {},
  "type": "Microsoft.KeyVault/managedHSMs"
}

# Create a Virtual Network 10.0.0.0/16
az network vnet create -g ContosoResourceGroup -n vnetwest --location westus 
# Create a Subnet
az network vnet subnet create -g  ContosoResourceGroup --vnet-name vnetwest --name mainsubnet --address-prefixes 10.0.1.0/24

# Disable Virtual Network Policies
az network vnet subnet update --name mainsubnet --resource-group ContosoResourceGroup --vnet-name vnetwest --disable-private-endpoint-network-policies true

# Create a Private DNS Zone
az network private-dns zone create --resource-group ContosoResourceGroup --name privatelink.managedhsm.azure.net

# Link the Private DNS Zone to the Virtual Network
az network private-dns link vnet create --resource-group ContosoResourceGroup --virtual-network vnetwest --zone-name privatelink.managedhsm.azure.net --name managedhsmzone --registration-enabled true

az keyvault update-hsm --hsm-name az400popMHSM -g ContosoResourceGroup --default-action deny --bypass AzureServices
https://docs.microsoft.com/en-us/azure/key-vault/general/overview-vnet-service-endpoints#trusted-services
C:\Users\puliu\managedhsm>az keyvault update-hsm --hsm-name az400popMHSM -g ContosoResourceGroup --default-action deny --bypass AzureServices
{
  "id": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup/providers/Microsoft.KeyVault/managedHSMs/az400popMHSM",
  "location": "eastus2",
  "name": "az400popMHSM",
  "properties": {
    "createMode": null,
    "enablePurgeProtection": false,
    "enableSoftDelete": true,
    "hsmUri": "https://az400popmhsm.managedhsm.azure.net/",
    "initialAdminObjectIds": [
      "91448210-9c62-4ea4-b436-50134fd9c830"
    ],
    "networkAcls": {
      "bypass": "AzureServices",
      "defaultAction": "Deny",
      "ipRules": [],
      "virtualNetworkRules": []
    },
    "privateEndpointConnections": null,
    "provisioningState": "Succeeded",
    "publicNetworkAccess": "Enabled",
    "scheduledPurgeDate": null,
    "softDeleteRetentionInDays": 28,
    "statusMessage": "The Managed HSM is provisioned and ready to use.",
    "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47"
  },
  "resourceGroup": "ContosoResourceGroup",
  "sku": {
    "family": "B",
    "name": "Standard_B1"
  },
  "systemData": {
    "createdAt": "1970-01-19T20:36:37.310000+00:00",
    "createdBy": "puliu@microsoft.com",
    "createdByType": "User",
    "lastModifiedAt": "1970-01-19T20:42:19.021000+00:00",
    "lastModifiedBy": "puliu@microsoft.com",
    "lastModifiedByType": "User"
  },
  "tags": {},
  "type": "Microsoft.KeyVault/managedHSMs"
}


az network private-endpoint create --resource-group ContosoResourceGroup --vnet-name vnetwest --subnet mainsubnet --name privateendpointmainsubnet  --private-connection-resource-id "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup/providers/Microsoft.KeyVault/managedHSMs/az400popmhsm" --group-id managedhsm --connection-name privatelinkmain --location westus

C:\Users\puliu\managedhsm>az network private-endpoint create --resource-group ContosoResourceGroup --vnet-name vnetwest --subnet mainsubnet --name privateendpointmainsubnet  --private-connection-resource-id "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup/providers/Microsoft.KeyVault/managedHSMs/az400popmhsm" --group-id managedhsm --connection-name privatelinkmain --location westus
{
  "customDnsConfigs": [
    {
      "fqdn": "az400popmhsm.managedhsm.azure.net",
      "ipAddresses": [
        "10.0.1.4"
      ]
    }
  ],
  "etag": "W/\"e0efbd8c-cad5-4ab8-b149-602718e54b76\"",
  "extendedLocation": null,
  "id": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup/providers/Microsoft.Network/privateEndpoints/privateendpointmainsubnet",
  "location": "westus",
  "manualPrivateLinkServiceConnections": [],
  "name": "privateendpointmainsubnet",
  "networkInterfaces": [
    {
      "dnsSettings": null,
      "dscpConfiguration": null,
      "enableAcceleratedNetworking": null,
      "enableIpForwarding": null,
      "etag": null,
      "extendedLocation": null,
      "hostedWorkloads": null,
      "id": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup/providers/Microsoft.Network/networkInterfaces/privateendpointmainsubnet.nic.4bc5d177-13a2-43b6-ac56-2771b3356874",
      "ipConfigurations": null,
      "location": null,
      "macAddress": null,
      "migrationPhase": null,
      "name": null,
      "networkSecurityGroup": null,
      "nicType": null,
      "primary": null,
      "privateEndpoint": null,
      "privateLinkService": null,
      "provisioningState": null,
      "resourceGroup": "ContosoResourceGroup",
      "resourceGuid": null,
      "tags": null,
      "tapConfigurations": null,
      "type": null,
      "virtualMachine": null,
      "workloadType": null
    }
  ],
  "privateLinkServiceConnections": [
    {
      "etag": "W/\"e0efbd8c-cad5-4ab8-b149-602718e54b76\"",
      "groupIds": [
        "managedhsm"
      ],
      "id": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup/providers/Microsoft.Network/privateEndpoints/privateendpointmainsubnet/privateLinkServiceConnections/privatelinkmain",
      "name": "privatelinkmain",
      "privateLinkServiceConnectionState": {
        "actionsRequired": "None",
        "description": "",
        "status": "Approved"
      },
      "privateLinkServiceId": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup/providers/Microsoft.KeyVault/managedHSMs/az400popmhsm",
      "provisioningState": "Succeeded",
      "requestMessage": null,
      "resourceGroup": "ContosoResourceGroup",
      "type": "Microsoft.Network/privateEndpoints/privateLinkServiceConnections"
    }
  ],
  "provisioningState": "Succeeded",
  "resourceGroup": "ContosoResourceGroup",
  "subnet": {
    "addressPrefix": null,
    "addressPrefixes": null,
    "applicationGatewayIpConfigurations": null,
    "delegations": null,
    "etag": null,
    "id": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup/providers/Microsoft.Network/virtualNetworks/vnetwest/subnets/mainsubnet",
    "ipAllocations": null,
    "ipConfigurationProfiles": null,
    "ipConfigurations": null,
    "name": null,
    "natGateway": null,
    "networkSecurityGroup": null,
    "privateEndpointNetworkPolicies": null,
    "privateEndpoints": null,
    "privateLinkServiceNetworkPolicies": null,
    "provisioningState": null,
    "purpose": null,
    "resourceGroup": "ContosoResourceGroup",
    "resourceNavigationLinks": null,
    "routeTable": null,
    "serviceAssociationLinks": null,
    "serviceEndpointPolicies": null,
    "serviceEndpoints": null,
    "type": null
  },
  "tags": null,
  "type": "Microsoft.Network/privateEndpoints"
}
az network private-endpoint show --resource-group ContosoResourceGroup --name privateendpointmainsubnet

"networkInterfaces":
   id:
/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup/providers/Microsoft.Network/networkInterfaces/privateendpointmainsubnet.nic.4bc5d177-13a2-43b6-ac56-2771b3356874


az network nic show --ids /subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/ContosoResourceGroup/providers/Microsoft.Network/networkInterfaces/privateendpointmainsubnet.nic.4bc5d177-13a2-43b6-ac56-2771b3356874
      "name": "managedhsm-default.privateEndpoint",
      "primary": true,
      "privateIpAddress": "10.0.1.4",

az network private-dns record-set a add-record -g ContosoResourceGroup -z "privatelink.managedhsm.azure.net" -n az400popmhsm  -a 10.0.1.4
C:\Users\puliu\managedhsm>az network private-dns record-set a add-record -g ContosoResourceGroup -z "privatelink.managedhsm.azure.net" -n az400popmhsm  -a 10.0.1.4
{
  "aRecords": [
    {
      "ipv4Address": "10.0.1.4"
    }
  ],
  "etag": "42ebc862-4b67-49d4-9eee-6cdbaf69fc09",
  "fqdn": "az400popmhsm.privatelink.managedhsm.azure.net.",
  "id": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/contosoresourcegroup/providers/Microsoft.Network/privateDnsZones/privatelink.managedhsm.azure.net/A/az400popmhsm",
  "isAutoRegistered": false,
  "metadata": null,
  "name": "az400popmhsm",
  "resourceGroup": "contosoresourcegroup",
  "ttl": 3600,
  "type": "Microsoft.Network/privateDnsZones/A"
}

===========dev box===
C:\Users\puliu\managedhsm>nslookup az400popmhsm.managedhsm.azure.net
Server:  UnKnown
Address:  192.168.86.1

Non-authoritative answer:
Name:    eastus2.az400popmhsm.managedhsm.azure.net
Address:  52.247.20.192
Aliases:  az400popmhsm.managedhsm.azure.net
          az400popmhsm.privatelink.managedhsm.azure.net

=== azure vm ====
C:\Users\azureuser>nslookup az400popmhsm.privatelink.managedhsm.azure.net
Server:  UnKnown
Address:  168.63.129.16

Non-authoritative answer:
Name:    az400popmhsm.privatelink.managedhsm.azure.net
Address:  10.0.1.4

C:\Users\azureuser>nslookup az400popmhsm.managedhsm.azure.net
Server:  UnKnown
Address:  168.63.129.16

Non-authoritative answer:
Name:    az400popmhsm.privatelink.managedhsm.azure.net
Address:  10.0.1.4
Aliases:  az400popmhsm.managedhsm.azure.net

C:\Users\azureuser>hostname
testvmmhsm


az vm identity assign --name testvmmhsm --resource-group contosoresourcegroup
C:\Users\puliu\managedhsm>az vm identity assign --name testvmmhsm --resource-group contosoresourcegroup
{
  "systemAssignedIdentity": "30c7f262-1107-49d2-882a-abeb0050f854",
  "userAssignedIdentities": {}
}

az vm identity show --name "testvmmhsm" --resource-group "contosoresourcegroup" --query objectId -o tsv
C:\Users\puliu\managedhsm>az vm identity show --name "testvmmhsm" --resource-group "contosoresourcegroup"
{
  "principalId": "30c7f262-1107-49d2-882a-abeb0050f854",
  "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47",
  "type": "SystemAssigned",
  "userAssignedIdentities": null
}

C:\Users\puliu\managedhsm>az vm identity show --name "testvmmhsm" --resource-group "contosoresourcegroup" --query principalId -o tsv
30c7f262-1107-49d2-882a-abeb0050f854

# Grant the "Crypto User" role to the VM's managed identity. It allows to create and use keys. 
# However it cannot permanently delete (purge) keys
az keyvault role assignment create  --hsm-name az400popmhsm --assignee 30c7f262-1107-49d2-882a-abeb0050f854  --scope / --role "Managed HSM Crypto User"


C:\Users\puliu\managedhsm>az keyvault role assignment list --hsm-name az400popmhsm
[
  {
    "id": "/providers/Microsoft.Authorization/roleAssignments/31053994-993f-4b9f-b746-a1ff7c506e45",
    "name": "31053994-993f-4b9f-b746-a1ff7c506e45",
    "principalId": "91448210-9c62-4ea4-b436-50134fd9c830",
    "principalName": "puliu@microsoft.com",
    "principalType": "User",
    "roleDefinitionId": "Microsoft.KeyVault/providers/Microsoft.Authorization/roleDefinitions/515eb02d-2335-4d2d-92f2-b1cbdf9c3778",
    "roleName": "Managed HSM Crypto Officer",
    "scope": "/keys",
    "type": "Microsoft.Authorization/roleAssignments"
  },
  {
    "id": "/providers/Microsoft.Authorization/roleAssignments/aba5bb73-05c4-466f-a633-1c421ad349e9",
    "name": "aba5bb73-05c4-466f-a633-1c421ad349e9",
    "principalId": "91448210-9c62-4ea4-b436-50134fd9c830",
    "principalName": "puliu@microsoft.com",
    "principalType": "User",
    "roleDefinitionId": "Microsoft.KeyVault/providers/Microsoft.Authorization/roleDefinitions/21dbd100-6940-42c2-9190-5d6cb909625b",
    "roleName": "Managed HSM Crypto User",
    "scope": "/",
    "type": "Microsoft.Authorization/roleAssignments"
  },
  {
    "id": "/providers/Microsoft.Authorization/roleAssignments/9c27ddd0-32ce-4a6b-912a-02aae436a5b0",
    "name": "9c27ddd0-32ce-4a6b-912a-02aae436a5b0",
    "principalId": "91448210-9c62-4ea4-b436-50134fd9c830",
    "principalName": "puliu@microsoft.com",
    "principalType": "User",
    "roleDefinitionId": "Microsoft.KeyVault/providers/Microsoft.Authorization/roleDefinitions/a290e904-7015-4bba-90c8-60543313cdb4",
    "roleName": "Managed HSM Administrator",
    "scope": "/",
    "type": "Microsoft.Authorization/roleAssignments"
  },
  {
    "id": "/providers/Microsoft.Authorization/roleAssignments/2b1a01fc-2738-494a-96de-dfbe29e7a8e5",
    "name": "2b1a01fc-2738-494a-96de-dfbe29e7a8e5",
    "principalId": "30c7f262-1107-49d2-882a-abeb0050f854",
    "principalName": "2084ae4a-2cb6-495c-8892-e8c5f942cad1",
    "principalType": "ServicePrincipal",
    "roleDefinitionId": "Microsoft.KeyVault/providers/Microsoft.Authorization/roleDefinitions/21dbd100-6940-42c2-9190-5d6cb909625b",
    "roleName": "Managed HSM Crypto User",
    "scope": "/",
    "type": "Microsoft.Authorization/roleAssignments"
  }
]



C:\Users\azureuser>az login --identity --allow-no-subscriptions
[
  {
    "environmentName": "AzureCloud",
    "id": "72f988bf-86f1-41af-91ab-2d7cd011db47",
    "isDefault": true,
    "name": "N/A(tenant level account)",
    "state": "Enabled",
    "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47",
    "user": {
      "assignedIdentityInfo": "MSI",
      "name": "systemAssignedIdentity",
      "type": "servicePrincipal"
    }
  }
]


C:\Users\azureuser>az keyvault key list --id https://az400popmhsm.managedhsm.azure.net/
[
  {
    "attributes": {
      "created": "2021-08-19T20:56:33+00:00",
      "enabled": true,
      "expires": null,
      "exportable": false,
      "notBefore": null,
      "recoverableDays": 28,
      "recoveryLevel": "CustomizedRecoverable+Purgeable",
      "updated": "2021-08-19T20:56:33+00:00"
    },
    "kid": "https://az400popmhsm.managedhsm.azure.net/keys/myrsakey",
    "managed": null,
    "name": "myrsakey",
    "tags": null
  },
  {
    "attributes": {
      "created": "2021-08-19T20:59:50+00:00",
      "enabled": true,
      "expires": null,
      "exportable": false,
      "notBefore": null,
      "recoverableDays": 28,
      "recoveryLevel": "CustomizedRecoverable+Purgeable",
      "updated": "2021-08-19T20:59:50+00:00"
    },
    "kid": "https://az400popmhsm.managedhsm.azure.net/keys/myaeskey",
    "managed": null,
    "name": "myaeskey",
    "tags": null
  },
  {
    "attributes": {
      "created": "2021-08-19T21:02:43+00:00",
      "enabled": true,
      "expires": null,
      "exportable": true,
      "notBefore": null,
      "recoverableDays": 28,
      "recoveryLevel": "CustomizedRecoverable+Purgeable",
      "updated": "2021-08-19T21:02:43+00:00"
    },
    "kid": "https://az400popmhsm.managedhsm.azure.net/keys/mypemrsakey",
    "managed": null,
    "name": "mypemrsakey",
    "tags": null
  }
]


C:\Users\azureuser\keyvault-console-app>az keyvault key show --id https://az400popmhsm.managedhsm.azure.net/keys/CloudRsaKey-df54998a-ac05-4238-a6bb-63137808c99f


https://github.com/Azure/azure-sdk-for-net/tree/main/sdk/keyvault/Azure.Security.KeyVault.Keys


https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-use-vm-token
The fundamental interface for acquiring an access token is based on REST, making it accessible to any client application running on the VM that can make HTTP REST calls. This is similar to the Azure AD programming model, except the client uses an endpoint on the virtual machine (vs an Azure AD endpoint).
Sample request using the Azure Instance Metadata Service (IMDS) endpoint (recommended):

PS C:\Users\azureuser\keyvault-console-app> $r = invoke-webrequest 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' -Headers @{'metadata'='true'} -UseBasicParsing
PS C:\Users\azureuser\keyvault-console-app> $r.Content
{"access_token":"xxx",
 "client_id":"2084ae4a-2cb6-495c-8892-e8c5f942cad1",
 "expires_in":"86333",
 "expires_on":"1629845848",
 "ext_expires_in":"86399",
 "not_before":"1629759148",
 "resource":"https://management.azure.com/",
 "token_type":"Bearer"}

HEADER:ALGORITHM & TOKEN TYPE

{
  "typ": "JWT",
  "alg": "RS256",
  "x5t": "nOo3ZDrODXEK1jKWhXslHR_KXEg",
  "kid": "nOo3ZDrODXEK1jKWhXslHR_KXEg"
}
{
  "typ": "JWT",
  "alg": "RS256",
  "x5t": "nOo3ZDrODXEK1jKWhXslHR_KXEg",
  "kid": "nOo3ZDrODXEK1jKWhXslHR_KXEg"
}
PAYLOAD:DATA

{
  "aud": "https://management.azure.com/",
  "iss": "https://sts.windows.net/72f988bf-86f1-41af-91ab-2d7cd011db47/",
  "iat": 1629759148,
  "nbf": 1629759148,
  "exp": 1629845848,
  "aio": "E2ZgYHh/XJ5rI+elrXfmCj6NYrzNBwA=",
  "appid": "2084ae4a-2cb6-495c-8892-e8c5f942cad1",
  "appidacr": "2",
  "idp": "https://sts.windows.net/72f988bf-86f1-41af-91ab-2d7cd011db47/",
  "oid": "30c7f262-1107-49d2-882a-abeb0050f854",
  "rh": "0.ARoAv4j5cvGGr0GRqy180BHbR0quhCC2LFxJiJLoxflCytEaAAA.",
  "sub": "30c7f262-1107-49d2-882a-abeb0050f854",
  "tid": "72f988bf-86f1-41af-91ab-2d7cd011db47",
  "uti": "h_EsYsvI6EaU4p-gACpTAA",
  "ver": "1.0",
  "xms_mirid": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourcegroups/ContosoResourceGroup/providers/Microsoft.Compute/virtualMachines/testvmmhsm",
  "xms_tcdt": "1289241547"
}




$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://managedhsm.azure.net' -Headers @{Metadata="true"} -UseBasicParsing
$content =$response.Content | ConvertFrom-Json
$access_token = $content.access_token
$keysInfoRest = (Invoke-WebRequest -Uri 'https://az400popmhsm.managedhsm.azure.net/keys?api-version=7.2' -Method GET -ContentType "application/json" -Headers @{ Authorization ="Bearer $access_token"} -UseBasicParsing).content