############################################################
#mgmUtilitiesInstall.ps1                                   #
#Version 1.1                                               #
#Powershell version 3.0                                    #
#                                                          #
#Purpose: Installs Symantec Endpoint Protection,           #
#Microsoft SCCM 2007, and Microsoft SCOM 2007              #
#                                                          #
#Author: Cort Frey                                         #
#Date:10/22/14                                             #
#                                                          #
############################################################


#####User-based input#####
#take in the user credentials for accessing the network shares
"Please enter your credentials for the session including the domain."
$cred = Get-Credential


#####OS Architecture Check#####
# retrieve and check OS architecture version, store result in $arch
"Retrieving OS Architecture"
$os = get-wmiobject -class "Win32_OperatingSystem" -namespace "root\CIMV2"
 if ($os.OSArchitecture -eq "64-bit"){
  $arch = 64
 } 
 else{
  $arch = 32
 } 
 $os.OSArchitecture
 

#####UNC Paths######
#UNC paths to the installation files
#THESE MUST UPDATED IF OLD INSTALLATION MEDIA IS UPDATED

#Anti-virus paths
$AV_32_Path = "AV:\[path to folder containing installation package/exe/script]\"
$AV_64_Path = "AV:\[path to folder containing installation package/exe/script]\"

#SCCM paths
$sccm_path = "SCCM:\[path to folder containing installation package/exe/script]\"

#SCOM paths
$scom_32_path = "SCOM:\[path to folder containing installation package/exe/script]\"
$scom_64_path = "SCOM:\[path to folder containing installation package/exe/script]\"


#####LOCAL PATHS#####
#required local paths
$temp = "C:\Temp\"


#####Map PSDrives#####
#Mounts PSDrives using the given credentials to access the installation files
"Mounting PSDrives"
New-PSDrive -name AV -PSProvider FileSystem -root \\[serverName]\[root directory for above file paths] -credential $cred
New-PSDrive -name SCCM -PSProvider FileSystem -root \\[serverName]\[root directory for above file paths] -credential $cred
New-PSDrive -name SCOM -PSProvider FileSystem -root \\[serverName]\[root directory for above file paths] -credential $cred
"Mounting Complete"


#####COPYING#####
#this section copies installation files to the computer
"Beginning of copying Installation Files"

#Antivirus block
"Beginning Anti-Virus"
if ($arch -eq 32) {copy-item -path $AV_32_Path"setup.exe" -destination $temp -recurse}
	else {copy-item -path $AV_64_Path"setup.exe" -destination $temp -recurse}
#end if
"Anti-Virus completed"

#SCCM Block
"Beginning SCCM"
if ($arch -eq 32){
	copy-item -path $sccm_path"x64" -destination $temp"\client\x64" -recurse}
	else{
	copy-item -path $sccm_path"xi386" -destination $temp"\client\x64" -recurse}
#end if
copy-item -path $sccm_path"ccmsetup.exe" -destination $temp"\client"
copy-item -path $sccm_path"ccmsetup.cab" -destination $temp"\client"
copy-item -path $sccm_path"R01InstallScript.bat" -destination $temp"\client"
"SCCM Completed"

#SCOM Block
"Beginning SCOM"
if ($arch -eq 32) {copy-item -path $scom_32_Path -destination $temp -recurse}
	else {copy-item -path $scom_64_Path -destination $temp -recurse}
#end if
"SCOM Completed"

"Copying of Installation Files completed"
	

#####INSTALLATION#####
#this section runs the installation files for each application
"Beginning Installation"

#start AV
"Starting Anti-Virus Installation"
Start-Process -path "C:\Temp\[containing folder from above path]\setup.exe" -NoNewWindow -wait
"Anti-Virus Installation Completed"

#start SCCM
"Starting SCCM Installation"
Start-Process "cmd.exe" "/c C:\Temp\[containing folder from above path]\r01InstallScript.bat"
Wait-process  -name "ccmsetup.exe"
"SCCM Installation Completed"

#start SCOM
"Starting SCOM Installation"
if ($arch -eq 32) {Start-Process "cmd.exe" "/c msiexec.exe /i C:\Temp\x86\MOMAgent.msi /qn INSTALLDIR=%Program Files%\System Center Operations Manager 2007\ CONFIG_GROUP='SCOM' MANAGEMENT_SERVER='[FQDN Server name]' SECURE_PORT='[PORT]'"
}
	else {Start-Process "cmd.exe" "/c msiexec.exe /i C:\Temp\x64\MOMAgent.msi /qn INSTALLDIR=%Program Files%\System Center Operations Manager 2007\ CONFIG_GROUP='SCOM' MANAGEMENT_SERVER='[FQDN Server name]' SECURE_PORT='[PORT]'"
	}
Wait-process -name "msiexec.exe"
"SCOM Installation Completed"


######Clean Up######
#unmounts PSDrives and removes installation files

#remove PSDrives
"Removing Mounted Drives"
Remove-PSDrive -name AV -force
Remove-PSDrive -name SCCM -force
Remove-PSDrive -name SCOM -force
"Removal of Mounted Drives Complete"

#remove files from C:\Temp
"Removing Installation Files"
remove-item -path "C:\Temp\[containing folder from above path]\" -force
remove-item -path "C:\Temp\[containing folder from above path]\" -force
remove-item -path "C:\Temp\[containing folder from above path]\" -force
"Installation Files Removed"

"End of Script"