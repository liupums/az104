# VNET to VNET connection

This template creates three VNETs in the same location, each containing a subnet and Gateway subnet. It creates three public IPs which are used to create a VPN Gateway in each VNET, all BGP enabled using private ASNs. 

It then establishes a BGP enabled connection between Hub and SpokeProd, and Hub and SpokeTest.

To demonstrate the transitive routing capabilities, deploy LinuxProd1 VM in SpokeProd and LinuxTest1 VM in SpokeTest. Then SSH to LinuxProd1 and from LinuxProd1, testing the connection with LinuxTest1

# How to build and deploy
- `az bicep build -f main.bicep`
- `az deployment sub create --location westus --template-file main.bicep --parameters @main.parameters.json`

Notes:
- The Autonomous System Numbers (ASNs) can be private or public (if you do use a public one, you must be able to prove ownership of it)
- Enter the Pre-shared Key as a parameter

# Full transcript of testing
- Loggon to LinuxProd1, then trace route to LinuxTest1 10.1.1.4
```
LAPTOP-MAIGQA9N:vnet-transitive-bgp puliu$ az vm show -d -g hubSpokeBgp -n LinuxProd1 --query publicIps -o tsv
13.93.176.177
LAPTOP-MAIGQA9N:vnet-transitive-bgp puliu$ ssh azureuser@13.93.176.177
Welcome to Ubuntu 18.04.5 LTS (GNU/Linux 5.4.0-1051-azure x86_64)

azureuser@LinuxProd1:~$ ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.0.1.4  netmask 255.255.255.0  broadcast 10.0.1.255
        inet6 fe80::222:48ff:fe05:e5c2  prefixlen 64  scopeid 0x20<link>
        ether 00:22:48:05:e5:c2  txqueuelen 1000  (Ethernet)
        RX packets 195740  bytes 263180139 (263.1 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 21159  bytes 4361669 (4.3 MB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 2696  bytes 353767 (353.7 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 2696  bytes 353767 (353.7 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

azureuser@LinuxProd1:~$ sudo traceroute -T 10.1.1.4
traceroute to 10.1.1.4 (10.1.1.4), 30 hops max, 60 byte packets
 1  10.1.1.4 (10.1.1.4)  15.091 ms  15.149 ms  15.140 ms
```

- Loggon to LinuxTest1, then trace route to LinuxProd1 via private IP  10.0.1.4
LAPTOP-MAIGQA9N:vnet-transitive-bgp puliu$ az vm show -d -g hubSpokeBgp -n LinuxTest1 --query publicIps -o tsv
13.64.17.146
LAPTOP-MAIGQA9N:vnet-transitive-bgp puliu$ ssh azureuser@13.64.17.146
Welcome to Ubuntu 18.04.5 LTS (GNU/Linux 5.4.0-1051-azure x86_64)

azureuser@LinuxTest1:~$ sudo traceroute -T 10.0.1.4
traceroute to 10.0.1.4 (10.0.1.4), 30 hops max, 60 byte packets
 1  10.0.1.4 (10.0.1.4)  13.832 ms  18.450 ms  18.437 ms
