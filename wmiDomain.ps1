$output = @()
$cred = get-credential
$path = read-host 'Input File:'

$csv = get-content ".\$path"
	foreach($line in $csv){
		"querying: $line"
		$row = New-object PSObject
		try{

			$dom = (get-wmiobject win32_computersystem -computername $line -credential $cred -erroraction Stop).domain
			
			$row | add-member -membertype noteproperty -name "server" -value $line
			$row | add-member -membertype noteproperty -name "manufacturer" -value $dom
		}
		catch{
			$row | add-member -membertype noteproperty -name "server" -value $line
			$row | add-member -membertype noteproperty -name "manufacturer" -value "ERROR"
			write-host "error: going to next object" -foregroundcolor red
		}
		Finally{
			$output += $row
		}		
	}

$output | export-csv -path "C:\temp\serversDomainInfo.csv" -notypeinformation
		