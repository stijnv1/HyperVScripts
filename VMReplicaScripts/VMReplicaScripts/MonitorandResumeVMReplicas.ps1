#
# MonitorandResumeVMReplicas.ps1
#
param
(
    [Parameter(Mandatory=$True)]
    [string]$ClusterName

)

$nodes = Get-Cluster $ClusterName | Get-ClusterNode
$VMReplicas = @()
$VMReplicasMeasure = @()
$VMReplicaOverview = @()

foreach ($node in $nodes)
{
    $VMReplicas += Get-VMReplication -ComputerName $node
    $VMReplicasMeasure += Measure-VMReplication -ComputerName $node
}

foreach ($VMReplica in $VMReplicas)
{
    $VMObject = New-Object -TypeName PSObject
    $VMObject | Add-Member -MemberType NoteProperty -Name VMName -Value $VMReplica.Name
    $VMObject | Add-Member -MemberType NoteProperty -Name State -Value $VMReplica.State
    $VMObject | Add-Member -MemberType NoteProperty -Name Health -Value $VMReplica.Health
    $VMObject | Add-Member -MemberType NoteProperty -Name Frequency -Value $VMReplica.FrequencySec
    $VMObject | Add-Member -MemberType NoteProperty -Name PrimaryServer -Value $VMReplica.PrimaryServer
    $VMObject | Add-Member -MemberType NoteProperty -Name ReplicaServer -Value $VMReplica.ReplicaServer

    $VMReplicaMeasureObject = ($VMReplicasMeasure) | Where {$_.Name -eq $VMReplica.Name}

    $VMObject | Add-Member -MemberType NoteProperty -Name LastReplicationTime -Value $VMReplicaMeasureObject.LReplTime
    $avgSize = $VMReplicaMeasureObject.AvgReplSize / 1MB
    $VMObject | Add-Member -MemberType NoteProperty -Name AverageReplicationSizeMB -Value $avgSize
  
    $VMReplicaOverview += $VMObject
}


Foreach ($VMReplica in $VMReplicas) {
    Write-Host "Checking Replication on" $VMReplica.Name -ForegroundColor Yellow
    
    $RetryCount = 0

    Do {
        
       
        if ($VMReplica.Health -eq "Warning" -and $VMReplica.State -eq "Suspended") {
            Write-Host "VM Replication is in Suspended State, resetting stats and resuming Replication" -ForegroundColor Red
            Get-VM -Name $VMReplica.Name -ComputerName $VMReplica.PrimaryServer | Get-VMReplication | Reset-VMReplicationStatistics
            Resume-VMReplication -ComputerName $VMReplica.PrimaryServer -VMName $VMReplica.Name
            Write-Host "Sleeping for 5 Seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
        Elseif ($VMReplica.Health -eq "Critical" -and $VMReplica.State -eq "WaitingForStartResynchronize") {
            Write-Host "VM Replication is Waiting to Start Resynchronize, Resuming Replication" -ForegroundColor Red
            Get-VM -Name $VMReplica.Name -ComputerName $VMReplica.PrimaryServer | Get-VMReplication | Reset-VMReplicationStatistics
            Resume-VMReplication -ComputerName $VMReplica.PrimaryServer -VMName $VMReplica.Name -Resynchronize
            Write-Host "Sleeping for 5 Seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
        Elseif ($VMReplica.Health -eq "Warning" -and $VMReplica.State -eq "Resynchronizing") {
            Write-Host "VM Replication is Resynchronizing." -ForegroundColor Yellow
            Write-Host "Sleeping for 60 Seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 60
            #Break
            # Use break if you do not want to wait for the resync
        }
        Elseif ($VMReplica.Health -eq "Warning" -and $VMReplica.State -eq "ReadyForInitialReplication") {
            Write-Host "VM Replication is Ready for Initial Replication, Starting Initial Replication" -ForegroundColor Red
            Start-VMInitialReplication -ComputerName $VMReplica.PrimaryServer -VMName $VMReplica.Name
            Write-Host "Sleeping for 30 Seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
        }
        Elseif($VMReplica.Health -eq "Warning") {
            Get-VM -Name $VMReplica.Name -ComputerName $VMReplica.PrimaryServer | Get-VMReplication | Reset-VMReplicationStatistics
        }

       

        $VMReplicaHealth = Get-VM -ComputerName $VMReplica.ComputerName -Name $VMReplica.VMName | Get-VMReplication
        #Start-Sleep -Seconds 10
    }
    Until($VMReplicaHealth.Health -eq "Normal" -and $VMReplicaHealth.State -eq "Replicating")
    Write-Host "Replication is properly working on" $VMReplica.Name -ForegroundColor Green
} 
