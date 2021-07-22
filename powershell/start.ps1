Set-ExecutionPolicy -Scope Process -ExecutionPolicy  ByPass

$myAccount = "puliu@microsoft.com"
$mySubscription = "uswestcsu_internal"
$mySubscriptionGuid = "ce2c696e-9825-44f7-9a68-f34d153e64ba"
$myTenent = "72f988bf-86f1-41af-91ab-2d7cd011db47"
$currentAccount = (Get-AzContext).Account.Id
if (-Not ($currentAccount -like $myAccount))
{
    Connect-AzAccount -Tenant $myTenent -Subscription $mySubscription
}
 
$currentSubscription = (Get-AzContext).SubscriptionName
if (-Not ($currentSubscription -like $mySubscription))
{
    Set-AzContext -Subscription $mySubscriptionGuid
}

