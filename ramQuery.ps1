#queries a list of servers from a hard coded filename to find out how much RAM is installed in each

$output = @()
$cred = get-credential

$csv = get-content ".\1ksvr.csv"
	foreach($line in $csv){
		"querying: $line"
		$row = New-object PSObject
		try{
			$byte = (get-wmiobject win32_physicalmemory -computername $line -credential $cred -erroraction Stop).capacity#wmi call pulls number of bytes

			$mega = [decimal]::round($byte / 1048576)#conversion to megabytes, not all servers have at least a gig
			$row | add-member -membertype noteproperty -name "server" -value $line
			$row | add-member -membertype noteproperty -name "physical memory" -value $mega

		}
		catch{
			if(test-connection -computername $line -quiet){
				$status = "RPC error - server online"
			}
			elseif (!(test-connection -computername $line -quiet)){
				$status = "server offline"
			}
			else{
				$status = "error"
			}
			
			$row | add-member -membertype noteproperty -name "server" -value $line
			$row | add-member -membertype noteproperty -name "physical memory" -value $status

			write-host "error: going to next object" -foregroundcolor red
		}
		Finally{
			$output += $row
		}		
	}

$output | export-csv -path ".\serversRAM.csv" -notypeinformation
		