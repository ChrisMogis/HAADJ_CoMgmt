<#
.DESCRIPTION
.NOTES
    Version       : 1.0.0
    Author        : Christopher Mogis
    Creation Date : 10/10/2023
#>

#Variables
$DeviceName = $(Get-WmiObject Win32_Computersystem).name
$logfilepath = "C:\Temp\HAADJ_CoMan_$Devicename.csv"
$Continue = $True

#function Toast Notification
function balloon([string]$Titre, [string]$Texte, [int]$duree){ 

$app = "{D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27}\WindowsPowerShell\v1.0\PowerShell.exe"

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
$Template = [Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText01
[xml]$ToastTemplate = ([Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($Template).GetXml())

[xml]$ToastTemplate = @"
<toast>
<visual>
<binding template="ToastGeneric">
<text hint-maxLines="2">$Titre</text>
<text>$texte</text>
<image src="file:///c:\windows\system32\SecurityAndMaintenance.png" placement="appLogoOverride"/>
</binding>
</visual>

<audio silent="False"/>
</toast>
"@

$ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
$ToastXml.LoadXml($ToastTemplate.OuterXml)
$notify = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app)
$notify.Show($ToastXml)
}

#Script execution
While($Continue) {

    Start-Sleep -s 5

    #Variables
    $Date = Get-Date
    $Domain = dsregcmd /status
    
    #Check certificates
    $CertDetailMS = Get-ChildItem -Path 'Cert:\LocalMachine\My' –Recurse
    $CertDetailMS | Select-Object @{n="Issuer";e={(($_.Issuer -split ",") |? {$_ -like "CN=*"}) -replace "CN="}}
    $CertDetailMSOrganization = ($CertDetailMS -like "*MS-Organization*").count
    Write-Host "Vérification de la présence des certificats MS-Organization" -ForegroundColor Yellow
    if ($CertDetailMSOrganization -eq '2')
        {
        $ResultCertDetailMSOrganization = "Yes"
        }
    else
        {
        $ResultCertDetailMSOrganization = "No"
        }

    #Device Domain Join verification
    $AD = $Domain | Where-Object {$_ -like "*DomainJoined : Yes*"}
    $ResultAD = if ($AD) {"Yes"}else{"No"}
	Write-Host "Verification de la connectivité à l'AD" -ForegroundColor Yellow
    
    #Search Device Azure AD Joined
    $AAD = $Domain | Where-Object {$_ -like "*AzureAdJoined : Yes*"}
    $ResultAAD = if ($AAD) {"Yes"}else{"No"}
	Write-Host "Verification de la connectivité à l'AzureAD" -ForegroundColor Yellow

    #JoinInfo registry key verification
    $JoinInfo = Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
	Write-Host	"Récupération de la valeur de registre JoinInfo" -ForegroundColor Yellow
    if ($JoinInfo -eq "True")
		{
        $RJoinInfo = "Yes"
		}
    else 
		{
        $RJoinInfo = "No"
		}
	
    #DeviceClientID registry key verification
    $regKeyPath01 = "HKLM:\\SOFTWARE\Microsoft\Provisioning\OMADM\MDMDeviceID"
    $regValueName01 = "DeviceClientId"
    $DeviceClientID = (Get-Item $regKeyPath01 -EA Ignore).Property -contains $regValueName01
	Write-Host	"Récupération de la valeur de registre DeviceID" -ForegroundColor Yellow
    if ($DeviceClientID -eq "True")
    {
        $RDeviceClientID = "Yes"
    }
    else 
    {
        $RDeviceClientID = "No"    
    }	
    
    #Check SCCM Agent
    $SCCMService = (Get-Service -Name CcmExec).Status
	Write-Host	"Récupération du status du service SCCM" -ForegroundColor Yellow
    if ($SCCMService -eq "Running")
		{
        $RSCCMService = "Yes"
		}
    else 
		{
        $RSCCMService = "No"  
		}
	
    #Check Microsoft Intune service
    $INTUNEService = (Get-Service -Name IntuneManagementExtension).Status
	Write-Host	"Recuperation du status du service MS Intune" -ForegroundColor Yellow
    if ($INTUNEService -eq "Running")
		{
        $RIntuneService = "Yes"
		}
    else 
		{
        $RIntuneService = "No"  
		}
	
    #Check MS Intune certificate
    Write-Host	"Recuperation du status de certificat Intune" -ForegroundColor Yellow
    $CertDetailIntune = Get-ChildItem -Path 'Cert:\LocalMachine\My' –Recurse
    $CertDetailIntune | Select-Object @{n="Issuer";e={(($_.Issuer -split ",") |? {$_ -like "CN=*"}) -replace "CN="}}
    $ResultCertDetailIntune = if ($CertDetailIntune -like "*Intune*") {"Yes"}else{"No"}
	
	#Verification du status Azure PRT
    Write-Host "Verification du status d'Azure PRT" -ForegroundColor Yellow
	$AADPRT = $Domain | Where-Object {$_ -like "*AzureAdPrt : YES*"}
    $ResultAADPRT = if ($AADPRT) {"Yes"}else{"No"}

    #Check HAADJ
    Write-Host "Check HAADJ" -ForegroundColor Yellow
    If ($ResultAD -eq 'Yes' -AND $ResultAAD -eq 'Yes' -AND $RJoinInfo -eq 'Yes' -AND $RDeviceClientID -eq 'Yes' -AND $ResultCertDetailMSOrganization -eq 'Yes' -AND $ResultAADPRT -eq 'Yes')
    {
        $HAADJ = 'Yes'
    }
    else 
    {
        $HAADJ = 'No'
    }
    
    #Check Co-Management
    Write-Host "Check Co-Management" -ForegroundColor Yellow
    If ($RSCCMService -eq 'Yes' -AND $RINTUNEService -eq 'Yes' -AND $ResultCertDetailIntune -eq 'Yes')
    {
        $CoMgnt = 'Yes'
    }
    else 
    {
        $CoMgnt = 'No'
    }

    #Report
    $report = New-Object psobject
    $report | Add-Member -MemberType NoteProperty -name "Date" -Value "$($Date)"
    $report | Add-Member -MemberType NoteProperty -name "Certificat MS Organization" -Value $ResultCertDetailMSOrganization
    $report | Add-Member -MemberType NoteProperty -name "Device connected to AD Domain" -Value $ResultAD
    $report | Add-Member -MemberType NoteProperty -name "Device connected to Azure AD" -Value $ResultAAD
    $report | Add-Member -MemberType NoteProperty -name "Registry Key JoinInfo" -Value $RJoinInfo 
    $report | Add-Member -MemberType NoteProperty -name "Registry key DeviceClientID" -Value $RDeviceClientID
    $report | Add-Member -MemberType NoteProperty -name "SCCM service Status" -Value $RSCCMService 
    $report | Add-Member -MemberType NoteProperty -name "Microsoft Intune Service Status" -Value $RIntuneService
    $report | Add-Member -MemberType NoteProperty -name "Check MS Intune certificate" -Value $ResultCertDetailIntune 
    $report | Add-Member -MemberType NoteProperty -name "HAADJ Configuration" -Value $HAADJ
    $report | Add-Member -MemberType NoteProperty -name "CoManagement State" -Value $CoMgnt 
    $report | export-csv -NoTypeInformation -Path $logfilepath -Delimiter ";" -Append

#Notification pour l'admin
If ($HAADJ -eq 'Yes' -and $CoMgnt -eq 'Yes')

    {
    balloon "Hello $env:UserName" "Your device $Devicename is ready !" 10000
    ($Continue = $false)
    }
        
}
