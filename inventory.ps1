################################################################
#inventory.ps1                                                #
#formerly comboQuery.ps1                                       #
#Version 4                                                     #
#Powershell version 3.1                                        #
#                                                              #
#Purpose: Given a CSV File pulls:                              #
#OS, Enclosure model/manufacturer/serial, IP,		           #
#install date, and determines type/function/location of server #             
#based on naming conventions								   #                                                   
#Author: Cort Frey                                             #
#Date:2/2/15                                                   #
#added functionality for file validation, AD validation		   #
#and non-harcoded file paths                                   #
#domain currently non functional							   #
################################################################


$output = @()
$fileIn = ""
$fileOut = ""
$csv = ""

############################################
#################Functions##################
############################################



#function test-port:
#tests the target server to see if the RPC port is available
function test-port{
	param(
		[string] $srv,
		$port = 135,
		$timeout=3000,
		[switch]$verbose
		)
	$errorActionPreference = "silentlycontinue"
	$tcpclient = new-object system.net.sockets.tcpclient
	$iar = $tcpclient.beginconnect($srv, $port, $null, $null)
	$wait = $iar.asyncwaithandle.waitone($timeout, $false)
	if(!$wait){
		$tcpclient.close()
		if($verbose){
			write-host Connection Timeout
			}
		return $false
	}
	else{
		$error.clear()
		$tcpclient.endconnect($iar)|out-null
		if(!$?){
			if($verbose){
				write-host $error[0]
			}
			$failed = $true
		}
		$tcpclient.close()
	}
	if($failed){
		return $false
	}
	else{
		return $true
	}
}

#function getType
#based on the server name, determines the type of the server
function getType{
	param(
		[string]$srv
	)
		switch -wildcard ($srv){
			[switch parameters]
		#embedded switch based on a match{switch -wildcard($line){
				[embedded switch parameters]	
			}
		}default{$type = "manual check"}
	}
	return $type
}

#function getLocation
#based on the server name, determines the location of the server
function getLocation{
	param(
		[string]$srv
	)
	switch -wildcard ($line){#server location
		[switch parameters]
		default{$location = "Manual Check"}
	}
	return $location
}

#function getFunction
#based on the server name, determines the general business function of the server
function getFunction{
	param(
		[string]$srv
	)
	switch -wildcard ($line){#server function
		[switch parameters]
		default{$function = "Manual Check"}		
	}
	return $function
}

#function getManufacturer
#connects to the server via RPC to query WMI for manufacturer information
function getManufacturer{
	param(
		[string]$srv
	)
	try{
		$WMIQuery = get-wmiobject win32_systemenclosure -computername $srv -AsJob
		wait-job -ID $WMIQuery.ID -timeout 20
		$manu = receive-job $WMIQuery.ID
		write-host "manufactuer success" -foregroundcolor white
		return $manu
	}
	catch{
		write-host "manufacturer error" -foregroundcolor red
		$manu = "ERROR"
		return $manu
	}
}

#function getSerial
#connects to the server via RPC to query WMI for serial information for the physical enclosure.
#virtual machines will also return their own serial, even without a physical enclosure
#blade servers will, in some cases return the serial of the blade enclosure
function getSerial{
	param(
		[string]$srv
	)
	try{
		$WMIQuery = get-wmiobject win32_systemenclosure -computername $srv -AsJob
		wait-job -ID $WMIQuery.ID -timeout 20
		$serialnum = receive-job $WMIQuery.ID
		write-host "serial success" -foregroundcolor white
		return $serialnum
	}
	catch{
		write-host "serial error" -foregroundcolor red
		$serialnum = "ERROR"
		return $serialnum
	}
}

#function getOS
#connects to the server via RPC to query WMI for Operating System information
function getOS{
	param(
		[string]$srv
	)
	try{
		$WMIQuery = get-wmiobject win32_operatingsystem -computername $srv -AsJob
		wait-job -ID $WMIQuery.ID -timeout 20
		$OSversion = receive-job $WMIQuery.ID
		write-host "OS success" -foregroundcolor white		
		return $OSversion
	}
	catch{
		write-host "OS error" -foregroundcolor red
		$OSversion = "ERROR"
		return $OSversion
	}
}

#function getInstallDate
#connects to the server via RPC to query WMI for the installation date of the OS
function getInstallDate{
	param(
		[string]$srv
	)
	try{
		$WMIQuery = get-wmiobject win32_operatingsystem -computername $srv -AsJob
		wait-job -ID $WMIQuery.ID -timeout 20
		$rawDate = receive-job $WMIQuery.ID
		write-host "Install Date success" -foregroundcolor white
		return $rawDate
	}
	catch{
		write-host "Install Date error" -foregroundcolor red
		$date ="ERROR"
		return $date
	}
}

#function getIP
#uses DNS to get the IP address of the target server
function getIP{
	param(
		[string]$srv
	)
	$addr = [System.Net.Dns]::GetHostAddresses($srv)
	
	if($addr -ne $null){
		write-host "dns/ip success" -foregroundcolor white
		return $addr
	}
	else{
		write-host "dns/ip error" -foregroundcolor red
		$addr = "error - host unknown"
		return $addr
	}
}

function getDomain{#currently not working
	param(
		[string]$srv
	)
	try{
		$WMIQuery = get-wmiobject win32_NTDomain -computername $srv -AsJob
		wait-job -ID $WMIQuery.ID -timeout 20
		$domain = receive-job $WMIQuery.ID
		write-host "Domain success" -foregroundcolor white		
		return $domain
	}
	catch{
		write-host "OS error" -foregroundcolor red
		$domain = "ERROR"
		return $domain
	}
}

#function getModel
#connects to the server via RPC to query WMI for model information
function getModel{
	param(
		[string]$srv
	)
	try{
		$WMIQuery = get-wmiobject win32_computersystem -computername $srv -AsJob
		wait-job -ID $WMIQuery.ID -timeout 20
		$model = receive-job $WMIQuery.ID
		write-host "model success" -foregroundcolor white
		return $temp
	}
	catch{
		write-host "mmodel error" -foregroundcolor red
		$manu = "ERROR"
		return $model
	}
}



############################################
####################MAIN####################
############################################

#ad validation
#this section will prompt for AD credentials and then attempt to validate them
#the do-until loop will repeat this process until it validates
do{
	$user = read-host 'Please Enter your user account in the form of DOMAIN\USERNAME.'
	$pass = read-host 'Please Enter your password' -assecurestring
	$cred = New-Object System.Management.Automation.PSCredential ($user, $pass)

	$username = $cred.username 
	$password = $cred.GetNetworkCredential().password  

	$CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName 
	$dom = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$username,$password) 
	$res = $dom.name 

	if ($res -eq $null)
	{ 
		write-host "Failed to authenticate. Make sure that you have supplied correct username and password." -foregroundcolor red
	}else{ 
		write-host "Successfully authenticated and connect to domain $($res)"
	}
}
until(!($res -eq $null))

#file Validation
#takes in a file path and tests to see if it exists.
#if it does exist, tests to see if it is a CSV or TXT file
#if it failes either test, it prompts for a correct file path/name
do{
	$flag1 = 0
	$flag2 = 0
	$fileIn = read-host 'Please Enter the Path of the file you wish to query results for'
	if(!(test-path $fileIn)){
		do{write-host "File Path does not exist." -foregroundcolor red
			$fileIn = read-host 'Please enter a valid file path'
		}
		until(test-path $fileIn)
	}
	$flag1 = 1

	$temp = $fileIn.split('.')#validate input file type
	if((!($temp[-1] -eq "csv")) -and (!($temp[-1] -eq "txt"))){
		write-host "Incorrect File Type, please use a .csv or .txt file" -foregroundcolor red
	}
	else{
		$flag2 = 1
	}
}
until(($flag1 -eq 1) -and ($flag2 -eq 1))

#takes in a filename from the user for results to be placed in
$fileOut = read-host 'Please enter the name of the file you want your results to be placed in'

#reads in a list of servers from the user supplied file
$csv = get-content $fileIn

#primary foreach loop.
#loops through each line of the user provided file and queries each server for a set of data 
#and stores the data in a hash.  The hash is then looped through and each key-value pair 
#is used to construct a custom powershell object.  The Key becomes the Property name,
#and the Value becomes the Propery value.  These objects are then added to an array
foreach($line in $csv){
	"querying $line"
	
	#initialization of hash
	$hash =[ordered]@{"Server" = $line; "Type" = ""; "Function" = ""; "OS" = ""; "IP" = ""; "Model" = "";` 
	"Manufacturer" = ""; "Serial" = ""; "Location" = ""; "InstallDate" = ""; "Domain" = ""}
	
	#initialization of PSObject
	$row = New-object PSObject
	
	
	if(test-connection -computername $line -quiet -count 1){#tests to see if the server can be pinged
		$p = test-port($line)#the server pinged so it tests the RPC port to see if it is available
		if($p){#the port is available, so it uses the functions to query the server and populate the hash
			write-host "port test passed" -foregroundcolor white
			$hash.server = $line
			$hash.Type = getType($line)
			$hash.Function = getFunction($line)
			$hash.os = (getOS($line)).caption
			
			#$hash.IP = (getIP($line)).ipaddresstostring
			$tempIP = (getIP($line)).ipaddresstostring
			$hash.ip = "SLH=$tempIP"
			
			$hash.Model = (getModel($line)).model
			$hash.Manufacturer = (getManufacturer($line)).manufacturer
			$hash.Serial = (getSerial($line)).serialnumber
			$hash.Location = getLocation($line)			
			$dateToConvert = (getInstallDate($line)).installdate
			$hash.domain = (getDomain($line)).domain
			
			#conversion of the raw date/time format to a readable one, which is then added to the hash
			$month = (([WMI]'').converttodatetime($dateToConvert)).month
			$day = (([WMI]'').converttodatetime($dateToConvert)).day
			$year = (([WMI]'').converttodatetime($dateToConvert)).year
			$date = "$month/$day/$year"
			$hash.InstallDate = $date			
			
			write-host "queries completed" -foregroundcolor yellow
		}
		else{#the port test fails, all fields which required an RPC connection are filled with an error,
			#the rest are queried
			write-host "port test failed" -foregroundcolor red
			$hash.server = $line
			$hash.Type = getType($line)
			$hash.Function = getFunction($line)
			$hash.os = "RPC error"
			
			#$hash.IP = (getIP($line)).ipaddresstostring
			$tempIP = (getIP($line)).ipaddresstostring
			$hash.ip = "SLH=$tempIP"
			
			$hash.Model = "RPC error"
			$hash.Manufacturer = "RPC error"
			$hash.Serial = "RPC error"
			$hash.Location = getLocation($line)
			$hash.InstallDate = "RPC error"
			$hash.domain = "RPC Error"
		}
		
		#loops through the hash to added each key/value pair to the object
		$hash.getEnumerator() | foreach-object{$row | add-member -membertype noteproperty -name $_.key -value $_.value}

		#adds the object to an array
		$output += $row
	}
	else{#the ping to the server fails, some values are given a default value, some can still be determined
		write-host "Could not ping $line" -foregroundcolor red
		$hash.server = $line
		$hash.Type = getType($line)
		$hash.Function = getFunction($line)
		$hash.os = "Error: Server Unreachable"
		$hash.IP = "Error: Server Unreachable"
		$hash.Model = "Error: Server Unreachable"
		$hash.Manufacturer = "Error: Server Unreachable"
		$hash.Serial = "Error: Server Unreachable"
		$hash.Location = getLocation($line)
		$hash.InstallDate = "Error: Server Unreachable"	
		$hash.domain = "Error: Server Unreachable"
		
		#loops through the hash to added each key/value pair to the object
		$hash.getEnumerator() | foreach-object{$row | add-member -membertype noteproperty -name $_.key -value $_.value}
		
		#adds the object to an array
		$output += $row
	}		
}

#beginning of the file writing section
#sets a flag to 0.  if the flag is zero, the write was successful.  if it fails to write, the flag is set to 1
#when the flag is set to 1, it triggers an if loop with a nested do-until loop promptng for a new save location
#it tries to write and if it fails, it prompts again, until it succeeds 
$flag1 = 0
try{
	$output | export-csv -path "$fileOut" -notypeinformation
	$flag1 = 0
}
catch{
	write-host "Access Denied Error" -foregroundcolor red
	$flag1 = 1
}
if($flag1 -eq 1){
	do{
		$outPath = read-host 'Please enter a valid save location that you have permission to write to'
	
		try{
			$output | export-csv -path "$outpath\$fileout" -notypeinformation -erroraction stop
				
			test-path "$outpath\$fileout"
		}
		catch{
			write-host "Access Denied Error" -foregroundcolor red
			test-path "$outpath\$fileout"
		}
	}
	until(test-path "$outpath\$fileout")
}	
"Script Complete, the output file has been placed in your current working directory"