<#
.NOTES
    Version       : 1.0.0
    Author        : Christopher Mogis
    Creation Date : 15/09/2023
	
.DESCRIPTION

	V1.0.0
	Ce script permet de verifier l'état des composants nécessaires pour :
		- L'hybridation AD et Azure AD
		- Activation du Co-Management SCCM / MS Intune
		- Etat du Windows Defender
		- Etat du firewall Windows et des régles appliquées sur le poste de travail
	Des que toutes les composants sont opérationnels, un rapport au format CSV est edité puis envoyé au service IT.
	L'utilisateur recoit de son coté une notification au format Toast.
	
#>

#Declaration des variables
$DeviceName = $(Get-WmiObject Win32_Computersystem).name
$logfilepath = "C:\Temp\HAADJ_CoMan_$Devicename.csv"
$LogShare = "\\wp063nas0001.commun01.svc\logpdt$\Mowe_Logs_Compliance_Script"
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

#Detection du fichier contenant les resultats du check 
$TestPathCSV = Test-Path "$($LogShare)\HAADJ_CoMan_$Devicename.csv"
If ($TestPathCSV -ne "True")
{

#Execution du script
While($Continue) {

    Start-Sleep -s 300
	
    #Variables
    $Date = Get-Date
    $Domain = dsregcmd /status
    
    #Verification des certificats
    $CertDetailMS = Get-ChildItem -Path 'Cert:\LocalMachine\My' -Recurse
    $CertDetailMS | Select-Object @{n="Issuer";e={(($_.Issuer -split ",") |? {$_ -like "CN=*"}) -replace "CN="}}
    $CertDetailMSOrganization = ($CertDetailMS -like "*MS-Organization*").count
    #Write-Host "Vérification de la présence des certificats MS-Organization" -ForegroundColor Yellow
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
	#Write-Host "Verification de la connectivité à l'AD" -ForegroundColor Yellow
    
    #Search Device Azure AD Joined
    $AAD = $Domain | Where-Object {$_ -like "*AzureAdJoined : Yes*"}
    $ResultAAD = if ($AAD) {"Yes"}else{"No"}
	#Write-Host "Verification de la connectivité à l'AzureAD" -ForegroundColor Yellow

    #Verification de l'existance de la cle JoinInfo
    $JoinInfo = Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
	#Write-Host	"Récupération de la valeur de registre JoinInfo" -ForegroundColor Yellow
    if ($JoinInfo -eq "True")
		{
        $RJoinInfo = "Yes"
		}
    else 
		{
        $RJoinInfo = "No"
		}
	
    #Verification de l'existance de la cle DeviceClientID
    $regKeyPath01 = "HKLM:\\SOFTWARE\Microsoft\Provisioning\OMADM\MDMDeviceID"
    $regValueName01 = "DeviceClientId"
    $DeviceClientID = (Get-Item $regKeyPath01 -EA Ignore).Property -contains $regValueName01
	#Write-Host	"Récupération de la valeur de registre DeviceID" -ForegroundColor Yellow
    if ($DeviceClientID -eq "True")
    {
        $RDeviceClientID = "Yes"
    }
    else 
    {
        $RDeviceClientID = "No"    
    }	
    
    #Verification de l'agent SCCM
    $SCCMService = (Get-Service -Name CcmExec).Status
	#Write-Host	"Récupération du status du service SCCM" -ForegroundColor Yellow
    if ($SCCMService -eq "Running")
		{
        $RSCCMService = "Yes"
		}
    else 
		{
        $RSCCMService = "No"  
		}
	
    #Verification gestion Microsoft Intune
    $INTUNEService = (Get-Service -Name IntuneManagementExtension).Status
	#Write-Host	"Recuperation du status du service MS Intune" -ForegroundColor Yellow
    if ($INTUNEService -eq "Running")
		{
        $RIntuneService = "Yes"
		}
    else 
		{
        $RIntuneService = "No"  
		}
	
    #Verification de la presence du certificat MS Intune
    #Write-Host	"Recuperation du status de certificat Intune" -ForegroundColor Yellow
    $CertDetailIntune = Get-ChildItem -Path 'Cert:\LocalMachine\My' -Recurse
    $CertDetailIntune | Select-Object @{n="Issuer";e={(($_.Issuer -split ",") |? {$_ -like "CN=*"}) -replace "CN="}}
    $ResultCertDetailIntune = if ($CertDetailIntune -like "*Intune*") {"Yes"}else{"No"}
	
	#Verification du status Azure PRT
    #Write-Host "Verification du status d'Azure PRT" -ForegroundColor Yellow
	$AADPRT = $Domain | Where-Object {$_ -like "*AzureAdPrt : YES*"}
    $ResultAADPRT = if ($AADPRT) {"Yes"}else{"No"}
	
    #Verification Windows Defender
    #Write-Host "Récupération des informations de Microsoft Defender" -ForegroundColor Yellow
    #Service Microsoft Defender Antivirus Service
    $DefService = Get-Service Windefend
    $DefServiceStatus = ($DefService).Status
    if ($DefServiceStatus -eq 'Running') {$RDefService = "Yes"}else{$RDefService = "No"}

    #Service Windows Security Service
    $SecurityHealthService = Get-Service SecurityHealthService
    $SecurityHealthServiceStatus = ($SecurityHealthService).Status
    if ($SecurityHealthServiceStatus -eq 'Running') {$RSecurityHealthService = "Yes"}else{$RSecurityHealthService = "No"}

    #Service Security Center
    $wscsvcService = Get-Service wscsvc
    $wscsvcServiceStatus = ($wscsvcService).Status
    if ($wscsvcServiceStatus -eq 'Running') {$RwscsvcServiceService = "Yes"}else{$RwscsvcServiceService = "No"}
	
    #Verification Windows Firewall
    $fw = Get-NetFirewallRule -PolicyStore ActiveStore -PolicyStoreSource MDM | Sort-Object DisplayName | Select-Object Name
	#Write-Host "Récupération du status du Firewall" -ForegroundColor Yellow
    $fwrule = $fw.Count
    if ($fwrule -ge "85")
    {
        $Resultfw = 'Yes'
    }
    else 
    {
        $Resultfw = 'No'
    }

    #Check HAADJ
    #Write-Host "Check HAADJ" -ForegroundColor Yellow
    If ($ResultAD -eq 'Yes' -AND $ResultAAD -eq 'Yes' -AND $RJoinInfo -eq 'Yes' -AND $RDeviceClientID -eq 'Yes' -AND $ResultCertDetailMSOrganization -eq 'Yes' -AND $ResultAADPRT -eq 'Yes')
    {
        $HAADJ = 'Yes'
    }
    else 
    {
        $HAADJ = 'No'
    }
    
    #Check Co-Management
    #Write-Host "Check Co-Management" -ForegroundColor Yellow
    If ($RSCCMService -eq 'Yes' -AND $RINTUNEService -eq 'Yes' -AND $ResultCertDetailIntune -eq 'Yes')
    {
        $CoMgnt = 'Yes'
    }
    else 
    {
        $CoMgnt = 'No'
    }
    
    #Check Windows Defender and Windows firewall
    #Write-Host "Check Firewall et MS Defender" -ForegroundColor Yellow
    If ($RDefService -eq 'Yes' -AND $RSecurityHealthService -eq 'Yes' -AND $RwscsvcServiceService -eq 'Yes' -AND $Resultfw -eq 'Yes')
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
    $report | Add-Member -MemberType NoteProperty -name "Certificat MS Organization" -Value $ResultCertDetailMSOrganization
    $report | Add-Member -MemberType NoteProperty -name "Device connecte au domaine" -Value $ResultAD
    $report | Add-Member -MemberType NoteProperty -name "Device connecte a Azure AD" -Value $ResultAAD
    $report | Add-Member -MemberType NoteProperty -name "Cle de registre JoinInfo" -Value $RJoinInfo 
    $report | Add-Member -MemberType NoteProperty -name "Cle de registre DeviceClientID" -Value $RDeviceClientID
    $report | Add-Member -MemberType NoteProperty -name "Etat Service SCCM" -Value $RSCCMService 
    $report | Add-Member -MemberType NoteProperty -name "Etat Microsoft Intune" -Value $RIntuneService
    $report | Add-Member -MemberType NoteProperty -name "Certificat MS Intune" -Value $ResultCertDetailIntune 
    $report | Add-Member -MemberType NoteProperty -name "Service Defender Actif" -Value $RDefService
    $report | Add-Member -MemberType NoteProperty -name "Service Security Health Service" -Value $RSecurityHealthService
    $report | Add-Member -MemberType NoteProperty -name "Service Security Center" -Value $RwscsvcServiceService
    $report | Add-Member -MemberType NoteProperty -name "Regles de firewall" -Value $Resultfw 
    $report | Add-Member -MemberType NoteProperty -name "Configuration HAADJ" -Value $HAADJ
    $report | Add-Member -MemberType NoteProperty -name "CoManagement SCCM Intune" -Value $CoMgnt 
    $report | Add-Member -MemberType NoteProperty -name "Windows firewall et Microsoft Defender" -Value $WinDef
    $report | export-csv -NoTypeInformation -Path $logfilepath -Delimiter ";" -Append

#Notification pour l'admin
If ($HAADJ -eq 'Yes' -and $CoMgnt -eq 'Yes' -and $WinDef -eq 'Yes')

    {
    #Write-Host "Envoie des résultats au service IT" -ForegroundColor Yellow
    Copy-Item $logfilepath -Destination $LogShare -Force
    balloon "Bonjour $env:UserName" "Votre poste $Devicename est pret !" 10000
	($Continue = $false)
    }
	}
}
