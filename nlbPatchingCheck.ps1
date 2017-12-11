###################################################
#script name: nlbPatchingCheck.ps1
#author: Cort Frey
#date: 11/7/17
#version: 1.3
#purpose:   designed to start a patching script if 
#           there are 5 or fewer active connections
#           the script will also drainstop the 
#           server first.  Patching script must
#           reboot server to restart NLB functions
#
#usage:     run from scheduled tasks, to be started
#           from an external source, leave task 
#           disabled.
###################################################


$nlb = ""               #stores output from the get-nlbClusterNode cmdlet
$date = ""              #stores the date for logging purposes    
$inString = ""          #string that is passed into the logging function whenever the logging function is called
$outString = ""         #string produced by logging function to write to file
$logFile = ""           #stores the name of the log file and location
$computerName = ""      #stores the name of the computer for use in email
$domainName = ""        #stores the name of the domain for use in email
$nodeList = ""          #stores list of nodes in the cluster
$unconvergeCount = 0    #used to track the number of unconverged nodes in a 3 node cluster
$mailDestination = ""   #stores the email destination for the errors
$smtp = ""              #stores the appropriate smtp server for the domain of the server being patched

$logFile = "C:\temp\$(gc env:computername)NLBAutomation.log"
$nlb = get-nlbClusterNode       #attempting to directly store properties results in a list object, 
                                #not a nlb object, nlb properties can be access from the variable

#function used for writing logs, takes a single string, adds prepends a date, and writes to file
function writeLog{
    param(
        [string]$inString
    )
    $date = get-date -format "MM dd, yyyy HH:mm:ss"
    $outString = $date + ": " + $inString
    Add-content $logFile -value $outString
}

#function used to send email notifications if the patching has failed
#takes in the computer name and domain to set a source email address
#determines the smtp server based on domain
#the domain switch can be removed or modifed as needed, but cannot be left as is
function sendMail{
    param(
        [string]$computer,
        [string]$domain
    )
    switch -wildcard ($domain){
            "*DOMAIN1*"{$smtp = "SMTPSERVER1"}
            "*DOMAIN2*"{$smtp = "SMTPSERVER2"}
            "*DOMAIN3*"{$smtp = "SMTPSERVER3"}
            default{$smtp = "SMTPSERVER1"}
    }
    send-mailMessage -from "$computer@$domain" - to $mailDestination -subject ("Patching Failed on " + $computerName) -smtpserver $smtp
}



$computerName = $env:ComputerName                               #set the computer name for use in email
$domainName = (get-wmiObject win32_computersystem).domain       #set the computer domain for use in email
$mailDestination = "DESTINATION@DOMAIN.DOMAIN"    #set the destination email for notifications  								THIS MUST BE CHANGED TO WORK

if(!(test-path "C:\temp\")){                                    #valdiates that the C:\temp\ directory exists, if it does not, it creates it
    new-item -itemtype directory -path "C:\temp\"
    writeLog("File Path C:\temp\ not found, creating directory")
}

writeLog("NLB pre-patch check script started")

if(!(get-module NetworkLoadBalancingClusters)){                                     #validates that the NLB powershell module is loaded
    writeLog("NetworkLoadBalancingClusters module not loaded, loading module...")   #if it is not, it will load it
    import-module NetworkLoadBalancingClusters
    writeLog("NetworkLoadBalancingCluster Module has been loaded")
}
else{
    writeLog("NetworkLoadBalancingClusters module is already loaded, proceeding")
}

[array]$nodeList = get-nlbClusterNode | select -property name, state   #get list of all nodes in the cluster

#counts the number of converged hosts, if it is equal to 1, it will abort patching
if(($nodeList | select -property state | where-object{$_.state -like "*converged*"} | measure).count -eq 1){
    $unconvergeCount = ($nodeList | select -property state | where-object{$_.state -notlike "*converged*"} | measure).count
    writeLog("There are " + $unconvergeCount + " nodes unconverged, out of " $nodeList.length + " exceeding the safe threshold")
    sendMail $computerName $domainName
    writeLog("E-mail Notification Sent to " + $mailDestination + " exiting script")
    exit
}


writeLog("Hosts are converged")
writeLog("Draining host " + $env:ComputerName)
stop-nlbClusterNode -drain                      #start drain stopping the server

#loop checks for remaining connections on port 443
#will run a maximum of 720 times with a 15 second interval between iterations
#if on any iteration, the total number of connections on 443 drops to 5 or less,
#the web server is stopped and patching started after a final convergance check,
#which logically should never trigger
for($i = 0; $i -le 720; $i++){                    
    $openConnections = (get-nlbClusterDriverInfo -openConnections | where-object{$_.destinationPort -eq "443"} | measure).count  #counts all active connections on port 443
    writeLog("There are Currently " + $openConnections + " open Connections")
    if($openConnections -le 5){
        if($nodelist | select -Property state | Where-Object{$computerName.state -like "*converged*"}){ #this loop should NEVER be hit or something went horribly wrong
            writeLog("failed final convergance check, something went wrong, exiting")
            sendMail $computerName $domainName
            exit
        }
        writeLog("There are 5 or fewer connections, stopping web server")
        stop-nlbClusterNode
        writeLog("Starting Patching Script")
        .\notepad.exe
        writeLog("Log written to: " + $logFile + ", exiting script")
        exit
    }
    start-sleep -s 15           #waits 15 seconds to re-run this loop
}