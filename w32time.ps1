#checks a list of servers from a hardcoded file and checks the w32time service
#tries to set the service to automatic start, and start the service.
#this can be easily adapted to other services
#writes results to file to check results later

$output = @()							#array used to output to csv

$csv = get-content .\w32TSvr.csv		#reads list of servers here
	foreach($line in $csv){				#main loop
		"Attempting: $line"
		$row = New-object PSObject		#will be written to the output array
		try{																						#tries to perform below actions
			set-service -name w32time -computername $line -startuptype automatic -erroraction stop	#set the service to auto start
			"w32Time set to automatic start"
			set-service -name w32time -computername $line -status running -erroraction stop			#start service
			"w32Time started"
			
			$row | add-member -membertype noteproperty -name "server" -value $line					#server name written to object
			$row | add-member -membertype noteproperty -name "status" -value "Started"				#results of operation written to object
		}
		catch{																						#inserts default values to the object if the setting changes fail
			$row | add-member -membertype noteproperty -name "server" -value $line
			$row | add-member -membertype noteproperty -name "status" -value "not started"
			write-host "error: going to next object" -foregroundcolor red
		}
		Finally{
			$output += $row																			#writes object to array
		}		
	}

$output | export-csv -path ".\w32TInfo.csv" -notypeinformation										#writes array/results to file