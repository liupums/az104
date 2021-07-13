# VNET to VNET connection
This template creates vmss build agent for Azure DevOps, see the [referenced tutorial](https://github.com/matt-FFFFFF/terraform-azuredevops-vmss-agent) 

# How to build and deploy
- `az bicep build -f buildagent.main.bicep`
- `az deployment sub create --location westus --template-file buildagent.main.bicep --parameters @buildagent.parameters.json`

# Note
- The [cloud-init.txt](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-automate-vm-deployment) is used to install maven and traceroute
- A maunal step is needed to convet the cloud-init.txt to base64 string and then add to main.parameters.json  
`cat cloud-init.txt | base64` 

# TODO

# Full transcript of testing
