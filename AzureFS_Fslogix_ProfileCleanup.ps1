<####
*************************************************************
 .SYNOPSIS

# Created on: 31.03.2023 Version: 1.0
# Created by: Naveen
# Description: This script is use to delete the Azure User Profile who has not accesed it from 60 days
# Call by : Manual or by Scheduled Task via SCCM#
##Incase you are using PIM.Make sure you you active the role before running the script or else use the account which doesn't require PIM

Note:! Read it once before your run it 
Do not run below script untill you are not sure what script is actually doing

Contact at Naveenarya198@outlook.com for any query.
*************************************************************
#>

Start-Transcript -Path "\\10.0.0.0\Citrix\Auto\Azure\Azure_fileShare_User_ProfileClenup\prod_Profile_$((get-date -Format 'ddMMyyy')).txt"

##Importing the Azure Module
##Importing azure modules 
Write-Host
Write-Host $(Get-Date -Format HH:mm:ss:) -ForegroundColor Gray -NoNewLine ; Write-Host ” Importing PowerShell Modules”

$Modules = @(‘Az’,'Microsoft.RDInfra.RDPowershell') ##importing the Azure Module

Foreach ($Module in $Modules) {
if((Get-Module -Name $Module -ErrorAction SilentlyContinue) -eq $false) {
Write-Host $(Get-Date -Format HH:mm:ss:) -ForegroundColor Gray -NoNewLine ; Write-Host ” Importing Module” $Module -ForegroundColor DarkYellow
Import-Module -Name $Module -Verbose -ErrorAction SilentlyContinue
}
Else {
Write-Host $(Get-Date -Format HH:mm:ss:) -ForegroundColor Gray -NoNewLine ; Write-Host ” PowerShell Module ” -NoNewline -ForegroundColor DarkYellow ; Write-Host “‘$Module'” -NoNewline -ForegroundColor DarkCyan ; Write-Host ” already imported” -ForegroundColor DarkYellow
}
}

###Variable 
$User="$env:username@Test.com"
$domaincred = get-credential -Message "Login with your Admin-Account:" -UserName($User ) ##Login with Account which has storage/Azure contirubutor access 
$UserName=$domaincred.UserName
$password=$domaincred.Password
$credential = New-Object System.Management.Automation.PSCredential ($UserName, $password)
Connect-AzAccount -Subscription 'Test-Subscription' -Credential (Get-Credential -Credential $credential)

#######################Connecting to Azure portal and pulling the Azure FIle Share information#######################
$straccName=(Get-AzStorageAccount|?{$_.Kind -eq "FileStorage"} )|select StorageAccountName,Context |Out-GridView -Title "Select the Storage Account:Single/multiple " -OutputMode Multiple  #you can chose single or multiple fileShare 
 if(!$straccName){Write-Host "No Storage selected, exiting script...";start-sleep -seconds 10;} 

$Context=(Get-AzStorageAccount |select Context).count

##################################################################################

#######################Creating the fileShare Name from Storage Account#######################

$file_Share_path=@()
foreach($straccunt in $straccName){
$File_Share= (Get-AzStorageShare -Context $straccunt.Context -ErrorAction Ignore|?{($_.IsSnapshot -eq $false)-and ($_.Name -inotlike "*Cache*")}).Name
foreach($file in $File_Share)
{
$file_Share_path+=(($straccunt.Context).FileEndPoint -replace("https:", "")).Replace("/","\")+ $file
}
}
Write-Host "Select Sharefile path are:"
foreach($i in $file_Share_path){
Write-Host $(Get-Date -Format HH:mm:ss:) -ForegroundColor Gray -NoNewLine; Write-Host " Selected FileShare is :" -ForegroundColor DarkYellow -NoNewline; Write-Host " $i" -ForegroundColor DarkCyan 
}

##################################################################################rofiles}
$nowtime=Get-Date

###Main script for deleting the profiles
foreach($prof in $file_Share_path){
if($LW = (Get-childItem -Path ($prof) -ErrorAction Ignore)){
###\\10.0.0.0\Citrix\Auto\Azure\Azure_fileShare_User_ProfileClenup ---> FileShare path
$Lw|select @{n="Profile";e={$i}},Name,LastWriteTime,FullName|Format-Table -AutoSize |Out-File "\\10.0.0.0\Citrix\Auto\Azure\Azure_fileShare_User_ProfileClenup\Profiles_$((get-date -Format 'ddMMyyy')).csv" -Append


}


foreach($folder in $LW){


#Deleting the citrix Azure  profile which are older than 60 days ===>Change here

if($file=Get-ChildItem -Path "$prof\$(($folder).Name)" -Filter "*vhd" -Recurse -ErrorAction Ignore){

if($count=(($file | select Name,LastWriteTime,@{n="Profile";e={$i}}|Group-Object Profile)).Count-eq 1 ){

###chekcing if file last modidied date is more than 60 days
if(((New-TimeSpan -Start $file.LastWriteTime -End $nowtime).Days) -gt 60){

Write-Host $(Get-Date -Format HH:mm:ss:) -ForegroundColor Gray -NoNewLine; Write-Host " Calculating the total space in GB for " -ForegroundColor DarkYellow -NoNewline; Write-Host "$(($file).Name)" -ForegroundColor DarkCyan
$Space_Beforcleanup=Get-ChildItem -Path "$prof\$(($folder).Name)"  -Recurse -Force -ea Ignore |Measure-Object -Property Length -Sum | Select-Object @{n="Size(GB)";e={("{0:N2}" -f($_.Sum/1GB))}}

Write-Host "$prof : $(($folder).Name):$(($file).Name):$((New-TimeSpan -Start $file.LastWriteTime -End $nowtime).Days) : $(($Space_Beforcleanup).'Size(GB)') : Can be Deleted"  -BackgroundColor black

Write-Host "$prof\$(($folder).Name)"  -BackgroundColor black

Remove-Item -Path "$prof\$(($folder).Name)" -Recurse -Force -ErrorAction Ignore

"$prof : $(($folder).Name):$(($file).Name):$((New-TimeSpan -Start $file.LastWriteTime -End $nowtime).Days) : $(($Space_Beforcleanup).'Size(GB)') : Can be Deleted " |Out-File "\\10.0.0.0\Citrix\Auto\Azure\Azure_fileShare_User_ProfileClenup\Prod_Prof_Deletion_$((get-date -Format 'ddMMyyy')).csv" -Append

########################
##Deleting the $(($folder).Name) by robocopy if #remove-commands fails due to large file name error ---This was specific to our Environment.

if(Test-Path "$prof\$(($folder).Name)"){

Write-host "RoboCopy $prof\$(($folder).Name)" -ForegroundColor Cyan

robocopy \\10.0.0.0\CTXSupport\Naveen\RoboCopy   "$prof\$(($folder).Name)" /purge
"$Prof  :  $(($folder).Name)  : RoboDelete" |Out-File "\\10.0.0.0\Citrix\Auto\Azure\Azure_fileShare_User_ProfileClenup\Prod_gops_ccu_RoboCopy_Prof_Deletion_$((get-date -Format 'ddMMyyy')).csv" -Append 
Remove-Item "$prof\$(($folder).Name)" -Recurse -Force -ErrorAction SilentlyContinue 
}

}

else{

$Space=Get-ChildItem -Path "$prof\$(($folder).Name)"  -Recurse -Force -ea Ignore |Measure-Object -Property Length -Sum | Select-Object @{n="Size(GB)";e={("{0:N2}" -f($_.Sum/1GB))}}
Write-Host "$i : $(($folder).Name):$(($file).Name):$((New-TimeSpan -Start $file.LastWriteTime -End $nowtime).Days):Skipped"  -BackgroundColor Blue
"$prof : $(($folder).Name):$(($file).Name):$((New-TimeSpan -Start $file.LastWriteTime -End $nowtime).Days): $space  : Skipped" |Out-File "\\10.0.0.0\Citrix\Auto\Azure\Azure_fileShare_User_ProfileClenup\Prod_Skipped_$((get-date -Format 'ddMMyyy')).csv" -Append


}

}
}

}
}

Stop-Transcript
