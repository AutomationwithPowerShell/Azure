<####
*************************************************************
 .SYNOPSIS

# Created on: 10.03.2025 Version: 1.1
# Created by: Naveen
# Key Contributor:
# Description: This script is use to delete the NetApp User Profile who has not accesed it from 60 days
# Call by : Manual or by Scheduled Task via SCCM#

Note:! Read it once before your run it 
Do not run below script untill you are not sure what script is actually doing it

Contact at Naveen.Ram@Test.com for any query.

\\NFileShareName.Test.com\azwvdprdshdr01

*************************************************************
#>

Start-Transcript -Path "\\10.0.0.0\Citrix\Auto\Azure\Azure_fileShare_User_ProfileClenup\DR_Profile_$((get-date -Format 'ddMMyyy')).txt"

$Dr_FileShare_path="\\NFileShareName.Test.com"
$File_ShareName="Prod1"

#\\NFileShareName.Test.com\Prod1
#\\NFileShareName.Test.com\Prod2
#\\NFileShareName.Test.com\Prod3
#\\NFileShareName.Test.com\Prod4


##################################################################################rofiles}
$nowtime=Get-Date

foreach($prof in $File_ShareName){

if($LW = (Get-ChildItem -Path $Dr_FileShare_path\$prof -ErrorAction Ignore)){

$Lw|select @{n="Profile";e={$i}},Name,LastWriteTime,FullName|Format-Table -AutoSize |Out-File "\\10.0.0.0\Citrix\Auto\Azure\Azure_fileShare_User_ProfileClenup\DR_Profiles_$((get-date -Format 'ddMMyyy')).csv" -Append


}


foreach($folder in $LW){


#Deleting the citrix Azure  profile which are older than 60 days

if($file=Get-ChildItem -Path $(($folder).FullName) -Filter "*vhdx" -Recurse -ErrorAction Ignore){

if($count=(($file | select Name,LastWriteTime|Group-Object Profile)).Count-eq 1 ){

###chekcing if file last modidied date is more than 60 days
if(((New-TimeSpan -Start $file.LastWriteTime -End $nowtime).Days) -gt 60){

Write-Host "Calculating the total space in GB for $(($file).Name)" -ForegroundColor Yellow
$Space_Beforcleanup=Get-ChildItem -Path "$(($folder).FullName)"  -Recurse -Force -ea Ignore |Measure-Object -Property Length -Sum | Select-Object @{n="Size(GB)";e={("{0:N2}" -f($_.Sum/1GB))}}

Write-Host "$prof : $(($folder).Name):$(($file).Name):$((New-TimeSpan -Start $file.LastWriteTime -End $nowtime).Days) : $(($Space_Beforcleanup).'Size(GB)') : Can be Deleted"  -BackgroundColor black

Write-Host "$(($folder).FullName)"  -ForegroundColor Cyan

#Remove-Item -Path "$(($folder).FullName)" -Recurse -Force 

"$prof : $(($folder).Name):$(($file).Name):$((New-TimeSpan -Start $file.LastWriteTime -End $nowtime).Days) : $(($Space_Beforcleanup).'Size(GB)') : Can be Deleted " |Out-File "\\10.0.0.0\Citrix\Auto\Azure\Azure_fileShare_User_ProfileClenup\DR_Prof_Deletion_$((get-date -Format 'ddMMyyy')).csv" -Append

########################
##Deleting the $(($folder).Name) by robocopy if #remove-commands fails due to large file name error.

if(Test-Path "$(($folder).FullName)"){

Write-host "$(($folder).FullName)" -ForegroundColor Cyan

#robocopy \\10.0.0.0\CTXSupport\Naveen\RoboCopy   "$(($folder).FullName)" /purge 
"$Prof  :  $(($folder).Name)  : RoboDelete" |Out-File \\10.0.0.0\Citrix\Auto\Azure\Azure_fileShare_User_ProfileClenup\Share4_robocopy_profile.csv -Append
#Remove-Item "$prof\$(($folder).Name)" -Recurse -Force -ErrorAction SilentlyContinue 

}

}

else{

$Space=Get-ChildItem -Path "$(($folder).FullName)"  -Recurse -Force -ea Ignore |Measure-Object -Property Length -Sum | Select-Object @{n="Size(GB)";e={("{0:N2}" -f($_.Sum/1GB))}}
Write-Host "$prof : $(($folder).FullName) : $(($file).Name):$((New-TimeSpan -Start $file.LastWriteTime -End $nowtime).Days):Skipped"  -BackgroundColor Blue
"$prof : $(($folder).Name):$(($file).Name):$((New-TimeSpan -Start $file.LastWriteTime -End $nowtime).Days): $space  : Skipped"  |Out-File "\\10.0.0.0\Citrix\Auto\Azure\Azure_fileShare_User_ProfileClenup\DR_Prof_Skipped_$((get-date -Format 'ddMMyyy')).csv" -Append


}

}
}

}
}

Stop-Transcript



