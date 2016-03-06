#simple script to find services that are hung on a remote server during stopping and then find their process and attempt to force it to stop
#script is best run in a slightly modified local version where PStools are present on the system allowing the use of pskill.exe
#note that in order to use the remote version, it requires WinRM to be enabled to use the invoke-command cmdlet
#requires -version 2.0

#UNFINISHED: credential intake for remote servers

$svrName = ""		#stores server name
$svrNameFlag = 0	#used to validate $svrName input
$hungSVCs = @()		#array of hung services in case of multiples
$svcPID = ""		#used to store Process ID of hung processes
$localOrRem = 0		#used to store user choice for local or remote usage
$localRemFlag = 0	#used in validation of $localOrRem input
$choice = 0			#holds choice to kill processes or not
$choiceFlag = 0		#used to validate user input for $choice variable

function test-port{
	param(
		[string] $srv,
		$port = 47001,
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


#prompts the user to find out if they want to run the script against a local or remote machine, validates input.
do{
	$localOrRem = read-host "Would you like to run this on a local or remote server? [1]Local, [2]Remote"
	if($localOrRem -ne 1 -and $localOrRem -ne 2){
		write-host "invalid input, please enter '1' or '2'"
	}
	else{
		$localRemFlag = 1
	}
}until($localRemFlag -eq 1)

#this block is for use against local comptuers
if($localorRem -eq 1){

	$hungSVCs = Get-Service  | where { $_.Status -eq 'StopPending' }#find service that is hung

	#in case there are no hung services, just exits script
	if($hungSVCs.length -eq 0){
		write-host "unable to find any hung services, exiting script."
		exit
	}

	#informational
	write-host "The following services are hung:"
	$hungSVCs 
	write-host "Would you like to stop their processes?"

	#do-until to take in user choice to stop processes or not, only works with a response of '1' or '2'
	do{
		$choice = read-host "[1]Yes, [2]No"
		if($choice -ne 1 -and $choice -ne 2){
			write-host "invalid input, please enter '1' or '2'"
		}
		else{
			$choiceFlag = 1
		}
	}until($choiceFlag -eq 1)

	#if the user decides to stop the processes, loops through each, finds the PID and attempts to use invoke-command to kill the process
	#if the user chose not to to end processes, it ends the script
	if($choice -eq 1){
		Foreach($svc in $hungSVCs){
			$svcPID = (get-wmiobject win32_Service  | Where { $_.Name -eq $ServiceName.Name }).ProcessID#finds the process ID
			write-host "Attempting to stop process ID $svcPID for service $svc" 
			Stop-Process $ServicePID
		}
	}
	else{
		write-host "exiting script"
		exit
	}
}

#this block is for use against remote computers
if($localOrRem -eq 2){
	
	#takes in server name and attempts to test the connection to it
	#if the connection fails, it will prompt for the server name again and give an otherwise hidden exit option
	do{
		$svrName = read-host 'Please Enter Name of Server with Hung Service:'#get server name
		if(test-connection -count 1 -quiet $svrName){
			$svrNameFlag = 1
		}
		elseif($svrName -eq "exit"){
			exit
		}
		else{
			"unable to connect to server, please input a valid name or enter 'exit' to exit the script."
		}
	}until($svrNameFlag -eq 1)
	
	$p = test-port($line)#the server pinged so it tests the WinRM port to see if it is available
	if($p){#the port is available, script continues
		$hungSVCs = Get-Service -computername $svrName | where { $_.Status -eq 'StopPending' }#find service that is hung

		#in case there are no hung services, just exits script
		if($hungSVCs.length -eq 0){
			write-host "unable to find any hung services, exiting script."
			exit
		}

		#informational
		write-host "The following services are hung:"
		$hungSVCs 
		write-host "Would you like to stop their processes?"

		#do-until to take in user choice to stop processes or not, only works with a response of '1' or '2'
		do{
			$choice = read-host "[1]Yes, [2]No"
			if($choice -ne 1 -and $choice -ne 2){
				write-host "invalid input, please enter '1' or '2'"
			}
			else{
				$choiceFlag = 1
			}
		}until($choiceFlag -eq 1)

		#if the user decides to stop the processes, loops through each, finds the PID and attempts to use invoke-command to kill the process
		#if the user chose not to to end processes, it ends the script
		if($choice -eq 1){
			Foreach($svc in $hungSVCs){
				$svcPID = (get-wmiobject win32_Service -computername $svrName | Where { $_.Name -eq $ServiceName.Name }).ProcessID#finds the process ID
				write-host "Attempting to stop process ID $svcPID for service $svc" 
				Invoke-Command -computername $svrName {Stop-Process $ServicePID}
			}
		}
		else{
			write-host "exiting script"
			exit
		}
	}
	else{
		write-host "WinRM port unavailable, unable to use the Invoke-Command cmdlet, exiting script"
	}
}