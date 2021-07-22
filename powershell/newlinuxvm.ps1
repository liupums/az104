Import-Module -Force -Name ".\Common.psm1"
InitGlobalVariables
LoginAzure

$sshKeyFile = "$home\.ssh\id_rsa.pub"
if (Test-Path $sshKeyFile -PathType Leaf)
{
    Write-Host "ssh key is already created: $sshKeyFile"
}
else {
    ssh-keygen -t rsa -b 4096
}

$myVnet = "myVNET"
$myVnetAddress = "192.168.0.0/16"
$mySubnet = "mySubnet"
$mySubnetAddress = "192.168.1.0/24"
$myPublicIp = "myPublicIp"

$vnet = Get-AzVirtualNetwork -Name $myVnet -ResourceGroupName $global:MyResourceGroup -ErrorAction Ignore

# Create a virtual network, subnet, and a public IP address. 
# These resources are used to provide network connectivity to the VM and connect it to the internet
# Create a virtual network
if (-Not $vnet)
{
    # Create a subnet configuration
    $subnetConfig = New-AzVirtualNetworkSubnetConfig `
        -Name $mySubnet `
        -AddressPrefix $mySubnetAddress

    $vnet = New-AzVirtualNetwork `
        -ResourceGroupName $global:MyResourceGroup `
        -Location $global:MyLocation `
        -Name $myVnet `
        -AddressPrefix $myVnetAddress `
        -Subnet $subnetConfig
}

$pip = Get-AzPublicIpAddress -Name $myPublicIp -ErrorAction Ignore
if (-Not $pip)
{
    # Create a public IP address and specify a DNS name
    $pip = New-AzPublicIpAddress `
    -ResourceGroupName $global:MyResourceGroup `
    -Location $global:MyLocation `
    -AllocationMethod Static `
    -IdleTimeoutInMinutes 4 `
    -Name $myPublicIp
}

$myNsg = "myNetworkSecurityGroup"
$nsg = Get-AzNetworkSecurityGroup -Name $myNsg -ErrorAction Ignore
if (-Not $nsg)
{
    # Create an inbound network security group rule for port 22
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
        -Name "mySshRule" `
        -Protocol "Tcp" `
        -Direction "Inbound" `
        -Priority 1000 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 22 `
        -Access "Allow"

    # Create an inbound network security group rule for port 80
    $nsgRuleWeb = New-AzNetworkSecurityRuleConfig `
        -Name "myWwwRule"  `
        -Protocol "Tcp" `
        -Direction "Inbound" `
        -Priority 1001 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 80 `
        -Access "Allow"

    # Create a network security group
    $nsg = New-AzNetworkSecurityGroup `
        -ResourceGroupName $global:MyResourceGroup `
        -Location $global:MyLocation `
        -Name $myNsg `
        -SecurityRules $nsgRuleSSH,$nsgRuleWeb
}

$myNic = "myNic"
$nic = Get-AzNetworkInterface -name $myNic -ErrorAction Ignore
if (-Not $nic)
{
    # Create a virtual network card and associate with public IP address and NSG
    $nic = New-AzNetworkInterface `
        -Name $myNic `
        -ResourceGroupName $global:MyResourceGroup `
        -Location $global:MyLocation `
        -SubnetId $vnet.Subnets[0].Id `
        -PublicIpAddressId $pip.Id `
        -NetworkSecurityGroupId $nsg.Id
}


#create vm
$myUser="azureuser"
$myVm = "myVM"
$vm = Get-AzVm -ResourceGroupName $global:MyResourceGroup -name $myVM -ErrorAction Ignore
if ($vm)
{
    Write-Host "vm already created: ssh $myUser@$($pip.IpAddress)"
    $status = Get-AzVM -status -Name $myVM
    $status.PowerState
    return
}

# Define a credential object
$securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($myUser, $securePassword)

# Create a virtual machine configuration
$vmConfig = New-AzVMConfig `
  -VMName $myVM `
  -VMSize "Standard_D1" | `
Set-AzVMOperatingSystem `
  -Linux `
  -ComputerName $myVM `
  -Credential $cred `
  -DisablePasswordAuthentication | `
Set-AzVMSourceImage `
  -PublisherName "Canonical" `
  -Offer "UbuntuServer" `
  -Skus "18.04-LTS" `
  -Version "latest" | `
Add-AzVMNetworkInterface `
  -Id $nic.Id

# Configure the SSH key
$sshPublicKey = Get-Content ~/.ssh/id_rsa.pub
Add-AzVMSshPublicKey `
  -VM $vmconfig `
  -KeyData $sshPublicKey `
  -Path "/home/azureuser/.ssh/authorized_keys"

New-AzVM `
  -ResourceGroupName $global:MyResourceGroup `
  -Location $global:MyLocation `
  -VM $vmConfig


# mount blobfuse
# https://techcommunity.microsoft.com/t5/azure-paas-blog/mount-blob-storage-on-linux-vm-using-managed-identities-or/ba-p/1821744
#LogoutAzure