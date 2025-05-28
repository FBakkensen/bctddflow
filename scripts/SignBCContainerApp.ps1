# Certificate and password is in Password HUB: 9altitudes GTM -> Common -> Code Signing
# Ask Diederick Hallynck for access

$containerName = 'bcserver'
$appFile = "C:\ProgramData\BcContainerHelper\Extensions\bcserver\my\9altitudes_9A Advanced Manufacturing – Project Based_23.23.10.1.app"
$pfxFile = "C:\ProgramData\BcContainerHelper\Extensions\bcserver\9altitudes.pfx"

$certificatepass = Read-Host "Enter Pass For Certificate: " -AsSecureString

Sign-BcContainerApp -containerName $containerName -appFile $appFile -pfxFile $pfxFile -pfxPassword $certificatepass