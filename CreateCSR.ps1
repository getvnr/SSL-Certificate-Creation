## PowerShell Script to generate a Certificate Signing Request (CSR) using the SHA256 (SHA-256) signature algorithm and a 2048 bit key size (RSA) via the Cert Request Utility (certreq) ##

<#
.SYNOPSIS
This powershell script can be used to generate a Certificate Signing Request (CSR) using the SHA256 signature algorithm and a 2048 bit key size (RSA). Subject Alternative Names are supported.
.DESCRIPTION
Tested platforms:
- Windows Server 2008R2 with PowerShell 2.0
- Windows 8.1 with PowerShell 4.0
- Windows 10 with PowerShell 5.0
#>

####################
# Prerequisite check
####################
if (-NOT([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Administrator priviliges are required. Please restart this script with elevated rights." -ForegroundColor Red
    Pause
    Throw "Administrator priviliges are required. Please restart this script with elevated rights."
}


#######################
# Setting the variables
#######################
$Date = (Get-Date).ToString('ddMMyyyyTHHmmss')

$directory = "$pwd\"

$WebSiteName = Read-Host "Website/File Name"
#$WebSiteName

$propfile = $(Get-ChildItem -PATH $directory -recurse -Filter "$WebSiteName.txt")
#$propfile

if ($propfile){
$files = @{}
$files['settings'] = "$directory\$WebSiteName-settings.inf";
$files['csr'] = "$directory\$WebSiteName-csr-$Date.req"
#$directory

$request = convertfrom-stringdata (Get-Content $directory/$WebSiteName.txt | Out-String)

$request['SAN'] = @{}

###########################
# Subject Alternative Names
###########################
$AppProps1 = Get-Content $directory/$WebSiteName.txt | Select-String -pattern DNS
$i=0
 foreach ($Data in $AppProps1)
 {
 $i++
 $First = $Data[0]
 $fir = $First -split "=" | Select-Object -Skip 1
 if ($fir){
 #write-host "First is: " $fir
 $request['SAN'][$i] = $fir
 }
 }
 
 $request['SAN']
 $exportable = $request['Exportable']
 $providername = $request['ProviderName']
 $providertype = $request['ProviderType']
 $machinekeyset = $request['MachineKeySet']
 $friendlyName = $request['FriendlyName']


#########################
# Create the settings.inf
#########################
$settingsInf = "
[Version] 
Signature=`"`$Windows NT`$ 
[NewRequest] 
FriendlyName = $FriendlyName
KeyLength =  2048
Exportable = $exportable 
MachineKeySet = $machinekeyset 
SMIME = FALSE
RequestType =  PKCS10 
ProviderName = `"$providername`" 
ProviderType =  $providertype
HashAlgorithm = sha256
;Variables
Subject = `"CN={{CN}},OU={{OU}},O={{O}},L={{L}},S={{S}},C={{C}}`"
[Extensions]
{{SAN}}
"
$request['SAN_string'] = & {
	if ($request['SAN'].Count -gt 0) {
		$san = "2.5.29.17 = `"{text}`"
"
		Foreach ($sanItem In $request['SAN'].Values) {
			$san += "_continue_ = `"dns="+$sanItem+"&`"
"
		}
		return $san
	}
}

$settingsInf = $settingsInf.Replace("{{CN}}",$request['CN']).Replace("{{O}}",$request['O']).Replace("{{OU}}",$request['OU']).Replace("{{L}}",$request['L']).Replace("{{S}}",$request['S']).Replace("{{C}}",$request['C']).Replace("{{SAN}}",$request['SAN_string'])

# Save settings to file
$settingsInf > $files['settings']

# Done, we can start with the CSR
Clear-Host

#################################
# CSR TIME
#################################

# Display summary
Write-Host "Certificate information
Common name: $($request['CN'])
Organisation: $($request['O'])
Organisational unit: $($request['OU'])
City: $($request['L'])
State: $($request['S'])
Country: $($request['C'])
Subject alternative name(s): $($request['SAN'].Values -join ", ")
Signature algorithm: SHA256
Key algorithm: RSA
Key size: 2048
" -ForegroundColor Yellow

certreq -new $files['settings'] $files['csr'] > $null

# Output the CSR
$CSR = Get-Content $files['csr']
Write-Output $CSR
Write-Host "
"

Write-Host File $files['csr'] is created
# Set the Clipboard (Optional)
Write-Host "Copy CSR to clipboard? (y|n): " -ForegroundColor Yellow -NoNewline
if ((Read-Host) -ieq "y") {
	$csr | clip
	Write-Host "Check your ctrl+v
"
}

########################
# Remove temporary files
########################
Remove-Item $files['settings']
}
else 
{write-host "file $WebSiteName.txt doesn't exist, check website name"}