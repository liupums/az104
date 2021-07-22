Import-Module -Force -Name ".\Common.psm1"
InitGlobalVariables
LoginAzure

$askclustername = "myAKSCluster"
$aks = Get-AzAks -ResourceGroupName $global:MyResourceGroup -Name $askclustername -ErrorAction Ignore
if (-Not $aks)
{
    New-AzAksCluster -ResourceGroupName $global:MyResourceGroup -Name $askclustername -NodeCount 1
}
