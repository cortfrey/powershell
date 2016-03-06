#currently untested
#able to query a single or list of servers, and search for logged on user sessions for a provided username.
#once they have been found, it will prompt you to see if you want them removed.
#it will log results to a file.

#Variables
#note that the 'q' in below variables indicates a value to be queried.  
$svrFlag = 1		#if set to 0, indicates that the server has been "found"
$typeFlag = 1		#if set to 0, indicates that a user has selected a type of query, and the server/server list file path has validated
$pathFlag = 1		#if set to 0, indicates that the path to a file provided by the user has validated.
$logoffFlag = 1		#if set to 0, indicates user has provided a valid input at the logoff prompt
$qServer = ""		#user will provide a server name that will populate this variable
$qPath = ""			#user will provide a file path that will populate this variable
$qType = ""			#user will provide a integer indicating the type of query they wish to perform that will populate this variable
$serverList = ""	#result of running a get-content on the file provided by user
$username = ""		#user will provide user name they should be querying for.
$output = @()		#array that will be eventually written to file and used for logging.
$loggedOnSvr = @()	#array containing a list of all servers a user is logged in on


do{#prompts user for type of query (single server or list) and then validates the filepath, or the single server via test-path, and test-connection, respectively.
	$qtype = read-host "Query a Single Server [1] or a list of servers [2]?"
	if($qtype -eq 1){
		do{#user has selected single server, it will prompt for name, then attempt to connect to the server, it will loop until it received a valid server/connection
			$qServer = read-host "Please enter the server name that you wish to query"
			if((test-connection $qServer -count 1 -q)){
				write-host "server found"
				$serverList = $qServer			#assigns server to variable that will be looped through later
				$typeFlag = 0					#query type chosen
				$svrFlag = 0					#server tests fine
			}
			else{
				write-host "server not found"
			}
		}until($svrFlag -eq 0)					#server is valid, exits loop
	}		
	else if($qType -eq 2){
		do{#user has selected list of servers, it will prompt for file name, then attempt verify the file exists, it will loop until it is provided and finds a valid file.
			$qpath = "Please enter a valid file path, starting with the drive letter"
			if (test-path $qPath){
				write-host "path found"
				$serverList = get-content $qPath#pulls list of servers from provided file.
				$pathFlag = 0					#file exists
				$typeFlag = 0					#query type chosen
			}
			else{
				write-host "path not found"
			}		
		}until($pathFlag -eq 0)					#path is valid, exits loop
	}
	else{
		write-host "Invalid input, please re-enter your response with either a '1' or a '2'"
	}
}until($typeFlag -eq 0)							#correct query type chosen, exits loop.

$username = read-host "Please Enter the username you wish to query for"#this will be the SINGLE username you query for

ForEach ($server in $serverlist){				#iterates through the list of servers provided
    $obj = new-object psobject					#this object will store the results
    write-host $server -foregroundcolor yellow
    $session = quser /server:$server			#pulls a list of active user sessions on the server

    foreach($user in $session){					#iterates through list of users and attempts to match the user name to the list of sessions
        if($user -match "$username"){
            $user
			$obj | add-member -MemberType NoteProperty -name "server" -value $server
			$loggedOnSvr += $server				#establishes a list of servers that the user is logged in on
        }
    }    
    $output += $obj
}
write-host "The following sessions have been found"
$output

#once the list of active sessions is found, this gives you the option to attempt a remote log off of each session
#validates user input
do{
	$qlogoff = read-host "Do you wish to log off these sessions? Yes[1] No[2]"
	if($qLogoff -eq 1){
		foreach($server in $loggedOnSvr){	
			logoff $user /server:$server		#iterates through servers the user is logged in on and attempt to log off
		}
		$logoffFlag = 0
		write-host "Sessions have been logged off.  Query results will be written to file"
	}
	else if($qLogoff -eq 2){
		write-host "Sessions have NOT been logged off.  Query results will be written to file"
		$logoffFlag = 0
	}
	else{
		write-host "Please re-enter your response with either a '1' or a '2'"
	}
}until($logoffFlag -eq 0)

$output | export-csv -path .\userSessionReport.csv -notypeinformation
write-host "Query results have been written to file at the location of this script."