$status = (gsv -name "winmgmt" -computername $line).status

$output = @()
$cred = get-credential

$csv = get-content ".\1ksvr.csv"
	foreach($line in $csv){
		"querying: $line"
		$row = New-object PSObject
		try{
			$status = (gsv -name "winmgmt" -computername $line -credential $cred -erroraction Stop).status

			$row | add-member -membertype noteproperty -name "server" -value $line
			$row | add-member -membertype noteproperty -name "status" -value $status

		}
		catch{
			if(test-connection -computername $line -quiet){
				$status = "RPC error - server online"
			}
			elseif (!(test-connection -computername $line -quiet)){
				$status = "server offline"
			}
			else{
				$status = "error, cannot verify"
			}
			
			$row | add-member -membertype noteproperty -name "server" -value $line
			$row | add-member -membertype noteproperty -name "status" -value $status

			write-host "error: going to next object" -foregroundcolor red
		}
		Finally{
			$output += $row
		}		
	}

$output | export-csv -path ".\wmiStatus.csv" -notypeinformation