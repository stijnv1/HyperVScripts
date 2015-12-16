#
# GetVMReplicaOverview.ps1
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

    $VMReplicaMeasureObject = ($VMReplicasMeasure).Where{$_.Name -eq $VMReplica.Name}

    $VMObject | Add-Member -MemberType NoteProperty -Name LastReplicationTime -Value $VMReplicaMeasureObject.LReplTime
    $avgSize = $VMReplicaMeasureObject.AvgReplSize / 1MB
    $VMObject | Add-Member -MemberType NoteProperty -Name AverageReplicationSizeMB -Value $avgSize

    $VMReplicaOverview += $VMObject
}

$VMReplicaOverview | Out-GridView -Title "VM Replica Overview"