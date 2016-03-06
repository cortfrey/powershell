################################################################
#lifecycle.ps1                                                 #
#Version 2                                                     #
#Powershell version 3.1                                        #
#                                                              #
#Purpose: Uses a provided .TXT, .CSV, or .RPT file, which MUST #
#	be SEMI-COLON DELIMTED to determine a lifecycle grade for  #
#	each server in the file.  This is based off a SQL export,  #
#	but fields may be filled manually.  Required fields follow:#
#		Server Name											   #
#		Operating System									   #
#		Installation Date									   #
#		Manufacturer										   #
#		Model												   #
#															   #
#proper format should be:									   #
#ServerName;OperatingSystem;InstallDate;Manufacturer;Model	   #
#anything else will yield incorrect results or crash the script#
#															   #
#if a server is physical, script will reach out and attempt to #
#	connect to the ilo on a server and read the IML log.  For  #
#	that reason, cpqlocfg.exe and Get_iLO_Log2.xml must be     #
#	included in the the same directory as this script.  If all #
#	servers are known to be virtual, this step can be skipped  #
################################################################

#####################
######Variables######
#####################  
$magic = TRUE									#everything is magic
     
$inFile = ""									#file that is read in
$inData = @()									#content of file
$outData = @()									#results of analysis

$osPts = 0										#points assigned based on the operating system
$genPts = 0										#points assigned based on the generation of hardware
$installDatePts = 0								#points assigned based on the age of the installation
$errorPoints = 0								#points assigned based on the number of errors in the IML log (physical only)
$totalPoints = 0								#Sum of points for each server, the grade

$serverName = ""								#first field in the sql report
$os = ""										#second field in the sql report
$installDate = ""								#third field in the sql report
$manufacturer = ""								#fourth field in the sql report
$model = ""										#fifth field in the sql report
$currentDate = ""								#The date that the script is run

$ILOpath = ".\iloitem"							#path to the ilo folder

$error1 = 0										#counts instances of IML error 1
$error2 = 0										#counts instances of IML error 2
$Total_Errors = 0								#Total instances of IML errors
$IML_Error_Match1 = "Server Reset"				#first type of error to be parsed for
$IML_Error_Match2 = "Server Power Removed"		#Second type of error to be parsed for

#tests to see if a file was inserted on the command line or not, if one was not, it will prompt for one
if ($args.length -ne 0){
	[string]$inFile = $args[0]
}
else{
	$inFile = read-host 'Please enter a valid file and file path to the sql report' -foregroundcolor yellow
}

#takes initial file input and validates it, if the file path doesn't exist, it will prompt and test until a valid file is provided.
#only accepts files with extensions of .txt, .csv, or .rpt
do{
	$flag1 = 0
	$flag2 = 0
	if(!(test-path $inFile)){
		do{write-host "File Path does not exist." -foregroundcolor red
			$inFile = read-host 'Please enter a valid file path'
		}
		until(test-path $inFile)
	}
	$flag1 = 1

	$temp = $inFile.split('.')
	if((!($temp[-1] -eq "rpt")) -and (!($temp[-1] -eq "txt")) -and (!($temp[-1] -eq "csv"))){
		write-host "Incorrect File Type, please use a .csv, .txt, or .rpt file" -foregroundcolor red
	}
	else{
		$flag2 = 1
	}
}
until(($flag1 -eq 1) -and ($flag2 -eq 1))
write-host "File is Valid" -foregroundcolor white

#tests to see if the path $ILOpath, defined in the variables exists, if it does not, it creates the directory.
if(!(test-path $ILOpath)){
	write-host "File Path: $ILOpath, does not exist, creating filepath"	
	mkdir $ILOpath
}

$inData = [System.Collections.Arraylist](get-content $inFile)#reads in the content of the provided file as an ARRAYLIST

$currentDate = (get-date).toshortdatestring()#retrieve current date, this is done for age of server purposes

#foreach loop that iterates through the contents of the provided file and analyses each line, assigning a set of points to various parameters to assist in lifecycle ranking.
foreach($line in $inData){
	$obj = new-object psobject
	$arr = $line -split ';'
	
	write-host "Analyzing: $arr[0]" -foregroundcolor white
	
	$servername = $arr[0]
	$OS = $arr[1]
	$i = $arr[2] #raw datetime which gets converted below
	$installDate = ([datetime]$i).toshortdatestring()
	$manufacturer = $arr[3]
	$model = $arr[4]
	
	$obj | add-member -membertype noteproperty -name "Server" -value $servername
	$obj | add-member -membertype noteproperty -name "Operating System" -value $os
	$obj | add-member -membertype noteproperty -name "Install Date" -value $installDate
	$obj | add-member -membertype noteproperty -name "Manufacturer" -value $manufacturer
	$obj | add-member -membertype noteproperty -name "Model" -value $model
	
	
	if((!($model -match 'VMware')) -or (!($model -match 'Virtual'))){#tests if the server is physical, if it is, it will run an HP iLO utility and pull the IML log to be analysed
		write-host "$arr[0] is a physical server, retrieving ILO IML log, please wait" -foregroundcolor white
		
		$ilo = $arr[0] + "ilo"##############################################################################################################################################################################################################################################################################################
		.\cpqlocfg.exe -s $ilo -f .\Get_iLO_Log2.xml -l .\iloitem\$arr[0]#iLO utlity must be in same directory as this script, as well as the xml file that is used.
		$fileContent = Get-Content ".\iloitem\$arr[0]"
		
		write-host "$arr[0] IML log retrieved, analyzing" -foregroundcolor white
		
		$error1 = 0
		$error2 = 0
		$Total_Errors = 0
		$errorPoints = 0
	
		foreach($line in $fileContent){#reads IML log and matches for specific errors, increasing the count per error found
			if($line -match $IML_Error_Match1){
				$error1++
			}
			elseif($line -match $IML_Error_Match2){
				$error2++
			}			
		}
		$Total_Errors = $error1 + $error2
		$errorPoints = [math]::Floor($Total_Errors/10)#some servers have a very large number of errors, dividing by 10 can help keep the points at manageable levels.
		
		#each error count is provided seperately, along with a total.
		$row | add-member -membertype noteproperty -name "[IML]Server Reset" -value $error1
		$row | add-member -membertype noteproperty -name "[IML]Server Power Removed" -value $error2
		$row | add-member -membertype noteproperty -name "[IML]Total Errors" -value $Total_Errors
	}
	else{#if the server is not physical, the IML error counts are simply set to zero
		[string]$error1 = "n/a"
		[string]$error2 = "n/a"
		$Total_Errors = 0
		$errorPoints = 0
		
		$row | add-member -membertype noteproperty -name "[IML]Server Reset" -value $error1
		$row | add-member -membertype noteproperty -name "[IML]Server Power Removed" -value $error2
		$row | add-member -membertype noteproperty -name "[IML]Total Errors" -value $Total_Errors
	}
	
	switch -wildcard ($os){#checks the OS version, assigning more points, the older the version, the more points it gets
		"*NT*"{$osPts = 6}
		"*2000*"{$osPts = 5}
		"*2003*"{$osPts = 4}
		"*2008*"{$osPts = 3}
		"*2008*R2*"{$osPts = 2}
		"*2012*"{$osPts = 1}
		"*2012*R2*"{$osPts = 0}
		default{$osPts = 10}
	}
	#checks the model of the server, assigning points, the older the version, the more points it gets
	#note that VMWare, being phased out, is assigned a number of points.
	#'Virtual' indicates a Hyper-V machine and is considered current, in terms of model
	switch -wildcard ($model){
		"*G2*"{$genPts = 7}
		"*G3*"{$genPts = 6}
		"*G4*"{$genPts = 5}
		"*G5*"{$genPts = 4}
		"VMware*"{$genPts = 4}
		"*G6*"{$genPts = 3}
		"*G7*"{$genPts = 2}
		"*Gen8*"{$genPts = 1}
		"*G8*"{$genPts = 1}
		"*G9*"{$genPts = 0}
		"Virtual*"{$genPts = 0}
		default{$genPts = 10}
	}
	
	$installDatePoints = [math]::round((new-timespan -start $installDate -end $currentDate).days/365)#each year since the server has been deployed adds another point to the score
	$totalPoints = $osPts + $genPts + $installDatePoints + $errorPoints

	$row | add-member -membertype noteproperty -name "IML Error Points" -value $errorPoints
	$obj | add-member -membertype noteproperty -name "Operating System Age Points" -value $osPts
	$obj | add-member -membertype noteproperty -name "Hardware Generation Points" -value $genPts
	$obj | add-member -membertype noteproperty -name "Install Age Points" -value $installDatePoints
	$obj | add-member -membertype noteproperty -name "Total Points" -value $totalPoints

	$outData += $obj
	
	write-host "Completed analysis of $arr[0], moving to next object" -foregroundcolor white
}
write-host "All servers analyzed, writing to file..." -foregroundcolor white

$filename = [string]::concat("Server_Grading_",(get-date).month,"-",(get-date).day,"-",(get-date).year)#provides a custom file name based on the date the report was run
$outData | export-csv ".\$filename.csv" -notypeinformation
write-host "file has been written to the current directory" -foregroundcolor white
write-host "Filename: $filename" -foregroundcolor white	