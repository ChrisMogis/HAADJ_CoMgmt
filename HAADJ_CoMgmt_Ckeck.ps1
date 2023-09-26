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

    Start-Sleep -s 600
    
    #Verification des certificats
    $CertDetailP2PAccess = Get-ChildItem -Path 'Cert:\LocalMachine\My' –Recurse
    $CertDetailP2PAccess | Select-Object @{n="Issuer";e={(($_.Issuer -split ",") |? {$_ -like "CN=*"}) -replace "CN="}}
    $ResultCertDetailP2PAccess = If ($CertDetailP2PAccess -like "*P2P-Access*") {"Yes"}else{"No"}
    
    $CertDetailOrgAccess = Get-ChildItem -Path 'Cert:\LocalMachine\My' –Recurse
    $CertDetailOrgAccess | Select-Object @{n="Issuer";e={(($_.Issuer -split ",") |? {$_ -like "CN=*"}) -replace "CN="}}
    $ResultCertDetailOrgAccess = if ($CertDetailOrgAccess -like "*Organization-Access*") {"Yes"}else{"No"}
    
    #Device Domain Join verification
    $AD = $Domain | Where-Object {$_ -like "*DomainJoined : Yes*"}
    $ResultAD = if ($AD) {"Yes"}else{"No"}
    
    #Search Device Azure AD Joined
    $AAD = $Domain | Where-Object {$_ -like "*AzureAdJoined : Yes*"}
    $ResultAAD = if ($AAD) {"Yes"}else{"No"}
    #if ($ResultAAD -ne 'Yes')
    #{
        #Start-ScheduledTask "\Microsoft\Windows\Workplace Join\Automatic-Device-Join"
    #}
    
    #Verification de l'existance de la cle JoinInfo
    $JoinInfo = Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
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
    if ($INTUNEService -eq "Running")
    {
        $RIntuneService = "Yes"
    }
    else 
    {
        $RIntuneService = "No"  
    }
    
    #Verification de la presence du certificat MS Intune
    $CertDetailIntune = Get-ChildItem -Path 'Cert:\LocalMachine\My' –Recurse
    $CertDetailIntune | Select-Object @{n="Issuer";e={(($_.Issuer -split ",") |? {$_ -like "CN=*"}) -replace "CN="}}
    $ResultCertDetailIntune = if ($CertDetailIntune -like "*Intune*") {"Yes"}else{"No"}
    
    #Verification Windows Defender
    $ED01 = (Get-MpComputerStatus).AntispywareEnabled
    if ($ED01 -eq "True")
    {
        $RED01 = "Yes"
    }
    else 
    {
        $RED01 = "No"    
    }
    
    $ED02 = (Get-MpComputerStatus).AntivirusEnabled
    if ($ED02 -eq "True")
    {
        $RED02 = "Yes"
    }
    else 
    {
        $RED02 = "No"   
    }
    
    $ED03 = (Get-MpComputerStatus).OnAccessProtectionEnabled
    if ($ED03 -eq "True")
    {
        $RED03 = "Yes"
    }
    else 
    {
        $RED03 = "No"    
    }
    
    $ED04 = (Get-MpComputerStatus).RealTimeProtectionEnabled
    if ($ED04 -eq "True")
    {
        $RED04 = "Yes"
    }
    else 
    {
        $RED04 = "Yes"    
    }
    
    $ED05 = (Get-MpComputerStatus).TamperProtectionSource
    if ($ED05 -eq "Intune")
    {
        $RED05 = "Yes"
    }
    else 
    {
        $RED05 = "No"  
    }
       
    #Verification Windows Firewall
    $fw = Get-NetFirewallRule -PolicyStore ActiveStore -PolicyStoreSource MDM | Sort-Object DisplayName | Select-Object Name
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
    If ($ResultAD -eq 'Yes' -AND $ResultAAD -eq 'Yes' -AND $RJoinInfo -eq 'Yes' -AND $RDeviceClientID -eq 'Yes' -AND $ResultCertDetailP2PAccess -eq 'Yes' -AND $ResultCertDetailOrgAccess -eq 'Yes')
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
    $report | Add-Member -MemberType NoteProperty -name "Certificat P2P Access" -Value $ResultCertDetailP2PAccess
    $report | Add-Member -MemberType NoteProperty -name "Certificat Organization-Access" -Value $ResultCertDetailOrgAccess
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

    balloon "ClientName - Information" "Votre poste $Devicename est prêt !" 5000
    ($Continue = $false)

    }
        
}
