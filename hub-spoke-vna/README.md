# VNET to VNET connection

This template creates two VNETs in the same location, each containing a single subnet, and creates connections between them using VNet peering.

MININT-0CQ9985:vnet-peering puliu$ ssh azureuser@40.78.66.23 ping 10.0.0.4
PING 10.0.0.4 (10.0.0.4) 56(84) bytes of data.
64 bytes from 10.0.0.4: icmp_seq=1 ttl=64 time=3.78 ms
64 bytes from 10.0.0.4: icmp_seq=2 ttl=64 time=1.39 ms
^CMININT-0CQ9985:vnet-peering puliussh azureuser@40.78.64.35 ping 192.168.0.4
PING 192.168.0.4 (192.168.0.4) 56(84) bytes of data.
64 bytes from 192.168.0.4: icmp_seq=1 ttl=64 time=1.09 ms
64 bytes from 192.168.0.4: icmp_seq=2 ttl=64 time=1.10 ms


az deployment sub create --location westus --template-file main.bicep --parameters @main.parameters.json


sudo apt install tcptraceroute
sudo wget http://www.vdberg.org/~richard/tcpping -O /usr/bin/tcping
sudo chmod 755 /usr/bin/tcping
azureuser@LinuxTest1:~/.ssh$ tcping 10.1.0.4 22
seq 0: tcp response from 10.1.0.4 [open]  0.035 ms
seq 1: tcp response from 10.1.0.4 [open]  0.040 ms

sudo apt install traceroute 
sudo traceroute -T 10.0.0.4 
traceroute to 10.0.0.4 (10.0.0.4), 30 hops max, 60 byte packets
 1  192.168.0.6 (192.168.0.6)  2.606 ms 192.168.0.7 (192.168.0.7)  2.592 ms 192.168.0.6 (192.168.0.6)  2.583 ms
 2  10.0.0.4 (10.0.0.4)  5.180 ms  5.845 ms  5.966 ms


 cloud-init.txt
 https://docs.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-automate-vm-deployment
 cat cloud-init.txt | base64 

 I2Nsb3VkLWNvbmZpZwpwYWNrYWdlX3VwZ3JhZGU6IHRydWUKcGFja2FnZXM6CiAgLSBuZ2lueAogIC0gbm9kZWpzCiAgLSBucG0KICAtIHRyYWNlcm91dGUKd3JpdGVfZmlsZXM6CiAgLSBvd25lcjogd3d3LWRhdGE6d3d3LWRhdGEKICAgIHBhdGg6IC9ldGMvbmdpbngvc2l0ZXMtYXZhaWxhYmxlL2RlZmF1bHQKICAgIGNvbnRlbnQ6IHwKICAgICAgc2VydmVyIHsKICAgICAgICBsaXN0ZW4gODA7CiAgICAgICAgbGlzdGVuIDQ0MyBzc2w7CiAgICAgICAgc3NsX2NlcnRpZmljYXRlIC9ldGMvbmdpbngvc3NsL215Y2VydC5jZXJ0OwogICAgICAgIHNzbF9jZXJ0aWZpY2F0ZV9rZXkgL2V0Yy9uZ2lueC9zc2wvbXljZXJ0LnBydjsKICAgICAgICBsb2NhdGlvbiAvIHsKICAgICAgICAgIHByb3h5X3Bhc3MgaHR0cDovL2xvY2FsaG9zdDozMDAwOwogICAgICAgICAgcHJveHlfaHR0cF92ZXJzaW9uIDEuMTsKICAgICAgICAgIHByb3h5X3NldF9oZWFkZXIgVXBncmFkZSAkaHR0cF91cGdyYWRlOwogICAgICAgICAgcHJveHlfc2V0X2hlYWRlciBDb25uZWN0aW9uIGtlZXAtYWxpdmU7CiAgICAgICAgICBwcm94eV9zZXRfaGVhZGVyIEhvc3QgJGhvc3Q7CiAgICAgICAgICBwcm94eV9jYWNoZV9ieXBhc3MgJGh0dHBfdXBncmFkZTsKICAgICAgICB9CiAgICAgIH0KICAtIG93bmVyOiBhenVyZXVzZXI6YXp1cmV1c2VyCiAgICBwYXRoOiAvaG9tZS9henVyZXVzZXIvbXlhcHAvaW5kZXguanMKICAgIGNvbnRlbnQ6IHwKICAgICAgdmFyIGV4cHJlc3MgPSByZXF1aXJlKCdleHByZXNzJykKICAgICAgdmFyIGFwcCA9IGV4cHJlc3MoKQogICAgICB2YXIgb3MgPSByZXF1aXJlKCdvcycpOwogICAgICBhcHAuZ2V0KCcvJywgZnVuY3Rpb24gKHJlcSwgcmVzKSB7CiAgICAgICAgcmVzLnNlbmQoJ0hlbGxvIFdvcmxkIGZyb20gaG9zdCAnICsgb3MuaG9zdG5hbWUoKSArICchJykKICAgICAgfSkKICAgICAgYXBwLmxpc3RlbigzMDAwLCBmdW5jdGlvbiAoKSB7CiAgICAgICAgY29uc29sZS5sb2coJ0hlbGxvIHdvcmxkIGFwcCBsaXN0ZW5pbmcgb24gcG9ydCAzMDAwIScpCiAgICAgIH0pCnJ1bmNtZDoKICAtIHNlY3JldHNuYW1lPSQoZmluZCAvdmFyL2xpYi93YWFnZW50LyAtbmFtZSAiKi5wcnYiIHwgY3V0IC1jIC01NykKICAtIG1rZGlyIC9ldGMvbmdpbngvc3NsCiAgLSBjcCAkc2VjcmV0c25hbWUuY3J0IC9ldGMvbmdpbngvc3NsL215Y2VydC5jZXJ0CiAgLSBjcCAkc2VjcmV0c25hbWUucHJ2IC9ldGMvbmdpbngvc3NsL215Y2VydC5wcnYKICAtIHNlcnZpY2UgbmdpbnggcmVzdGFydAogIC0gY2QgIi9ob21lL2F6dXJldXNlci9teWFwcCIKICAtIG5wbSBpbml0CiAgLSBucG0gaW5zdGFsbCBleHByZXNzIC15CiAgLSBub2RlanMgaW5kZXguanMK