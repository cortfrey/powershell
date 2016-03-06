#queries a list of servers and find where a desired service account is located
#input is currently hardcoded as 'servers.txt' to be located in the same directory as the script
#[SVC ACCOUNT] is where you would enter your desired service account
#[SID] is the desired group SID you wish to use, S-1-5-32-544 for administrators
#the .domain in the $query variable refers to the local domain

$svr = @()		#list of servers from text file
$out = @()		#used to store results

$svr = get-content .\servers.txt 	#gets list of servers


foreach($s in $svr){
	write-host $s -foregroundcolor yellow
	
	$obj = new-object PSObject	#creates a new custom object
	
	#set of wmi calls and filters to find service accounts
	$group = get-wmiobject win32_group -ComputerName $s -Filter "LocalAccount=True AND SID='[SID]'"				#get local group
	$query = "GroupComponent = `"Win32_Group.Domain='$($group.domain)'`,Name='$($group.name)'`""				#query built off of previous WMI results and used as for following WMI call
	$list = Get-WmiObject win32_groupuser -ComputerName $s -Filter $query										#pulls all users that match being a member of the group and are local accounts
	$users = $list.PartComponent | % {$_.substring($_.lastindexof("Domain=") + 7).replace("`",Name=`"","\")}	#filters out results for desired information
	
	$obj | add-member -membertype noteproperty -name "server" -value $s #adds servername to output object
	
	#loops through list of users that are in the group and searches for the desired service account.  Immediately breaks if it finds it and moves onto the next server
	foreach($u in $users){
		if($u -like '*[SVC ACCOUNT]*'){
			$obj | add-member -membertype noteproperty -name "[SVC ACCOUNT]?" -value "True"						#adds to output object
			break
		}
		else{
			$obj | add-member -membertype noteproperty -name "[SVC ACCOUNT]?" -value "False"					#adds to output object
			break			
		}
	}
	$out += $obj		#adds object to array that will be exported.
}

$out | export-csv -notypeinformation ".\[SVC ACCOUNT]rpt.csv"		#export results to csv
