<#
.SYNOPSIS
    Script to check Exchange Environment Health, simply and clear!
.DESCRIPTION
    Script checks Services, Mail queue, Serevice accessibility, Replication Health and Database status.

All Services in S-EX-01 good
All Services in S-EX-02 good
All Services in S-EX-03 good
All Services in S-EX-04 good
All Services in S-EX-05 good

S-EX-01 - No transport queue
S-EX-02 - No transport queue
S-EX-03 - No transport queue
S-EX-04 - No transport queue
S-EX-05 - No transport queue

.EXAMPLE
.\Test_Exchange_Health.ps1
#>

Clear-Host

$Results=@()
$1=@()
$serverq=@()
$mbx = Get-exchangeserver -WarningAction silentlycontinue
foreach ($mb in $mbx)
{
    $s=Test-ServiceHealth -Server $mb.name 
    if (-Not($s.ServicesNotRunning))
    {
        $Services= Write-Output "All Services in $mb good"
        $1 +=$Services
    }
    else
    {
        $Services= Write-Output "Services $mb is down:" ($s.ServicesNotRunning |Group-Object | Select-Object -ExpandProperty name) 
        $1 +=$Services
    } 

    $q = $null
    $q = Get-Queue -server $mb.Name -ErrorAction Stop | Where-Object {$_.DeliveryType -ne "ShadowRedundancy"}

    if ($q)
    {
        $qcount = $q | Measure-Object MessageCount -Sum
        [int]$qlength = $qcount.sum
        if ($qlength -gt 10)
        {
            Write-Host -ForegroundColor Red "$mb is $qlength queue"
            "$mb"
            $serverq+= "$mb - Transport queue is $qlength"

        }
        else
        {
            Write-Host -ForegroundColor Green "$mb is $qlength queue"
            $serverq+= "$mb - No transport queue"
        }
    }

}
$2=foreach ($mb in $mbx) {Get-ServerComponentState -Identity $mb.name | Where-Object {($_.State -eq "inactive") -and ($_.Component -notmatch "ForwardSyncDaemon|ProvisioningRps")} | Format-Table ServerFqdn,Component,State}
$3=foreach ($mb in $mbx) {Get-ServerHealth $mb.name | Where-Object Alertvalue -eq "UnHealthy"}
$4=Get-DatabaseAvailabilityGroup | Select-Object -ExpandProperty Servers | Test-ReplicationHealth | Where-Object Result -ne "Passed"
$5=Get-DatabaseAvailabilityGroup | Select-Object -ExpandProperty Servers | Test-MapiConnectivity | Where-Object Result -ne "Success" | Format-Table -AutoSize -Wrap
$6=Foreach ($db in (Get-MailboxDatabase |Select-Object -ExpandProperty name)) {Get-MailboxDatabaseCopyStatus $db |Where-Object Status -NotMatch "Healthy|Mounted"}
$7=Get-MailboxServer | Where-Object DatabaseCopyAutoActivationPolicy -ne "Unrestricted"| Format-Table Name, DatabaseCopyAutoActivationPolicy
""
$Results=$1+$2+$3+$4+$5+$6+$7+""+$serverq+""
$Results #| Out-File .\Exchange_Health_Report.txt
