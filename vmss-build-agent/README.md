# VNET to VNET connection
This template creates vmss build agent for Azure DevOps, see the [referenced tutorial](https://github.com/matt-FFFFFF/terraform-azuredevops-vmss-agent)
The Microsoft doc is available [here](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops)

# How to build and deploy
- `az bicep build -f buildagent.main.bicep`
- `az deployment sub create --location westus --template-file buildagent.main.bicep --parameters @buildagent.parameters.json`

# Note
- The [cloud-init.txt](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-automate-vm-deployment) is used to install maven and traceroute
- A maunal step is needed to convet the cloud-init.txt to base64 string and then add to main.parameters.json  
`cat cloud-init.txt | base64` 

# TODO

# Full transcript of testing
- Use Bastion to logon VM
  Goto 'buildagent' -> Instances -> buildagent_0 (for example) -> Connect with Bastion
  ```
  Username: azureuser
  Authentication Type: SSH Private Key from Azure Key Vault
  Subscription: uswestcsu_internal
  Azure Key Vault: az400popliukeyvault
  Azure Key Vault Secret: az400privatekey
  ``` 
- Check build agent
  NOTE: it might take several minutes for the VMSS to connect with Azure DevOps, [Azure DevOps CLI](https://docs.microsoft.com/en-us/cli/azure/service-page/azure%20pipelines?view=azure-cli-latest)

  - Check pool
  ```
    LAPTOP-MAIGQA9N:vmss-build-agent puliu$ az pipelines pool show --pool-id 12 --query name
    Command group 'pipelines pool' is in preview and under development. Reference and support levels: https://aka.ms/CLI_refstatus
    "buildagentvmss"

    LAPTOP-MAIGQA9N:vmss-build-agent puliu$ az pipelines agent list --pool-id 12 
    Command group 'pipelines agent' is in preview and under development. Reference and support levels: https://aka.ms/CLI_refstatus
    [
      {
        "accessPoint": "CodexAccessMapping",
        "assignedAgentCloudRequest": null,
        "assignedRequest": null,
        "authorization": {
          "authorizationUrl": null,
          "clientId": "8a2c4a1b-f022-42b5-8020-84f961f6ebe8",
          "publicKey": {
            "exponent": "AQAB",
            "modulus": "3Yj+k0iBrhrVVecAuIN2wk1uMpnbIIRPJY2ubzxASdP6pkGi2TTwdNleSDlwtIGQ9yK5i69cHomv4Mh1OYwKWCU/W4FWiZyWQdyIPSbkS+gLVcP0PCpH6jM3tzNWZcuuFhhcor5yUS2+a2GxED1ONXP675KMDWomzfmyc0S5PREmgE7aOaOwdEEeJTVeIIg6OhAGTib+ILQ5RHYVjDsfLthhes76ZSVJaT2sgm6S6Waq+jFCQHLdSUkmVmTm74PQTsAWh87CkyTHyRRkiz9X39N7/WbMn8vvdMmgekqe0H8JYjqsk+wUPOdTSi8nWkIGnmmlMGU4gaHgGal3MOKV0Q=="
          }
        },
        "createdOn": "2021-07-13T21:20:30.543000+00:00",
        "enabled": true,
        "id": 93,
        "lastCompletedRequest": null,
        "maxParallelism": 1,
        "name": "buildagent000002",
        "osDescription": "Linux 5.8.0-1036-azure #38~20.04.1-Ubuntu SMP Thu Jun 17 14:14:18 UTC 2021",
        "pendingUpdate": null,
        "properties": null,
        "provisioningState": "Provisioned",
        "status": "online",
        "statusChangedOn": "2021-07-13T21:20:38.970000+00:00",
        "systemCapabilities": null,
        "userCapabilities": null,
        "version": "2.188.4"
      },
      {
        "accessPoint": "CodexAccessMapping",
        "assignedAgentCloudRequest": null,
        "assignedRequest": null,
        "authorization": {
          "authorizationUrl": null,
          "clientId": "a62ca5c7-f0cf-4200-bd41-c50199c19c4b",
          "publicKey": {
            "exponent": "AQAB",
            "modulus": "tKoFHvv8l6X6OurSqxDV394NbqWXpcsXOOjBrDBYsiBnKn6BIa2UeKW8SX8wDFrSg7LahIQ6BdVBcnG3/3KW4JaSOFUo2fbm7MzF21Tnjd2iVDTe9ZQxHrArPuYi23DAwT2uy8KVXzZvW5lEfsp3yapGxZtjEreXUaNrxwfrufmWGSitpdVbW9h9XCYcGIi44uEYjGWE18m6lXesi+2HUwA/Is+5EpuUUvScUXL+rjOMgLC3GQIpm/S8+rOI7j1AakjYU8OBoeappdV27sDijtuV+UF703lCKq+QnBBP+RB1rS8xlOYpF/fZuFCkqvHYSoowKBn5i54pC+XYHt6bOQ=="
          }
        },
        "createdOn": "2021-07-13T21:21:23.557000+00:00",
        "enabled": true,
        "id": 94,
        "lastCompletedRequest": null,
        "maxParallelism": 1,
        "name": "buildagent000001",
        "osDescription": "Linux 5.8.0-1036-azure #38~20.04.1-Ubuntu SMP Thu Jun 17 14:14:18 UTC 2021",
        "pendingUpdate": null,
        "properties": null,
        "provisioningState": "Provisioned",
        "status": "online",
        "statusChangedOn": "2021-07-13T21:21:31.270000+00:00",
        "systemCapabilities": null,
        "userCapabilities": null,
        "version": "2.188.4"
      }
    ]
  ```
  - Modify the [azure-pipelines.yml](https://github.com/liupums/spring-framework-petclinic/blob/master/azure-pipelines.yml)
  ```
    pool:
      # vmImage: $(vmImageName)
      # name: 'MyAgentPool'
      # name: 'LinuxVMScaleSetAgentPool'
      name: 'buildagentvmss'
  ```

  - Check result
  ```
  LAPTOP-MAIGQA9N:vmss-build-agent puliu$ az pipelines build list --project javawebapp --top 1
    [
      {
        "buildNumber": "20210713.3",
        "buildNumberRevision": 3,
        "controller": null,
        "definition": {
          "createdDate": null,
          "drafts": [],
          "id": 4,
          "name": "liupums.spring-framework-petclinic",
          "path": "\\",
          "project": {
            "abbreviation": null,
            "defaultTeamImageUrl": null,
            "description": "java web app",
            "id": "14ab5b9e-3451-4d8a-b1bc-6f1948d4dd8a",
            "lastUpdateTime": "2021-06-23T16:59:23.03Z",
            "name": "javawebapp",
            "revision": 19,
            "state": "wellFormed",
            "url": "https://dev.azure.com/popliucsa/_apis/projects/14ab5b9e-3451-4d8a-b1bc-6f1948d4dd8a",
            "visibility": "private"
          },
          "queueStatus": "enabled",
          "revision": 1,
          "type": "build",
          "uri": "vstfs:///Build/Definition/4",
          "url": "https://dev.azure.com/popliucsa/14ab5b9e-3451-4d8a-b1bc-6f1948d4dd8a/_apis/build/Definitions/4?revision=1"
        },
        "deleted": null,
        "deletedBy": null,
        "deletedDate": null,
        "deletedReason": null,
        "demands": null,
        "finishTime": "2021-07-13T21:27:41.944221+00:00",
        "id": 39,
        "keepForever": true,
        "lastChangedBy": {
          "descriptor": "s2s.MDAwMDAwMDItMDAwMC04ODg4LTgwMDAtMDAwMDAwMDAwMDAwQDJjODk1OTA4LTA0ZTAtNDk1Mi04OWZkLTU0YjAwNDZkNjI4OA",
          "directoryAlias": null,
          "displayName": "Microsoft.VisualStudio.Services.TFS",
          "id": "00000002-0000-8888-8000-000000000000",
          "imageUrl": "https://dev.azure.com/popliucsa/_apis/GraphProfile/MemberAvatars/s2s.MDAwMDAwMDItMDAwMC04ODg4LTgwMDAtMDAwMDAwMDAwMDAwQDJjODk1OTA4LTA0ZTAtNDk1Mi04OWZkLTU0YjAwNDZkNjI4OA",
          "inactive": null,
          "isAadIdentity": null,
          "isContainer": null,
          "isDeletedInOrigin": null,
          "profileUrl": null,
          "uniqueName": "00000002-0000-8888-8000-000000000000@2c895908-04e0-4952-89fd-54b0046d6288",
          "url": "https://spsprodwus21.vssps.visualstudio.com/A944d00b9-06b8-46ad-abd5-bde230dd296a/_apis/Identities/00000002-0000-8888-8000-000000000000"
        },
        "lastChangedDate": "2021-07-13T21:27:42+00:00",
        "logs": {
          "id": 0,
          "type": "Container",
          "url": "https://dev.azure.com/popliucsa/14ab5b9e-3451-4d8a-b1bc-6f1948d4dd8a/_apis/build/builds/39/logs"
        },
        "orchestrationPlan": {
          "orchestrationType": null,
          "planId": "6dc06d22-a7c1-4293-b335-9fbcfbd48d45"
        },
        "parameters": null,
        "plans": [
          {
            "orchestrationType": null,
            "planId": "6dc06d22-a7c1-4293-b335-9fbcfbd48d45"
          }
        ],
        "priority": "normal",
        "project": {
          "abbreviation": null,
          "defaultTeamImageUrl": null,
          "description": "java web app",
          "id": "14ab5b9e-3451-4d8a-b1bc-6f1948d4dd8a",
          "lastUpdateTime": "2021-06-23T16:59:23.03Z",
          "name": "javawebapp",
          "revision": 19,
          "state": "wellFormed",
          "url": "https://dev.azure.com/popliucsa/_apis/projects/14ab5b9e-3451-4d8a-b1bc-6f1948d4dd8a",
          "visibility": "private"
        },
        "properties": {},
        "quality": null,
        "queue": {
          "id": 17,
          "name": "Hosted Ubuntu 1604",
          "pool": {
            "id": 8,
            "isHosted": true,
            "name": "Hosted Ubuntu 1604"
          },
          "url": null
        },
        "queueOptions": null,
        "queuePosition": null,
        "queueTime": "2021-07-13T21:23:50.716657+00:00",
        "reason": "individualCI",
        "repository": {
          "checkoutSubmodules": false,
          "clean": null,
          "defaultBranch": null,
          "id": "liupums/spring-framework-petclinic",
          "name": null,
          "properties": null,
          "rootFolder": null,
          "type": "GitHub",
          "url": null
        },
        "requestedBy": {
          "descriptor": "svc.OTQ0ZDAwYjktMDZiOC00NmFkLWFiZDUtYmRlMjMwZGQyOTZhOkdpdEh1YiBBcHA6MTRhYjViOWUtMzQ1MS00ZDhhLWIxYmMtNmYxOTQ4ZDRkZDhh",
          "directoryAlias": null,
          "displayName": "GitHub",
          "id": "600a992f-5863-4847-a58e-72aa888a99d1",
          "imageUrl": "https://dev.azure.com/popliucsa/_apis/GraphProfile/MemberAvatars/svc.OTQ0ZDAwYjktMDZiOC00NmFkLWFiZDUtYmRlMjMwZGQyOTZhOkdpdEh1YiBBcHA6MTRhYjViOWUtMzQ1MS00ZDhhLWIxYmMtNmYxOTQ4ZDRkZDhh",
          "inactive": null,
          "isAadIdentity": null,
          "isContainer": null,
          "isDeletedInOrigin": null,
          "profileUrl": null,
          "uniqueName": "GitHub App\\14ab5b9e-3451-4d8a-b1bc-6f1948d4dd8a",
          "url": "https://spsprodwus21.vssps.visualstudio.com/A944d00b9-06b8-46ad-abd5-bde230dd296a/_apis/Identities/600a992f-5863-4847-a58e-72aa888a99d1"
        },
        "requestedFor": {
          "descriptor": "svc.OTQ0ZDAwYjktMDZiOC00NmFkLWFiZDUtYmRlMjMwZGQyOTZhOkdpdEh1YiBBcHA6MTRhYjViOWUtMzQ1MS00ZDhhLWIxYmMtNmYxOTQ4ZDRkZDhh",
          "directoryAlias": null,
          "displayName": "GitHub",
          "id": "600a992f-5863-4847-a58e-72aa888a99d1",
          "imageUrl": "https://dev.azure.com/popliucsa/_apis/GraphProfile/MemberAvatars/svc.OTQ0ZDAwYjktMDZiOC00NmFkLWFiZDUtYmRlMjMwZGQyOTZhOkdpdEh1YiBBcHA6MTRhYjViOWUtMzQ1MS00ZDhhLWIxYmMtNmYxOTQ4ZDRkZDhh",
          "inactive": null,
          "isAadIdentity": null,
          "isContainer": null,
          "isDeletedInOrigin": null,
          "profileUrl": null,
          "uniqueName": "GitHub App\\14ab5b9e-3451-4d8a-b1bc-6f1948d4dd8a",
          "url": "https://spsprodwus21.vssps.visualstudio.com/A944d00b9-06b8-46ad-abd5-bde230dd296a/_apis/Identities/600a992f-5863-4847-a58e-72aa888a99d1"
        },
        "result": "succeeded",
        "retainedByRelease": false,
        "sourceBranch": "refs/heads/master",
        "sourceVersion": "925d66387c553c626a85a6db73d7358a7d2d7ff7",
        "startTime": "2021-07-13T21:23:56.744580+00:00",
        "status": "completed",
        "tags": [],
        "triggerInfo": {
          "ci.message": "use buildagentvmss",
          "ci.sourceBranch": "refs/heads/master",
          "ci.sourceSha": "925d66387c553c626a85a6db73d7358a7d2d7ff7",
          "ci.triggerRepository": "liupums/spring-framework-petclinic"
        },
        "triggeredByBuild": null,
        "uri": "vstfs:///Build/Build/39",
        "url": "https://dev.azure.com/popliucsa/14ab5b9e-3451-4d8a-b1bc-6f1948d4dd8a/_apis/build/Builds/39",
        "validationResults": []
      }
    ]

  ```
