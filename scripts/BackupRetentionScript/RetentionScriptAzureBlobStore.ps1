[CmdletBinding(PositionalBinding = $false)]
param (
    [Parameter(Mandatory=$false)]
    [String] $ConnectionString,

    [Parameter(Mandatory=$false)]
    [String] $ContainerName,

    [Parameter(Mandatory=$false)]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$false)]
    [String] $StorageAccountKey,
    
    [Parameter(Mandatory=$true)]
    [String] $DateTimeBefore,
    
    [Parameter(Mandatory=$true)]
    [String] $ClusterEndpoint,

    [Parameter(Mandatory=$false)]
    [switch] $DeleteNotFoundPartitions,

    [Parameter(Mandatory=$false)]
    [String] $PartitionId,

    [Parameter(Mandatory=$false)]
    [String] $ServiceId,

    [Parameter(Mandatory=$false)]
    [String] $ApplicationId,

    [Parameter(Mandatory=$false)]
    [String] $ClientCertificateThumbprint
)
. .\UtilScript.ps1

$partitionIdListToWatch = New-Object System.Collections.ArrayList

if($ApplicationId)
{
    if($ClientCertificateThumbprint)
    {
        $partitionIdListToWatch = Get-PartitionIdList -ApplicationId $ApplicationId -ClusterEndpoint $ClusterEndpoint -ClientCertificateThumbprint $ClientCertificateThumbprint
    }
    else {
        $partitionIdListToWatch = Get-PartitionIdList -ApplicationId $ApplicationId -ClusterEndpoint $ClusterEndpoint
    }
}
elseif($ServiceId)
{
    if($ClientCertificateThumbprint)
    {
        $partitionIdListToWatch = Get-PartitionIdList -ServiceId $ServiceId -ClusterEndpoint $ClusterEndpoint -ClientCertificateThumbprint $ClientCertificateThumbprint
    }
    else {
        $partitionIdListToWatch = Get-PartitionIdList -ServiceId $ServiceId -ClusterEndpoint $ClusterEndpoint
    }
} 
elseif($PartitionId)
{
    $partitionIdListToWatch.Add($PartitionId) 
}

$contextForStorageAccount = $null

if($ConnectionString)
{
    $contextForStorageAccount = New-AzureStorageContext -ConnectionString $ConnectionString
}
else
{
    $contextForStorageAccount = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
}

$containerNameList = New-Object System.Collections.ArrayList

if(!$ContainerName.IsPresent)
{
    $containers = Get-AzureStorageContainer -Context $contextForStorageAccount
    foreach($container in $containers)
    {
        $containerNameList.Add($container.Name) | Out-Null
    }   
}
Else {
    $containerNameList.Add($ContainerName) | Out-Null
}

foreach($containerName in $containerNameList)
{
    $token = $null
    $pathsList = New-Object System.Collections.ArrayList    
    do
    {
        $blobs = Get-AzureStorageBlob -Container $ContainerName -ContinuationToken $token -Context $contextForStorageAccount
            
        foreach($blob in $blobs)    
        {
            $pathsList.Add($blob.Name) | Out-Null
        }
        if($blobs.Count -le 0) { Break;}
        $token = $blobs[$blobs.Count -1].ContinuationToken;
    }
    While ($token -ne $Null)
    $partitionDict = New-Object 'system.collections.generic.dictionary[[string],[system.collections.generic.list[string]]]'
    $finalDateTimeObject = $dateTimeBeforeObject
    $partitionDict = Get-PartitionDict -pathsList $pathsList
    $partitionCountDict = New-Object 'system.collections.generic.dictionary[[String],[Int32]]'

    foreach($partitionid in $partitionDict.Keys)
    {
        $partitionCountDict[$partitionid] = $partitionDict[$partitionid].Count
        if($partitionIdListToWatch.Count -ne 0 -and !$partitionIdListToWatch.Contains($partitionid))
        {
            continue
        }
        if($ClientCertificateThumbprint)
        {
            $finalDateTimeObject = Get-FinalDateTimeBefore -DateTimeBefore $DateTimeBefore -Partitionid $partitionid -ClusterEndpoint $ClusterEndpoint -DeleteNotFoundPartitions $DeleteNotFoundPartitions -ClientCertificateThumbprint $ClientCertificateThumbprint
        }
        else {
            $finalDateTimeObject = Get-FinalDateTimeBefore -DateTimeBefore $DateTimeBefore -Partitionid $partitionid -ClusterEndpoint $ClusterEndpoint -DeleteNotFoundPartitions $DeleteNotFoundPartitions
        }
        if($finalDateTimeObject -eq [DateTime]::MinValue)
        {
            continue
        }
        $deleteCount = 0
        foreach($blobPath in $partitionDict[$partitionid])
        {
            $fileNameWithExtension = Split-Path $blobPath -Leaf
            $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($fileNameWithExtension)
            $extension = [IO.Path]::GetExtension($fileNameWithExtension)
            if($extension -eq ".zip" -or $extension -eq ".bkmetadata" )
            {
                $dateTimeObject = [DateTime]::ParseExact($fileNameWithoutExtension + "Z","yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
                if($dateTimeObject.ToUniversalTime() -lt $finalDateTimeObject.ToUniversalTime())
                {
                    Write-Host "Deleting the file: $blobPath"
                    Remove-AzureStorageBlob -Blob $blobPath -Container $containerName -Context $contextForStorageAccount
                    $partitionCountDict[$partitionid] = $partitionCountDict[$partitionid] -1
                    $deleteCount = $deleteCount + 1 
                    if($partitionCountDict[$partitionid] -eq 0)
                    {
                        Write-Warning -Message "The backup count in this $partitionid is zero. It could happen if the partition is not found on the $ClusterEndpoint"
                    }
                }
            }
        }
        $numberOfBackupsLeft = $partitionCountDict[$partitionid]
        Write-Host "Cleanup for the partitionID: $partitionid is complete "
        Write-Host "The number of backup left in the partition after cleanup: $numberOfBackupsLeft"
        Write-Host "The number of backup files deleted : $deleteCount (.bkmetadata + .zip files)"
    }
}


$newPathsList = New-Object System.Collections.ArrayList
$newToken = $null  
do
{
    $blobs = Get-AzureStorageBlob -Container $ContainerName -ContinuationToken $newToken -Context $contextForStorageAccount
        
    foreach($blob in $blobs)    
    {
        $newPathsList.Add($blob.Name) | Out-Null
    }
    if($blobs.Count -le 0) { Break;}
    $newToken = $blobs[$blobs.Count -1].ContinuationToken;
}
While ($newToken -ne $Null)

$newPartitionDict = Get-PartitionDict -pathsList $newPathsList

foreach($partitionid in $newPartitionDict.Keys)
{
    if($partitionCountDict.ContainsKey)
    {
        if($partitionCountDict[$partitionid] -gt $newPartitionDict[$partitionid].Count)
        {
            throw "The partition with partitionId : $partitionid has less number of backups than expected."
        }
    }
    Start-BackupDataCorruptionTest -DateTimeBefore $DateTimeBefore -Partitionid $partitionid -ClusterEndpoint $ClusterEndpoint -ClientCertificateThumbprint $ClientCertificateThumbprint
}




