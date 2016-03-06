#simple script to pull the last date a user changed their password.  
#This could be easily adapted with a foreach loop to pull this information for a list of users

$user = read-host "user name?"

$searcher=New-Object DirectoryServices.DirectorySearcher
$searcher.Filter="(&(samaccountname=$user))"
$results=$searcher.findone()
[datetime]::fromfiletime($results.properties.pwdlastset[0])