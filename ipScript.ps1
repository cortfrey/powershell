#simple script designed to get the ip addresses of a list of servers.

$fileIn = read-host "Filename of server list (local to this directory)"#read in file

$list = get-content $filein

foreach($line in $list){
	try{#tries the connection, if it passes it exports/appends the desired information to a csv file
		"Testing $line"
		
		test-connection $line -count 1 -erroraction Stop |select-object -property Address, IPV4Address | export-csv ".\ipaddr.csv" -append
		"Next server"
	}
	Catch{#if it fails, it fills in default information and appends the file.
		[System.Net.NetworkInformation.PingException]
		"error"
		$row = new-object PSObject
		$row | add-member -membertype noteProperty -name "Address" -value "$line"
		$row | add-member -membertype noteproperty -name "IPV4Address" -value "ERROR"
		$row | export-csv ipaddr.csv -notypeinformation -append
	}
	Finally{}
}

	
