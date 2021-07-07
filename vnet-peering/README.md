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