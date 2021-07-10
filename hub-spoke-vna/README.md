# VNET to VNET connection
This template creates Hub-Spoke vNETs in the same location, see the [referenced tutorial](https://techcommunity.microsoft.com/t5/fasttrack-for-azure/using-azure-firewall-as-a-network-virtual-appliance-nva/ba-p/1972934) and the [high level diagram](https://techcommunity.microsoft.com/t5/fasttrack-for-azure/using-azure-firewall-as-a-network-virtual-appliance-nva/ba-p/1972934?lightbox-message-images-1972934=239185iA66BE3E562016600)

- Hub vNET contains the firewall as VNA
- Two Spoke vNET each contains a single subnet and with one Linux VM inside. 
- Each Spoke is conntected with Hub via vNET peering but two Spoke vNETs are NOT peered.
- Two Spoke vNETs are connected via the firewall plus user defined routing  

# How to build and deploy
- `az bicep build -f main.bicep`
- `az deployment sub create --location westus --template-file main.bicep --parameters @main.parameters.json`


# How to verify the two Spoke vNETs are connected
- SSH to the test VM 10.1.0.4 in SpokeTest vNET via firewall public IP (the SNAT rule)
- Run `traceroute` to check the routing to another VM 10.0.0.4 in the SpokeProd vNET
- Note the the next hop is the private IP 192.168.0.6 of firewall in the HUB vNET
  - sudo apt install traceroute 
  - sudo traceroute -T 10.0.0.4 
  ```traceroute to 10.0.0.4 (10.0.0.4), 30 hops max, 60 byte packets
   1  192.168.0.6 (192.168.0.6)  2.606 ms 192.168.0.7 (192.168.0.7)  2.592 ms 192.168.0.6 (192.168.0.6)  2.583 ms
   2  10.0.0.4 (10.0.0.4)  5.180 ms  5.845 ms  5.966 ms
  ```
# Note
- The [cloud-init.txt](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-automate-vm-deployment) is used to install NGINX and traceroute
- A maunal step is needed to convet the cloud-init.txt to base64 string and then add to main.parameters.json  
`cat cloud-init.txt | base64` 

# TODO
How to use [KeyVault for SSL certificates](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.compute/vmss-ubuntu-web-ssl)