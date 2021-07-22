Get-AzKeyVaultCertificate -VaultName "az400popliukeyvault" -Name "mycert" -IncludeVersions
$secret = Get-AzKeyVaultSecret -VaultName "az400popliukeyvault" -Name "mycert" -Version 2ba8bdb1c8e749feb2d4956cb8c07d07 -AsPlainText
$secretByte = [Convert]::FromBase64String($secret)
[System.IO.File]::WriteAllBytes("c:\Users\puliu\az104\powershell\cert.pfx", $secretByte)
certutil .\cert.pfx