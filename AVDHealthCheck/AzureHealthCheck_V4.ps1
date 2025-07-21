<#
 .SYNOPSIS
# Created on: 09.01.2023 Version: 1.0
# Created by:Naveen Arya 
# File name: AzureHealthCheck_V4.ps1
#
# Description: This script perform the healthcheck of Azure Hostpool VMs and Storage file share.
# It generates a HTML output File which will be sent as Email to Citrix DL.

# Prerequisite:Make sure Azure Modules are available in the system where script is running and Read/write permission in Azure HP and FileShare
# Call by : Manual or by Scheduled Task via SCCM#

Note:! Read it once before your run it 
Contact at #emailid for any query.


!.....Change Logs 
1.Corrected the formatting of html tables and colour code added for unavailable VMs Count.
2.Changed the Storage file share Threshold values.
3.Updated the html and css for formatting.
4.Customize the code to minimise the execution time in on 13/03/2023
5.Added Draim modeON column in the Health check report on 13/03/2023
6. Added Azure font for Cosmetic Stuff 14/03/2023
7.Removed  hostpool from HealthCheck Report
8.Added DR fileshare utlization

 #>
 Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Confirm:$false -Force
##########################################################################################
write-host ""
write-host ""
write-host "                                                            " -ForegroundColor Green
write-host "     /\                                                  	" -ForegroundColor Yellow
write-host "    /  \    _____   _ _ __ ___ 				" -ForegroundColor Red
write-host "   / /\ \  |_  / | | | '__/ _ \  				" -ForegroundColor Cyan
write-host "  / ____ \  / /| |_| | | |  __/				" -ForegroundColor DarkCyan
write-host " /_/    \_\/___|\__,_|_|  \___				" -ForegroundColor Magenta
write-host "     "


###########################################################################################
 $path='\\filesharepath\Automation\AzureHealthCheck'
 Write-Host "Transacript started by  $env:userName for HealthCheck report" -ForegroundColor Yellow
 Start-Transcript  $path\AzureHealthCheckLog_$((get-date -Format 'ddMMyyy')).txt
 Write-Host "Script Start Time " -NoNewline -ForegroundColor Gray; Write-Host $(Get-Date -Format HH:mm:ss) -ForegroundColor Gray ; 
 
 $ReportDate = (Get-Date -UFormat "%A, %d. %B %Y %R")
 $resultsHTM = "$path\AzureHealthCheck.htm"
 #$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size (500, 25)
###################################################################################

###Importing the AzureModle and RDmodule
Write-Host
Write-Host $(Get-Date -Format HH:mm:ss:) -ForegroundColor Gray -NoNewLine ; Write-Host ” Importing PowerShell Modules”
$Modules = @(‘Az’,'Microsoft.RDInfra.RDPowershell','Az.NetAppFiles')
Foreach ($Module in $Modules) {
if((Get-Module -Name $Module -ErrorAction SilentlyContinue) -eq $false) {
Write-Host $(Get-Date -Format HH:mm:ss:) -ForegroundColor Gray -NoNewLine ; Write-Host ” Importing Module” $Module -ForegroundColor DarkYellow
Import-Module -Name $Module -Verbose -ErrorAction SilentlyContinue
}
Else {
Write-Host $(Get-Date -Format HH:mm:ss:) -ForegroundColor Gray -NoNewLine ; Write-Host ” PowerShell Module ” -NoNewline -ForegroundColor DarkYellow ; Write-Host “‘$Module'” -NoNewline -ForegroundColor DarkCyan ; Write-Host ” already imported” -ForegroundColor DarkYellow
}
}

Write-Host " Successfully Imported Azure moduless " -ForegroundColor Green

###################################################################################
###Sa account login prompt for Azure login 
$User="$env:Naveen@cloud9vin.com"
$domaincred = get-credential -Message "Login with your admin-Account:" -UserName($User ) 
$UserName=$domaincred.UserName
$password=$domaincred.Password
$credential = New-Object System.Management.Automation.PSCredential ($UserName, $password)
Connect-AzAccount -Subscription 'SubscriptionName' -Credential (Get-Credential -Credential $credential)

<# do not delete this..we will use below when Script it scheduled
$UserName="username@cloud9vin.com"
$pass=''
$password = ConvertTo-SecureString -String $pass -AsPlainText -Force
#>

###################################################################################
###Fetching the hostpool Names from Azure
$Hostpool = Get-AzWvdHostPool |?{$_.Name -like "*UAEN*"} | Select @{n="HostpoolName" ;e={($_.Name)}},@{n="ResourceGroup" ;e={($_.id).Split("/")[4]}}
$Hostpool.Length

<#
##################################################################################
###Fetching the Resource group  Name
$RG_Name=(Get-AzWvdHostPool).id -split "/" |ForEach-Object {if($_ -match "-rg"){$_}}
$Resource_Group=$RG_Name|Select-Object -Unique
$Resource_Group.Length
##################################################################################
#>

$AzhpFirstheaderName = "HostpoolName"
$AzhpHeaderNames = "TotalVM", 	"AvailableVM","DrainModeOn","UnAvailableVM"
$AzhpHeaderWidths = "3",	"3", 	"3"	,"3"			
$AzhpTableWidth= 1200
###################################################################################

<#
Function writeHtmlHeader{
param($title, $fileName)
$date = $ReportDate
$head = @"
<html>
<head>
<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
<title>$title</title>
<STYLE TYPE="text/css">
<!--
td {
 font-family: Calibri, sans-serif, 'Gill Sans', 'Gill Sans MT', 'Trebuchet MS';
                background-color: whitesmoke;
font-family: Tahoma;
font-size: 11px;
border-top: 1px solid #999999;
border-right: 1px solid #999999;
border-bottom: 1px solid #999999;
border-left: 1px solid #999999;
padding-top: 0px;
padding-right: 0px;
padding-bottom: 0px;
padding-left: 0px;
overflow: hidden;
}
body {
margin-left: 5px;
margin-top: 5px;
margin-right: 0px;
margin-bottom: 10px;
table {
table-layout:fixed;
border: thin solid #000000;
}
-->
</style>
</head>
<body>
<table width='1200'>
<tr bgcolor='#CCCCCC'>
<td colspan='7' height='48' align='center' valign="middle">
<font face='tahoma' color='#003399' size='4'>
<strong>$title - $date</strong></font>
</td>
</tr>
</table>
"@
$head | Out-File $fileName
}


$HostpoolHeader = @"
<style>
TABLE {border-width: 1px;width: 100% ;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;text-align: left; padding: 3px;border-style: solid;border-color: black;background-color:#6495ED;}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
</style>
"@ 
#>

###Creating html file formatting
Function writeHtmlHeader{
param($title, $fileName)
$date = $ReportDate
$head = @"
<html>
<head>
<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
<title>$title</title>
<STYLE TYPE="text/css">
<!--
td {

font-family: Tahoma;
background-color: F5f5f5;
font-size: 11px;
border-top: 1px solid #999999;
border-right: 1px solid #999999;
border-bottom: 1px solid #999999;
border-left: 1px solid #999999;
padding-top: 0px;
padding-right: 0px;
padding-bottom: 0px;
padding-left: 0px;
overflow: hidden;
}
body {
margin-left: 5px;
margin-top: 5px;
margin-right: 0px;
margin-bottom: 10px;
table {
table-layout:fixed;
border: thin solid #000000;
}
-->
</style>
</head>
<body>
<table width='1600'>
<tr bgcolor='Cadetblue'>
<td colspan='7' height='48' align='center' valign="middle">
<font face='tahoma' color='#003399' size='4'>
<strong>$title - $date</strong></font>
</td>
</tr>
</table>
"@
$head | Out-File $fileName
}
$HostpoolHeader = @"
<style>
TABLE {border-width: 1px;width: 100% ;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;text-align: left; padding: 3px;border-style: solid;border-color: black;background-color:CadetBlue;}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color:whitesmoke;}
</style>
"@ 
###Footer
Function writeHtmlFooter
{
param($fileName)
@"
</table>
<table width='1200'>
<tr bgcolor='whitesmoke'>
<td colspan='7' height='25' align='left'>
<font face='courier' color='#000000' size='2'>

<strong>LastRun: </strong> $LastRun<br>
<strong>RunBy: </strong> $RunBy <br>
<strong>RunFrom: </strong> $RunFrom <br>
<strong>Version: </strong> $Version <br>
<strong>CreatedBy: </strong><strong><a href="Mailto:$CreatedBy">$CreatedBy</a></strong> <br>
<strong>SupportBy: </strong><strong><a href="Mailto:$Support">$Support</a></strong> <br>
<strong><a href=$Source>https://Portal.azure.com </a></strong> <br>

</font>
</td>
</table>
</body>
</html>
"@ | Out-File $FileName -append
}

###################################################################################

Function writeTableHeader
{
param($fileName, $firstheaderName, $headerNames, $headerWidths, $tablewidth)
$tableHeader = @"
  
<table width='$tablewidth'><tbody>
<tr bgcolor='#F5f5f5'>
<td width='6%' align='Left'><strong>$firstheaderName</strong></td>
"@
  
$i = 0
while ($i -lt $headerNames.count) {
$headerName = $headerNames[$i]
$headerWidth = $headerWidths[$i]
$tableHeader += "<td width='" + $headerWidth + "%' align='left'><strong>$headerName</strong></td>"
$i++
}
  
$tableHeader += "</tr>"
  
$tableHeader | Out-File $fileName -append
}
  
###################################################################################
Function writeTableFooter
{
param($fileName)
"</table><br/>"| Out-File $fileName -append
}
  
###################################################################################
Function writeData
{
param($data, $fileName, $headerNames)
#<font color='#003399'>
$tableEntry  =""  
$data.keys | sort | foreach {
$tableEntry += "<tr>"
$computerName = $_
$tableEntry += ("<td bgcolor='#F5f5f5' align=left>$computerName</font></td>")
#$data.$_.Keys | foreach {
$headerNames | foreach {
#"$computerName : $_" | LogMe -display
#$fontColor = "#FFFFFF"
try {
if ($data.$computerName.$_[0] -eq "SUCCESS") { $bgcolor = "#387C44" }
elseif ($data.$computerName.$_[0] -eq "WARNING") { $bgcolor = "#FF7700"}
elseif ($data.$computerName.$_[0] -eq "ERROR") { $bgcolor = "#FF0000" }
else { $bgcolor = "#F5f5f5"; $fontColor = "#000000" }
$testResult = $data.$computerName.$_[1]
}
catch {
$bgcolor = "#F5f5f5"; $fontColor = "#000000"
$testResult = ""
}

$tableEntry += ("<td style='background-color:$bgcolor'"  + "' align=left><font color='" + $fontColor + "'>$testResult</font></td>")
}
$tableEntry += "</tr>"
}
$tableEntry | Out-File $fileName -append
}
  
###################################################################################

###################################################################################
Function ToHumanReadable()
{
  param($timespan)
  
  If ($timespan.TotalHours -lt 1) {
    return $timespan.Minutes + "minutes"
  }

  $sb = New-Object System.Text.StringBuilder
  If ($timespan.Days -gt 0) {
    [void]$sb.Append($timespan.Days)
    [void]$sb.Append(" days")
    [void]$sb.Append(", ")    
  }
  If ($timespan.Hours -gt 0) {
    [void]$sb.Append($timespan.Hours)
    [void]$sb.Append(" hours")
  }
  If ($timespan.Minutes -gt 0) {
    [void]$sb.Append(" and ")
    [void]$sb.Append($timespan.Minutes)
    [void]$sb.Append(" minutes")
  }
  return $sb.ToString()
}


###################################################################################

###footer information in html report
$LastRun = (Get-Date)
$RunBy = "$($env:USERDOMAIN)\$env:username"
$RunFrom = $env:Computername
$Version = "1.0"
$CreatedBy= "Naveenarya198@outlook.com"
$Support="Naveenarya198@outlook.com"
$Source="https://Portal.azure.com"

###################################################################################

###getting the Name  of unavailable Machine name in Hostpool..

$HostpoolVM=@()
foreach($hp in $Hostpool){

Write-Host "Fetching the list of Unavailable VMs in $(($hp).HostpoolName)" -ForegroundColor Yellow
$VM_Information=(Get-AzWvdSessionHost -HostPoolName $hp.HostpoolName -ResourceGroupName $hp.ResourceGroup  -ea Ignore) | ? {($_.Status -imatch 'Unavailable') -or ($_.Status -imatch 'Upgrading*')} |select @{n="Hostpool";e={($_.Name).split("/")[0]}},@{n="Machine";e={($_.Name).split("/")[1]}},Status
$HostpoolVM+=($VM_Information)
}


$Hostpoolarraylist=[System.Collections.ArrayList]@($HostpoolVM)

###################################################################################

####Restarting the VMs Which are in Unavailable state.

$Restart_HostpoolVM=($HostpoolVM).Machine|%{($_ -replace (".bankfab.com",""))} 
foreach($VM in $Restart_HostpoolVM){

$status= (Get-AzVM -Name $VM -Status)| select PowerState
if($status.PowerState -imatch "running"){
Write-Host "$VM status is $(($status.PowerState) -replace "VM "," ").Restarting the VM " -BackgroundColor Green
Get-AzVM -Name $VM |Restart-AzVM
}
else{Write-Host "$VM status is $(($status.PowerState) -replace "VM "," ") Restart will skip" -BackgroundColor Red}
}


###################################################################################
###Getting the List of  Total Machines in hostpools
$TotalVM=@()
foreach($hp in $Hostpool){

Write-Host "Fetching the Total number of  VMs in $(($hp).HostpoolName)" -ForegroundColor Yellow
$VMCount=(Get-AzWvdSessionHost -HostPoolName $hp.HostpoolName -ResourceGroupName $hp.ResourceGroup -ea Ignore) | select @{n="Hostpool";e={($_.Name).split("/")[0]}}|Group-Object Hostpool|select Name,@{n="TotalVM";e={($_.Count)}}
$TotalVM+=($VMCount)
}

###################################################################################

###getting the list of total available machines
$AvailableVM=@()
foreach($hp in $Hostpool){

Write-Host "Fetching the Total number of Available VMs in $(($hp).HostpoolName)" -ForegroundColor Yellow
$AvailableCount=(Get-AzWvdSessionHost -HostPoolName $hp.HostpoolName -ResourceGroupName $hp.ResourceGroup -ea Ignore)| ? {$_.Status -eq "Available"} | select @{n="Hostpool";e={($_.Name).split("/")[0]}},status|Group-Object Hostpool |select Name,@{n="Available";e={($_.Count)}}
$AvailableVM+=($AvailableCount)
}
$AvailableVM

###################################################################################

###################################################################################

###getting the list of machines which are in drain mode 
$DrainModeON=@()
foreach($hp in $Hostpool){

Write-Host "Fetching the Total number of VMs in DrainMode in $(($hp).HostpoolName)" -ForegroundColor Yellow
$DrainCount=(Get-AzWvdSessionHost -HostPoolName $hp.HostpoolName -ResourceGroupName $hp.ResourceGroup -ea Ignore)| ? {$_.AllowNewSession -like "false"} | select @{n="Hostpool";e={($_.Name).split("/")[0]}},AllowNewSession|Group-Object Hostpool |select Name,@{n="DrainModeON";e={($_.Count)}}
$DrainModeON+=($DrainCount)

}

$DrainModeON

###################################################################################

###getting the list of  Available  machines
$TotalVMArrList =[System.Collections.ArrayList]@($TotalVM)
foreach($i in $TotalVMArrList){

#$i |Add-Member -MemberType NoteProperty -Name AvailableVM -Value($AvailableVM|?{$_.Name -eq $i.Name}).Available -Force

if(($AvailableVM|?{$_.Name -eq $i.Name}).Available){

$i |Add-Member -MemberType NoteProperty -Name AvailableVM -Value (($AvailableVM|?{$_.Name -eq $i.Name}).Available) -Force

}

else {

$i |Add-Member -MemberType NoteProperty -Name AvailableVM -Value 0 -Force


}

}

###getting the list of  DrainMode  machines
foreach($i in $TotalVMArrList){

if(($DrainModeON|?{$_.Name -eq $i.Name}).DrainModeON){

$i |Add-Member -MemberType NoteProperty -Name DrainModeOn -Value (($DrainModeON|?{$_.Name -eq $i.Name}).DrainModeON) -Force

}

else {

$i |Add-Member -MemberType NoteProperty -Name DrainModeOn -Value 0 -Force


}
}

###getting the list of total Unavailable machines
foreach($i in $TotalVMArrList){

$i |Add-Member -MemberType NoteProperty -Name UnAvailableVM -Value((($TotalVM|?{$_.Name -eq $i.Name}).TotalVM)-(($AvailableVM|?{$_.Name -eq $i.Name}).Available)) -Force

}

###################################################################################
###getting the Name  of final unavailable Machine name in Hostpool post reboot.
$AfterRebootHostpoolVM=@()
foreach($hp in $Hostpool){
$VM_Information1=(Get-AzWvdSessionHost -HostPoolName $hp.HostpoolName -ResourceGroupName $hp.ResourceGroup -ea Ignore) | ? {($_.Status -imatch 'Unavailable') -or ($_.Status -imatch 'Upgrading*')} |select @{n="Hostpool";e={($_.Name).split("/")[0]}},@{n="Machine";e={($_.Name).split("/")[1]}},Status

$AfterRebootHostpoolVM+=($VM_Information1)
}


$AfterRebootHostpoolarraylist=[System.Collections.ArrayList]@($AfterRebootHostpoolVM)

###################################################################################

###Creating the colour code for UnavailableVM DrainModeOn VMs Machine in the Hostpool
$TotalVMArrListResults = @{}
foreach ($line in $TotalVMArrList){

$test1=@{}

$Name = $line| %{ $_.Name }
$test1.Name="NEUTRAL", ($Name)

$TotalVM = $line | %{ $_.TotalVM }
$test1.TotalVM  ="NEUTRAL", ($TotalVM)

$AvailableVM = $line | %{ $_.AvailableVM }
$test1.AvailableVM  ="NEUTRAL", ($AvailableVM)

$DrainModeON = $line | %{ $_.DrainModeOn }
$test1.DrainModeON  ="NEUTRAL", ($DrainModeON)

$UnAvailableVM = $line | %{ $_.UnAvailableVM }
$test1.UnAvailableVM  ="NEUTRAL", ($UnAvailableVM)

###Unavailable VM -gt 0 & lesss than 5 ==>Warning(Yellow)
###Unavailable VM -gt 5 =================>Crtical(Red)

if((($UnAvailableVM -gt 0)-and ($UnAvailableVM -le 5))){
$test1.UnAvailableVM    ="WARNING", $UnAvailableVM
}

elseif($UnAvailableVM -gt 5){
$test1.UnAvailableVM    ="ERROR", $UnAvailableVM
}

else{
$test1.UnAvailableVM    ="SUCCESS", $UnAvailableVM
}


if((($DrainModeON -gt 0)-and ($DrainModeON -le 20))){
$test1.DrainModeON    ="WARNING", $DrainModeON
}

elseif($DrainModeON -gt 20){
$test1.DrainModeON    ="ERROR", $DrainModeON
}

else{
$test1.DrainModeON    ="SUCCESS", $DrainModeON
}

$TotalVMArrListResults.($line.Name)=  $test1 
}


##################################################################################

###Getting volume and cache Fileshare Storage information
$straccName=(Get-AzStorageAccount|?{$_.Kind -eq "FileStorage"} )
$Context=(Get-AzStorageAccount |select Context).count

##################################################################################
###Getting Azure File Share with Quota information Information 

$Storage_Information=@()
foreach($straccunt in $straccName){
if($straccunt.PrimaryEndpoints.file -ne $null){
$Storage_Information+= (Get-AzStorageShare -Context $straccunt.Context -ErrorAction Ignore|?{$_.IsSnapshot -eq $false}|Select @{n="StorageName";e={($straccunt.StorageAccountName)}},@{n="FileShare";e={($_.Name)}},@{n="Quota(TB)";e={("{0:N2}" -f($_.Quota/1024))}})
}
}

#################################################################################
###Getting Azure File Share utlization Information 
$Usage=@()

foreach($str in $straccName){

$client= (((Get-AzStorageShare -Context $str.Context -ErrorAction SilentlyContinue  |?{$_.IsSnapshot -eq $false}).ShareClient))

foreach($uri in $client){
$Usage+= (($uri.GetStatistics()).value)|Select @{n="StorageName";e={($str.StorageAccountName)}},@{n="FileShare";e={($uri.Name)}} ,@{n="Usage(TB)";e={("{0:N2}" -f($_.ShareUsageInBytes/1TB))}}

}
}

##################################################################################

###Getting Azure File Share Available and FreeSpace and FreeSpace% Information 
$Storage_Information_List =[System.Collections.ArrayList]@($Storage_Information)
foreach($i in $Storage_Information_List){

$i |Add-Member -MemberType NoteProperty -Name 'Usage(TB)' -Value($Usage|?{($_.StorageName -eq $i.StorageName)-and($_.FileShare -eq $i.FileShare)}).'Usage(TB)' -Force

}


foreach($i in $Storage_Information_List){

#$i |Add-Member -MemberType NoteProperty -Name 'Available(TB)' -Value((($Storage_Information|?{$_.Name -eq $i.Name})."Quota(TB)")-(($Storage_Information|?{$_.Name -eq $i.Name})."Usage(TB)")) -Force

$i|Add-Member -MemberType NoteProperty -Name 'Available(TB)' -Value(($i.'Quota(TB)') -($i.'Usage(TB)')) -Force 

}

foreach($i in $Storage_Information_List){

#$i |Add-Member -MemberType NoteProperty -Name 'Available(TB)' -Value((($Storage_Information|?{$_.Name -eq $i.Name})."Quota(TB)")-(($Storage_Information|?{$_.Name -eq $i.Name})."Usage(TB)")) -Force

$i|Add-Member -MemberType NoteProperty -Name 'FreeSpace(%)' -Value ("{0:N2}" -f(($i.'Available(TB)')/($i.'Quota(TB)')*100)) -Force 

}   

###Getting Azure File Share Available and FreeSpace and FreeSpace% Information

foreach($i in $Storage_Information_List){

#$i |Add-Member -MemberType NoteProperty -Name 'Available(TB)' -Value((($Storage_Information|?{$_.Name -eq $i.Name})."Quota(TB)")-(($Storage_Information|?{$_.Name -eq $i.Name})."Usage(TB)")) -Force
<#
###Available(TB)  -lt 300 GB ================>Crtical(Red)
###Available(TB)  -gt 300 GB & -lt 500 GB ===>Warning(Yellow)
###Available(TB)  -gt 500 GB=================>Normal(Green)
#>
if($i.'Available(TB)'  -le 0.29){$i|Add-Member -MemberType NoteProperty -Name 'StorageStatus' -Value ("Critical")  -Force}

elseif(($i.'Available(TB)' -gt 0.29) -and($i.'Available(TB)' -le  0.49)){$i|Add-Member -MemberType NoteProperty -Name 'StorageStatus' -Value ("Warning")  -Force }
else {$i|Add-Member -MemberType NoteProperty -Name 'StorageStatus' -Value ("Normal")  -Force}

}        
     
#$final_Str_Information=$Storage_Information_List |Format-Table -autosize -Force


##################################################################################
#Fetching the NetApp files pool information from azure portal 

$ANF_RG='Azure-NetApp-RG1'
$ANF_StorageAccount= (Get-AzNetAppFilesAccount -ResourceGroupName $ANF_RG).Name
$ANF_pool =((Get-AzNetAppFilesPool -ResourceGroupName $ANF_RG -AccountName ($ANF_StorageAccount)).Name).Split("/")[1]

$ANF_Volume_name= Get-AzNetAppFilesVolume -ResourceGroupName $ANF_RG -AccountName $ANF_StorageAccount -PoolName $ANF_pool|?{$_.CreationToken -notlike "*cache*"} |select @{n="DRFileShare";e={$_.CreationToken}},@{n="Quota(TB)";e={("{0:N2}" -f($_.UsageThreshold/1TB))}}

###Fetching the details of utilized sapce in NetApp fileShare ##Pulling it manually as command is not pulling th mount information from portal.
$mount_path="\\netAppfileshare.cloud9vin.com"
$Utilized_Space=@()
$ANF_Volume =[System.Collections.ArrayList]@($ANF_Volume_name)

foreach($Space in $ANF_Volume_name){

Write-Host "Calculating the total space in TB for $(($Space).'DRFileShare')" -ForegroundColor Yellow
$Utilized_Space=Get-ChildItem -Path $mount_path\$(($Space).'DRFileShare') -Recurse -Force -ea Ignore |Measure-Object -Property Length -Sum | Select-Object @{n="Size(TB)";e={("{0:N2}" -f($_.Sum/1TB))}}

###Adding the ultilize sapce as 'Usage(TB)' and mountpath too

$Space |Add-Member -MemberType NoteProperty -Name 'Usage(TB)' -Value ($($Utilized_Space).'Size(TB)') -Force

}

#################################################################################

######################################################################################
##fetching the Availabel spsace in TB
foreach($i in $ANF_Volume_name){

$i|Add-Member -MemberType NoteProperty -Name 'Available(TB)' -Value(($i.'Quota(TB)') -($i.'Usage(TB)')) -Force 
$i | Add-Member -MemberType NoteProperty -Name 'FileSharepath' -Value ("$mount_path\$(($i).DRFileShare)")
}

######################################################################################
###Free Space Percentage for NetApp file Share volume
foreach($i in $ANF_Volume_name){


$i|Add-Member -MemberType NoteProperty -Name 'FreeSpace(%)' -Value ("{0:N2}" -f(($i.'Available(TB)')/($i.'Quota(TB)')*100)) -Force 

}   

######################################################################################
###Creating Colour code colum e.g normal,warning,error

foreach($i in $ANF_Volume_name){

<#
###Available(TB)  -lt 300 GB ================>Crtical(Red)
###Available(TB)  -gt 300 GB & -lt 500 GB ===>Warning(Yellow)
###Available(TB)  -gt 500 GB=================>Normal(Green)
#>
if($i.'Available(TB)'  -le 0.29){$i|Add-Member -MemberType NoteProperty -Name 'StorageStatus' -Value ("Critical")  -Force}

elseif(($i.'Available(TB)' -gt 0.29) -and($i.'Available(TB)' -le  0.49)){$i|Add-Member -MemberType NoteProperty -Name 'StorageStatus' -Value ("Warning")  -Force }
else {$i|Add-Member -MemberType NoteProperty -Name 'StorageStatus' -Value ("Normal")  -Force}

}    
######################################################################################

$ANF_Volume_name_final=$ANF_Volume_name| select FileSharepath,DRFileShare,'Quota(TB)','Usage(TB)','Available(TB)','FreeSpace(%)',StorageStatus
##################################################################################


###Writing the entire data  in  html file
Write-Host ("Saving results to html report: " + $resultsHTM)
writeHtmlHeader "Azure WVD Hostpool and FileShare HealthCheck Report" $resultsHTM 
writeTableFooter $resultsHTM

writeTableHeader $resultsHTM $AzhpFirstheaderName $AzhpHeaderNames $AzhpHeaderWidths $AzhpTableWidth
$TotalVMArrListResults  | %{ writeData $TotalVMArrListResults $resultsHTM $AzhpHeaderNames }
writeTableFooter $resultsHTM

$AfterRebootHostpoolarraylist | ConvertTo-Html -head $HostpoolHeader  | ForEach {
$PSItem -replace ("<td>Unavailable</td>", "<td style='background-color:#FF0000'>Unavailable</td>") -replace ("<td>upgrading</td>", "<td style='background-color:#FF7700'>Upgrading</td>")
}  | out-file $resultsHTM -Append
writeTableFooter $resultsHTM

$Storage_Information_List | ConvertTo-Html -head $HostpoolHeader  | ForEach {
$PSItem -replace ("<td>Critical</td>", "<td style='background-color:#FF0000'>Critical</td>") -replace 
("<td>Warning</td>", "<td style='background-color:#FF7700'>Warning</td>") -replace
("<td>Normal</td>", "<td style='background-color:#387C44'>Normal</td>")
}  | out-file $resultsHTM -Append
writeTableFooter $resultsHTM

####Adding the NetApp file Share information in html.
$ANF_Volume_name_final | ConvertTo-Html -head $HostpoolHeader  | ForEach {
$PSItem -replace ("<td>Critical</td>", "<td style='background-color:#FF0000'>Critical</td>") -replace 
("<td>Warning</td>", "<td style='background-color:#FF7700'>Warning</td>") -replace
("<td>Normal</td>", "<td style='background-color:#387C44'>Normal</td>")
}  | out-file $resultsHTM -Append
writeTableFooter $resultsHTM

writeHtmlFooter $resultsHTM 
#$Storage_Information_List|ConvertTo-Html -head $HostpoolHeader|Format-Table -AutoSize| out-file $resultsHTM -Append



##################################################################################
<#
###Email Notification with report to citrixDL
$emailFrom="Azure-HealthCheck-alerts@outlook.com"
$emailTo="Naveenarya198@outlook.com"
$emailCC="Naveenarya198@outlook.com"
$emailSubject='Azure WVD and FileShare HealthCheck Report-'+ (Get-Date)
$smtpServer='10.163.35.40'
$smtpServerPort=25
$emailPriority="Low"


$resultsHTM='\\10.0.0.4\CTXSupport\Naveen\Do_not_Run\Azure\AzureHealthCheck.htm'
$emailMessage = New-Object System.Net.Mail.MailMessage
$emailMessage.From = $emailFrom
$emailMessage.To.Add( $emailTo )
$emailMessage.CC.Add( $emailCC )
$emailMessage.Subject = $emailSubject 
$emailMessage.IsBodyHtml = $true
$emailMessage.Body = (gc $resultsHTM) | Out-String
$emailMessage.Attachments.Add($resultsHTM)
$emailMessage.Priority = ($emailPriority)

$smtpClient = New-Object System.Net.Mail.SmtpClient( $smtpServer , $smtpServerPort )
#$smtpClient.EnableSsl = $smtpEnableSSL

$smtpClient.Send( $emailMessage )
write-host "Mail has been Sent from:$emailFrom" -BackgroundColor Green 
$emailMessage.Attachments.Dispose()
#>
Write-Host "Transacript Completed by  $env:userName for HealthCheck report" -ForegroundColor Green
Write-Host "Script End Time " -NoNewline -ForegroundColor Gray; Write-Host $(Get-Date -Format HH:mm:ss) -ForegroundColor Gray ; 

Stop-Transcript
##################################################################################