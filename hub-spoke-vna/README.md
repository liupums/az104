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

# Full transcript of testing
```
LAPTOP-MAIGQA9N:hub-spoke-vna puliu$ ssh azureuser@13.91.247.164
Welcome to Ubuntu 18.04.5 LTS (GNU/Linux 5.4.0-1051-azure x86_64)

azureuser@LinuxTest1:~$ ifconfig | grep 'inet '
        inet 10.1.0.4  netmask 255.255.255.0  broadcast 10.1.0.255
        inet 127.0.0.1  netmask 255.0.0.0
azureuser@LinuxTest1:~$ sudo traceroute -T 10.0.0.4
traceroute to 10.0.0.4 (10.0.0.4), 30 hops max, 60 byte packets
 1  192.168.0.7 (192.168.0.7)  3.604 ms 192.168.0.6 (192.168.0.6)  2.537 ms  2.522 ms
 2  10.0.0.4 (10.0.0.4)  8.499 ms  8.486 ms  8.472 ms
azureuser@LinuxTest1:~$ sudo traceroute -T www.google.com
traceroute to www.google.com (216.58.195.68), 30 hops max, 60 byte packets
 1  192.168.0.6 (192.168.0.6)  2.724 ms  2.701 ms 192.168.0.7 (192.168.0.7)  2.687 ms
 2  * * *
 3  * * *
 4  * * *
 5  * * *
 6  * * *
 7  * * *
 8  * * *
 9  * * *
10  * * *
11  * * *
12  sfo07s16-in-f68.1e100.net (216.58.195.68)  4.145 ms * *
azureuser@LinuxTest1:~$ curl 10.1.0.4
Hello World from host LinuxTest1!azureuser@LinuxTest1:~$ 
azureuser@LinuxTest1:~$ 
azureuser@LinuxTest1:~$ service nginx status
● nginx.service - A high performance web server and a reverse proxy server
   Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
   Active: active (running) since Sat 2021-07-10 16:40:56 UTC; 56min ago
     Docs: man:nginx(8)
  Process: 9388 ExecStop=/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid (code=exited, status=0/SUCCESS)
  Process: 9403 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
  Process: 9391 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
 Main PID: 9407 (nginx)
    Tasks: 2 (limit: 2263)
   CGroup: /system.slice/nginx.service
           ├─9407 nginx: master process /usr/sbin/nginx -g daemon on; master_process on;
           └─9411 nginx: worker process

Jul 10 16:40:56 LinuxTest1 systemd[1]: Starting A high performance web server and a reverse proxy server...
Jul 10 16:40:56 LinuxTest1 systemd[1]: nginx.service: Failed to parse PID from file /run/nginx.pid: Invalid argument
Jul 10 16:40:56 LinuxTest1 systemd[1]: Started A high performance web server and a reverse proxy server.
```