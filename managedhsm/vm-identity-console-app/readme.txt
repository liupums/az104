

https://docs.microsoft.com/en-us/dotnet/csharp/tutorials/console-webapiclient


dotnet new console --name vm-identity-console-app

PS C:\Users\azureuser\vm-identity-console-app> dotnet run       
{"value":[{"attributes":{"created":1629406593,"enabled":true,"exportable":false,"recoverableDays":28,"recoveryLevel":"CustomizedRecoverable+Purgeable","updated":1629406593},"kid":"https://az400popmhsm.managedhsm.azure.net/keys/myrsakey"},{"attributes":{"created":1629406790,"enabled":true,"exportable":false,"recoverableDays":28,"recoveryLevel":"CustomizedRecoverable+Purgeable","updated":1629406790},"kid":"https://az400popmhsm.managedhsm.azure.net/keys/myaeskey"},{"attributes":{"created":1629406963,"enabled":true,"exportable":true,"recoverableDays":28,"recoveryLevel":"CustomizedRecoverable+Purgeable","updated":1629406963},"kid":"https://az400popmhsm.managedhsm.azure.net/keys/mypemrsakey"},{"attributes":{"created":1629753443,"enabled":true,"exp":1661289443,"exportable":false,"recoverableDays":28,"recoveryLevel":"CustomizedRecoverable+Purgeable","updated":1629753443},"kid":"https://az400popmhsm.managedhsm.azure.net/keys/CloudRsaKey-df54998a-ac05-4238-a6bb-63137808c99f"},{"attributes":{"created":1629763058,"enabled":true,"exp":1661299057,"exportable":false,"recoverableDays":28,"recoveryLevel":"CustomizedRecoverable+Purgeable","updated":1629763058},"kid":"https://az400popmhsm.managedhsm.azure.net/keys/CloudRsaKey-06e8d542-49f0-4557-a30b-a7565b58db7b"}]}


===user defined managed identity==
C:\Users\puliu\keyvault>az identity create -g contosoresourcegroup -n "hsmvmid"
{
  "clientId": "8a188a88-fd90-41e9-b603-fe949e2eaf22",
  "clientSecretUrl": "https://control-eastus2.identity.azure.net/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourcegroups/contosoresourcegroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/hsmvmid/credentials?tid=72f988bf-86f1-41af-91ab-2d7cd011db47&oid=9f3292c9-9541-40af-bb71-4c625cae361b&aid=8a188a88-fd90-41e9-b603-fe949e2eaf22",
  "id": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourcegroups/contosoresourcegroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/hsmvmid",
  "location": "eastus2",
  "name": "hsmvmid",
  "principalId": "9f3292c9-9541-40af-bb71-4c625cae361b",
  "resourceGroup": "contosoresourcegroup",
  "tags": {},
  "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47",
  "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
}

C:\Users\puliu\keyvault>az identity list -g contosoresourcegroup
[
  {
    "clientId": "8a188a88-fd90-41e9-b603-fe949e2eaf22",
    "clientSecretUrl": "https://control-eastus2.identity.azure.net/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourcegroups/contosoresourcegroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/hsmvmid/credentials?tid=72f988bf-86f1-41af-91ab-2d7cd011db47&oid=9f3292c9-9541-40af-bb71-4c625cae361b&aid=8a188a88-fd90-41e9-b603-fe949e2eaf22",
    "id": "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourcegroups/contosoresourcegroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/hsmvmid",
    "location": "eastus2",
    "name": "hsmvmid",
    "principalId": "9f3292c9-9541-40af-bb71-4c625cae361b",
    "resourceGroup": "contosoresourcegroup",
    "tags": {},
    "tenantId": "72f988bf-86f1-41af-91ab-2d7cd011db47",
    "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
  }
]

C:\Users\puliu\keyvault>az vm identity assign -g contosoresourcegroup -n testvmmhsm --identities hsmvmid
{
  "systemAssignedIdentity": "30c7f262-1107-49d2-882a-abeb0050f854",
  "userAssignedIdentities": {
    "/subscriptions/ce2c696e-9825-44f7-9a68-f34d153e64ba/resourceGroups/contosoresourcegroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/hsmvmid": {
      "clientId": "8a188a88-fd90-41e9-b603-fe949e2eaf22",
      "principalId": "9f3292c9-9541-40af-bb71-4c625cae361b"
    }
  }
}

For keyvault, you need to choose between Access Policy and RBAC
The RBAC works for user-defined managed identity


