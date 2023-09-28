<#
.DESCRIPTION
.NOTES
    Version       : 0.0.1
    Author        : Christopher Mogis
    Creation Date : 15/09/2023
#>

#Declaration des variables
$Date = Get-Date -Format "HH:mm"
$DeviceName = $(Get-WmiObject Win32_Computersystem).name
$logfilepath = "C:\Temp\HAADJ_CoMan_$Devicename.csv"
$Domain = dsregcmd /status
$Continue = $True

#Declaration de la fonction Toast
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

#Execution du script
While($Continue) {

    Start-Sleep -s 5
    
    #Verification des certificats
    try {
    $CertDetailMS = Get-ChildItem -Path 'Cert:\LocalMachine\My' –Recurse
    $CertDetailMS | Select-Object @{n="Issuer";e={(($_.Issuer -split ",") |? {$_ -like "CN=*"}) -replace "CN="}}
    $CertDetailMSOrganization = ($CertDetailMS -like "*MS-Organization*").count
    Write-Host "Vérification de la présence des certificats MS-Organization" -ForegroundColor Green
    if ($CertDetailMSOrganization -eq '2')
        {
        $ResultCertDetailMSOrganization = "Yes"
        }
    else
        {
        $ResultCertDetailMSOrganization = "No"
        }
    }
    catch
    {
        Write-Host "Impossible de verifier la présence des certificats MS-Organization" -ForegroundColor Red
    }
    
    #Device Domain Join verification
	try {
    $AD = $Domain | Where-Object {$_ -like "*DomainJoined : Yes*"}
    $ResultAD = if ($AD) {"Yes"}else{"No"}
	Write-Host "Verification de la connectivité à l'AD" -ForegroundColor Green
	}
	catch
	{
		Write-Host "Ordinateur non connecté à l'AD" -ForegroundColor	Red
	}
    
    #Search Device Azure AD Joined
	try {
    $AAD = $Domain | Where-Object {$_ -like "*AzureAdJoined : Yes*"}
    $ResultAAD = if ($AAD) {"Yes"}else{"No"}
	Write-Host "Verification de la connectivité à l'AzureAD" -ForegroundColor Green
	    #if ($ResultAAD -ne 'Yes')
    #{
        #Start-ScheduledTask "\Microsoft\Windows\Workplace Join\Automatic-Device-Join"
    #}
	}
	catch
	{
		Write-Host "Impossible de verifier la connectivité à l'AzureAD" -ForegroundColor Red
	}

    
    #Verification de l'existance de la cle JoinInfo
	try {
    $JoinInfo = Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
	Write-Host	"Récupération de la valeur de registre JoinInfo" -ForegroundColor Green
    if ($JoinInfo -eq "True")
		{
        $RJoinInfo = "Yes"
		}
    else 
		{
        $RJoinInfo = "No"    
		}
    }
	catch
	{
		Write-Host	"Impossible de récupérer les informations de la valeur de registre JoinInfo" -ForegroundColor Red
	}
	
    #Verification de l'existance de la cle DeviceClientID
	try {
    $regKeyPath01 = "HKLM:\\SOFTWARE\Microsoft\Provisioning\OMADM\MDMDeviceID"
    $regValueName01 = "DeviceClientId"
    $DeviceClientID = (Get-Item $regKeyPath01 -EA Ignore).Property -contains $regValueName01
	Write-Host	"Récupération de la valeur de registre DeviceID" -ForegroundColor Green
    if ($DeviceClientID -eq "True")
    {
        $RDeviceClientID = "Yes"
    }
    else 
    {
        $RDeviceClientID = "No"    
    }
	}
	catch
	{
		Write-Host	"Impossible de récupérer les informations de la clé de registre DeviceID" -ForegroundColor Red
	}	
    
    #Verification de l'agent SCCM
	try {
    $SCCMService = (Get-Service -Name CcmExec).Status
	Write-Host	"Récupération du status du service SCCM" -ForegroundColor Green
    if ($SCCMService -eq "Running")
		{
        $RSCCMService = "Yes"
		}
    else 
		{
        $RSCCMService = "No"  
		}
    }
	catch
	{
		Write-Host	"Impossible de récupérer le status du service SCCM " -ForegroundColor Red
	}
	
    #Verification gestion Microsoft Intune
	try {
    $INTUNEService = (Get-Service -Name IntuneManagementExtension).Status
	Write-Host	"Recuperation du status du service MS Intune" -ForegroundColor Green
    if ($INTUNEService -eq "Running")
		{
        $RIntuneService = "Yes"
		}
    else 
		{
        $RIntuneService = "No"  
		}
    }
	catch
	{
		Write-Host " Impossible de récupérer l'etat du service MS Intune" -ForegroundColor Red
	}	
	
    #Verification de la presence du certificat MS Intune
	try {
    $CertDetailIntune = Get-ChildItem -Path 'Cert:\LocalMachine\My' –Recurse
    $CertDetailIntune | Select-Object @{n="Issuer";e={(($_.Issuer -split ",") |? {$_ -like "CN=*"}) -replace "CN="}}
    $ResultCertDetailIntune = if ($CertDetailIntune -like "*Intune*") {"Yes"}else{"No"}
    Write-Host	"Recuperation du status de certificat Intune" -ForegroundColor Green
    }
	catch
	{
		Write-host "Impossible de récupérer le status de l'antispyware" -ForegroundColor Red
	}
	
    #Verification Windows Defender
	try {
    $ED01 = (Get-MpComputerStatus).AntispywareEnabled
	Write-Host	"Recuperation du status de l'antispyware" -ForegroundColor Green
		if ($ED01 -eq "True")
		{
			$RED01 = "Yes"
		}
    else 
		{
			$RED01 = "No"    
		}
	}
	catch
    {
        Write-Host "Impossible de récupérer le status de l'antispyware" -ForegroundColor Red
    }
    
	try {
    $ED02 = (Get-MpComputerStatus).AntivirusEnabled
	Write-Host "Récupération du status de l'antivirus" -ForegroundColor Green
    if ($ED02 -eq "True")
    {
        $RED02 = "Yes"
    }
    else 
    {
        $RED02 = "No"   
    }
	}
		catch
    {
        Write-Host "Impossible de récupérer le status de l'antivirus" -ForegroundColor Red
    }
    
	try {
    $ED03 = (Get-MpComputerStatus).OnAccessProtectionEnabled
	Write-Host "Récupération du status OnAccessProtectionEnabled" -ForegroundColor Green
    if ($ED03 -eq "True")
    {
        $RED03 = "Yes"
    }
    else 
    {
        $RED03 = "No"    
    }
    }
		catch
    {
        Write-Host "Impossible de récupérer le status du module OnAccessProtectionEnabled" -ForegroundColor Red
    }
	
	try {
    $ED04 = (Get-MpComputerStatus).RealTimeProtectionEnabled
	Write-Host "Récupération du status du module Real Time Protection" -ForegroundColor Green
    if ($ED04 -eq "True")
    {
        $RED04 = "Yes"
    }
    else 
    {
        $RED04 = "Yes"    
    }
    }
	catch
    {
        Write-Host "Impossible de récupérer le status du module Real Time Protection" -ForegroundColor Red
    }
	
	try {
    $ED05 = (Get-MpComputerStatus).TamperProtectionSource
	Write-Host "Récupération du status du TamperProtectionSource" -ForegroundColor Green
    if ($ED05 -eq "Intune")
    {
        $RED05 = "Yes"
    }
    else 
    {
        $RED05 = "No"  
    }
    }
	catch
    {
        Write-Host "Impossible de récupérer le status du TamperProtectionSource" -ForegroundColor Red
    }
	
    #Verification Windows Firewall
	try {
    $fw = Get-NetFirewallRule -PolicyStore ActiveStore -PolicyStoreSource MDM | Sort-Object DisplayName | Select-Object Name
	Write-Host "Récupération du status du Firewall" -ForegroundColor Green
    $fwrule = $fw.Count
    if ($fwrule -ge "85")
    {
        $Resultfw = 'Yes'
    }
    else 
    {
        $Resultfw = 'No'
    }
	}
	catch
	{
        Write-Host "Impossible de récupérer le status du Firewall" -ForegroundColor Red
    }

    #Check HAADJ
    If ($ResultAD -eq 'Yes' -AND $ResultAAD -eq 'Yes' -AND $RJoinInfo -eq 'Yes' -AND $RDeviceClientID -eq 'Yes' -AND $ResultCertDetailMSOrganization -eq 'Yes')
    {
        $HAADJ = 'Yes'
    }
    else 
    {
        $HAADJ = 'No'
    }
    
    #Check Co-Management
    If ($RSCCMService -eq 'Yes' -AND $RINTUNEService -eq 'Yes' -AND $ResultCertDetailIntune -eq 'Yes')
    {
        $CoMgnt = 'Yes'
    }
    else 
    {
        $CoMgnt = 'No'
    }
    
    #Check Windows Defender and Windows firewall
    If ($ED01 -eq 'True' -AND $ED02 -eq 'True' -AND $ED03 -eq 'True' -AND $ED04 -eq 'True' -AND $ED05 -eq 'Intune' -AND $Resultfw -eq 'Yes')
    {
        $WinDef = 'Yes'
    }
    else 
    {
        $WinDef = 'No'
    }

    #Report
    $report = New-Object psobject
    $report | Add-Member -MemberType NoteProperty -name "Date" -Value "$($Date)"
    $report | Add-Member -MemberType NoteProperty -name "Certificat MS-Organization" -Value $ResultCertDetailMSOrganization
    $report | Add-Member -MemberType NoteProperty -name "Device connecte au domaine" -Value $ResultAD
    $report | Add-Member -MemberType NoteProperty -name "Device connecte a Azure AD" -Value $ResultAAD
    $report | Add-Member -MemberType NoteProperty -name "Cle de registre JoinInfo" -Value $RJoinInfo 
    $report | Add-Member -MemberType NoteProperty -name "Cle de registre DeviceClientID" -Value $RDeviceClientID
    $report | Add-Member -MemberType NoteProperty -name "Etat Service SCCM" -Value $RSCCMService 
    $report | Add-Member -MemberType NoteProperty -name "Etat Microsoft Intune" -Value $RIntuneService
    $report | Add-Member -MemberType NoteProperty -name "Certificat MS Intune" -Value $ResultCertDetailIntune 
    $report | Add-Member -MemberType NoteProperty -name "Module Antispyware actif" -Value $RED01
    $report | Add-Member -MemberType NoteProperty -name "Module antivirus actif" -Value $RED02
    $report | Add-Member -MemberType NoteProperty -name "Module OnAccessProtectionEnabled configure" -Value $RED03
    $report | Add-Member -MemberType NoteProperty -name "Protection en temps reel activee" -Value $RED04 
    $report | Add-Member -MemberType NoteProperty -name "Tamper protection configure sur via Intune" -Value $RED05
    $report | Add-Member -MemberType NoteProperty -name "Regles de firewall" -Value $Resultfw 
    $report | Add-Member -MemberType NoteProperty -name "Configuration HAADJ" -Value $HAADJ
    $report | Add-Member -MemberType NoteProperty -name "CoManagement SCCM Intune" -Value $CoMgnt 
    $report | Add-Member -MemberType NoteProperty -name "Windows firewall et Microsoft Defender" -Value $WinDef
    $report | export-csv -NoTypeInformation -Path $logfilepath -Delimiter ";" -Append


#Notification pour l'admin
If ($HAADJ -eq 'Yes' -and $CoMgnt -eq 'Yes' -and $WinDef -eq 'Yes')

    {

    balloon "CAGIP - Information" "Votre poste $Devicename est prêt !" 5000
    ($Continue = $false)

    }
        
}
