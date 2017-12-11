###########################################################
#subnetScan.ps1
#author:    Cort Frey
#date:      11-3-17
#version:   1.0
#Purpose:   given a subnet and a lower and upper bound
#           scans the range and returns a list of all 
#           IPs in the range, and if they respond to
#           a single ping.  Validates all input.
#           Only works for class C subnets (255.255.255.X)
#usage:     from command line: subnetScan.ps1
###########################################################          

#variables
$subnet = ""            #holds the subnet
$subnetFlag = 0         #used to exit the subnet validation loop
$addresses = @()        #holds the query results
$start = ""             #lower end of the IP range
$startFlag = 0          #used to exit the range start validation loop
$stop = ""              #upper end of the IP range
$stopFlag = 0           #used to exit the range end validation loop
$rangeFlag = 0          #used to exit the overall range validaton loop
$fileOut = ""           #stores the desired file name
$fileFlag = 0           #used to exit the file writing loop in case of an error
$validValues = @(0..255)#valid octet values

#subnet validation loop, requires the '.' between the 3rd and 4th octets
#this loop is set to pass initially, failing any test changes the flag and cycles the loop
do{
    $subnetFlag = 1    
    $subnet = read-host "please enter a valid subnet, including the '.' at the end, ex: '1.2.3.'"
    $subnetValidation = $subnet.split('.')          #split the address into it's octets

    if($subnetValidation.length -lt 4){             #checks for the length of the array, the lenth of 4 is because a 4th index is registered when splitting the last period
            if($subnetValidation.lenth -eq 3){      #checks to see if the final '.' is missing, this will happen when there are only 3 octets
                write-host "Final '.' missing, please re-enter" -ForegroundColor Yellow
                $subnetFlag = 0
                continue
            }
            else{                                   #all other numbers of octets are wrong
                write-host "Invalid number of octets, please re-enter" -ForegroundColor Yellow
                $subnetFlag = 0
                continue
            }
    }
    elseif($subnetValidation[3] -ne ""){            #makes sure that the 4th octet is left empty, ex: 255.255.255.255 is the correct length, but the last octet is not empty
        write-host "Please leave the last octet empty, including spaces" -ForegroundColor Yellow
        $subnetFlag = 0
        continue
    }
    foreach($octet in $subnetValidation){           #verifies that the values for each octet lie within a range of possible values
        if(!($validValues -contains $octet)){
            write-host "$octet is an invalid value, please enter a valid octet" -ForegroundColor Yellow
            $subnetFlag = 0
            continue
        }
    }
}until($subnetFlag -eq 1)

#range validation loop, validates that the IP range is valid, the acceptable range is 1-254 at most
do{
    #start/lower range validation loop, verifies that the input is valid
    #entry of a non-number character produces and error, but the loop repeats
    do{
        try{
            [int]$start = Read-Host "Please enter the lowest number in the IP range you wish to scan, excluding 0"
        }
        catch{
            write-host "ok dude, stop putting letters where you know numbers go, now its just on purpose" -ForegroundColor Yellow
            continue
        }
        switch ($start){
            0 {write-host "Invalid, 0 cannot be used" -ForegroundColor Yellow}
            255 {write-host "Invalid, 255 cannot be used" -ForegroundColor Yellow}
            {$_ -lt 0} {write-host "invalid, please enter a number above 0" -ForegroundColor Yellow}
            {$_ -gt 255} {write-host "Invalid, please enter a number below 255" -ForegroundColor Yellow}
            default {$startFlag = 1}

        }  
    }until($startFlag -eq 1)

    #stop/upper range validation loop, verifies that the input is valid
    #entry of a non-number character produces and error, but the loop repeats
    do{
        try{
            [int]$stop = Read-Host "Please enter the highest number in the IP range you wish to scan, excluding 0"
        }
        catch{
            write-host "ok dude, stop putting letters where you know numbers go, now its just on purpose" -ForegroundColor Yellow
            continue
        }
        switch ($stop){
            0 {write-host "Invalid, 0 cannot be used" -ForegroundColor Yellow}
            255 {write-host "Invalid, 255 cannot be used" -ForegroundColor Yellow}
            {$_ -lt 0} {write-host "invalid, please enter a number above 0" -ForegroundColor Yellow}
            {$_ -gt 255} {write-host "Invalid, please enter a number below 255" -ForegroundColor Yellow}
            default {$stopFlag = 1}

        }  
    }until($stopFlag -eq 1)

    #validates that the stop address is a higher value than the start address, 
    #if not, it starts the entire loop over again, beginning with the start address
    if($start -lt $stop){
        write-host "IP range validated" -ForegroundColor Green
        $rangeFlag = 1
    }
    else{
        write-host "The start of the range is not lower than the end of the range, please re-enter your range" -ForegroundColor Yellow
        $startFlag = 0
        $stopFlag = 0
        $rangeFlag = 0
    }
}until($rangeFlag = 1)

#take in a file name
$fileOut = read-host "Please enter the name of the file you wish for the results to be saved in"

$stop++ #add 1 to the stop value, this is to make the below for loop inclusive of the stop address, otherwise it would stop 1 short
for($i = $start; $i -lt $stop; $i++){
    $test = ""                          #resets the result value
    $obj = new-object psobject
    $target = "$subnet" + "$i"          #constructs the address being checked
    write-host "testing $target" -ForegroundColor Cyan
    $obj | add-member -membertype noteproperty -name "IP Address" -value $target

    if(test-connection $target -count 1 -quiet){    #conducts 1 quiet ping, the if statement treats the result as a boolean
        $test = "IP Active"
        
    }
    else{
        $test = "IP Inactive"
    }
    $obj | add-member -membertype noteproperty -name "Status" -value $test  
    $addresses += $obj
}

#attempt to write the results to the specified file name at the current directory the script is being run from, 
#if it fails, it flips a flag and enters a re-entry and validation loop 
try{
	$addresses | export-csv -path "$fileOut" -notypeinformation
	$fileFlag1 = 1
    write-host "Script Complete results have been written to the current directory this script has been run from" -ForegroundColor Green
}
catch{
	write-host "Access Denied Error" -foregroundcolor red
	$fileFlag1 = 0
}
if($fileFlag1 -eq 0){
	do{
		$outPath = read-host 'Please enter a valid save location that you have permission to write to'
	
		try{
			$output | export-csv -path "$outPath\$fileOut" -notypeinformation -erroraction stop
		}
		catch{
			write-host "Access Denied Error" -foregroundcolor red
		}
	}
	until(test-path "$outPath\$fileOut")
    write-host "Script complete, the results have been written to a file located at " + $outPath -ForegroundColor Green
}