#simple script that cycles through a list of servers and checks to see if 
#the services are running to verify if a product is installed
#more services can be added, or removed as needed
#[FILE] should be the hardcoded file

$output = @()				#will be written to file later
$input = @()				#contains contents of in file

$input = get-content [FILE]	#hardcoded value for file containing list of servers

#loops through the list of servers and first tests if they are online and then to see if the services are running
foreach($svr in $input){
	"querying: $svr"
	$obj = new-object psobject																		#custom object, will be added to array to be written
	$obj | add-member -membertype noteproperty -name "server" -value $svr							#adds server to object
	if(test-connection $svr -count 1 -quiet){														#pings server, if true, continues, if false, skips services and goes to next iteration
		if(get-service "[service1]" -computername $svr){											#tests to see if the first service is present or not and adds values to the object as appropriate
			write-host "[service1] pass" -foregroundcolor white		
			$obj | add-member -membertype noteproperty -name "[service1]" -value "installed"
		}
		else{
			write-host "[service1] fail" -foregroundcolor yellow	
			$obj | add-member -membertype noteproperty -name "[service1]" -value "not installed"
		}
		if(get-service "[service2]" -computername $svr){											#tests to see if the second service is present or not and adds values to the object as appropriate
			write-host "[service2] pass" -foregroundcolor white			
			$obj | add-member -membertype noteproperty -name "[service2]" -value "installed"
		}
		else{
			write-host "[service2] fail" -foregroundcolor yellow
			$obj | add-member -membertype noteproperty -name "[service2]" -value "not installed"
		}
	}
	else{																							#default values if the ping fails
		$obj | add-member -membertype noteproperty -name "[service1]" -value "offline"
		$obj | add-member -membertype noteproperty -name "[service2]" -value "offline"
	}
	$output += $obj																					#add object to the array for later file writing
}

$output | export-csv -path "C:\temp\voeInfo.csv" -notypeinformation									#exports results to csv

