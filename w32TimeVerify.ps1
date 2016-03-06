#verifies that the servers contact have been receiving network time
#needs fixin

$output = @()							#array to hold results, will be written to file
$csv = get-content .\w32TSvr.csv		#hardcoded list of servers to be checked

	foreach($line in $csv){				#main loop, cycles through the list of servers
		"Attempting: $line"
		$row = New-object PSObject		#new object to store results
		if (get-eventlog -logname system -computername $line -newest 100 | where {($_.eventID -eq 35) -or ($_.eventID -eq 37)})	#if event ID 35 or 37 are present
			get-eventlog -logname system -computername $line -newest 100 | where {($_.eventID -eq 35) -or ($_.eventID -eq 37)} | `	#adds entry to the csv file
			export-csv "w32TimeVerify.csv" -append -notypeinformation #wrapped from previous line
		}
		else{
			$row | add-member -membertype noteproperty -name "MachineName" -value $line					#builds default line for file
			$row | add-member -membertype noteproperty -name "Message" -value "unable to read log"
			write-host "error: going to next object" -foregroundcolor red
			$output += $row																				#adds default line to output array
			$output | export-csv -path "w32TimeVerify.csv" -append -notypeinformation					#appends to file
		}
	}