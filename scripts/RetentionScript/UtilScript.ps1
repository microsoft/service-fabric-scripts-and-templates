<#
 .SYNOPSIS
    Utility functions for retention script.
#>

Function Get-PartitionDict 
{    
    [CmdletBinding(PositionalBinding = $false)]
    param([Parameter(Mandatory=$true)][System.Collections.ArrayList]$pathsList
    ) 

    $partitionDict = New-Object 'system.collections.generic.dictionary[[string],[system.collections.generic.list[string]]]'
    foreach($path in $pathsList)
    {
        $pathList = $path.Split("\",[StringSplitOptions]'RemoveEmptyEntries')
        $length = $pathList.Count
        $partitionID = $null
        if($length -le 1)
        {
            $pathList = $path.Split("/",[StringSplitOptions]'RemoveEmptyEntries')
            $length = $pathList.Count
            if($length -le 1)
            {
                throw "$path is not in correct format."
            }
            Else
            {
                $partitionID = $pathList[$length - 2]
            }
        }
        Else {
            $partitionID = $pathList[$length - 2]            
        }
        
    
        if($partitionID -eq $null)
        {
            throw "Not able to extract partitionID"
        }
        
        if(!$partitionDict.ContainsKey($partitionID))
        {
            $partitionDict.Add($partitionID, $path)
        }
        else {
            $partitionDict[$partitionID].add($path)
        }
    }

    return $partitionDict
}

Function Get-FinalDateTimeBefore 
{   
    [CmdletBinding(PositionalBinding = $false)]    
    param([Parameter(Mandatory=$true)][string]$DateTimeBefore, 
    [Parameter(Mandatory=$true)][string]$Partitionid, 
    [Parameter(Mandatory=$true)][string]$ClusterEndpoint,
    [Parameter(Mandatory=$false)][bool]$DeleteNotFoundPartitions,
    [Parameter(Mandatory=$false)][string]$ClientCertificateThumbprint
    )  

    # DateTime Improvement to be done here.
    $dateTimeBeforeObject = [DateTime]::ParseExact($DateTimeBefore,"yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
    $finalDateTimeObject = $dateTimeBeforeObject
    $dateTimeBeforeString = $dateTimeBeforeObject.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") 
    $url = "http://$ClusterEndpoint/Partitions/$Partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
    $backupEnumerations = $null
    try {
        if($ClientCertificateThumbprint)
        {
            $url = "https://$ClusterEndpoint/Partitions/$Partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
            $pagedBackupEnumeration = Invoke-RestMethod -Uri $url  -CertificateThumbprint $ClientCertificateThumbprint
        }
        else {  
            Write-Host "Querying the URL: $url"
            $pagedBackupEnumeration = Invoke-RestMethod  -Uri $url       
        }
        $backupEnumerations = $pagedBackupEnumeration.Items | Sort-Object -Property @{Expression = {[DateTime]::ParseExact($_.CreationTimeUtc,"yyyy-MM-ddTHH:mm:ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)}; Ascending = $false}
    }
    catch  {
        $err = $_.ToString() | ConvertFrom-Json
        if($err.Error.Code -eq "FABRIC_E_PARTITION_NOT_FOUND")
        {
            Write-Warning "$Partitionid is not found on the cluster : $ClusterEndpoint" 
            if($DeleteNotFoundPartitions -eq $true)
            {
                Write-Warning "DeleteNotFoundPartitions flag is enabled so, deleting data all in this partition"
                return [DateTime]::MaxValue
            }
            else {
                Write-Warning "If you want to remove data in this partition as well, please run the script by enabling DeleteNotFoundPartitions flag."
                return [DateTime]::MinValue
            }
        }
        else {
            throw $_.Exception.Message
        }
    }

    $fullBackupFound = $false
    foreach($backupEnumeration in $backupEnumerations)
    {
        if($backupEnumeration.BackupType -eq "Full")
        {
            $finalDateTimeObject = [DateTime]::Parse($backupEnumeration.CreationTimeUtc)
            $fullBackupFound = $true
            break
        }
    }
    if($backupEnumerations.Count -eq 0)
    {
        Write-Host "There are no backups available in the partition: $Partitionid before the specified date."
        return [DateTime]::MinValue
    }

    if(!$fullBackupFound)
    {
        Write-Host "The Backups Before this $dateTimeBeforeString date are corrupt as no full backup is found, So, deleting them."
    }
    return $finalDateTimeObject
}


Function Get-PartitionIdList 
{   
    [CmdletBinding(PositionalBinding = $false)]
    param([Parameter(Mandatory=$false)][string]$ApplicationId, 
    [Parameter(Mandatory=$false)][string]$ServiceId,
    [Parameter(Mandatory=$true)][string]$ClusterEndpoint,    
    [Parameter(Mandatory=$false)][string]$ClientCertificateThumbprint
    ) 

    $serviceIdList = New-Object System.Collections.ArrayList
    if($ApplicationId)
    {
        if($ClientCertificateThumbprint)
        {
            $serviceIdList = Get-ServiceIdList -ApplicationId $ApplicationId -ClusterEndpoint $ClusterEndpoint -ClientCertificateThumbprint $ClientCertificateThumbprint
        }
        else {
            $serviceIdList = Get-ServiceIdList -ApplicationId $ApplicationId -ClusterEndpoint $ClusterEndpoint
        }
    }
    else {
        $serviceIdList.Add($ServiceId) | Out-Null
    }

    $partitionIdList = New-Object System.Collections.ArrayList

    foreach($serviceId in $serviceIdList)
    {
        $continuationToken = $null
        do
        {
            if($ClientCertificateThumbprint)
            {
                $partitionInfoList = Invoke-RestMethod -Uri "https://$ClusterEndpoint/Services/$serviceId/$/GetPartitions?api-version=6.2&ContinuationToken=$continuationToken"  -CertificateThumbprint $ClientCertificateThumbprint
            }
            else {  
                $partitionInfoList = Invoke-RestMethod -Uri "http://$ClusterEndpoint/Services/$serviceId/$/GetPartitions?api-version=6.2&ContinuationToken=$continuationToken" 
            }
            foreach($partitionInfo in $partitionInfoList.Items)
            {
                $partitionIdList.Add($partitionInfo.PartitionInformation.Id)
            }
            $continuationToken = $partitionInfoList.ContinuationToken
        }while($continuationToken -ne "")
    }
    $length = $partitionIdList.Count
    Write-Host "The total number of partitions found on the cluster are $length"
    return $partitionIdList
}


Function Get-ServiceIdList 
{   
    [CmdletBinding(PositionalBinding = $false)]
    param([Parameter(Mandatory=$true)][string]$ApplicationId,
    [Parameter(Mandatory=$true)][string]$ClusterEndpoint,    
    [Parameter(Mandatory=$false)][string]$ClientCertificateThumbprint
        )

    $continuationToken = $null
    $serviceIdList = New-Object System.Collections.ArrayList
    do
    {
        if($ClientCertificateThumbprint)
        {
            $serviceInfoList = Invoke-RestMethod -Uri "https://$ClusterEndpoint/Applications/$ApplicationId/$/GetServices?api-version=6.2&ContinuationToken=$continuationToken" -CertificateThumbprint $ClientCertificateThumbprint
        }
        else {  
            $serviceInfoList = Invoke-RestMethod -Uri "http://$ClusterEndpoint/Applications/$ApplicationId/$/GetServices?api-version=6.2&ContinuationToken=$continuationToken"
        }
        foreach($serviceInfo in $serviceInfoList.Items)
        {
            $serviceIdList.Add($serviceInfo.Id) | Out-Null
        }
        $continuationToken = $serviceInfoList.ContinuationToken
    }while($continuationToken -ne "")

    $length = $serviceIdList.Count
    Write-Host "$ApplicationId has $length number of services"
    return $serviceIdList
}


Function Start-BackupDataCorruptionTest 
{  
    [CmdletBinding(PositionalBinding = $false)]
    param([Parameter(Mandatory=$true)][string]$DateTimeBefore,
    [Parameter(Mandatory=$true)][string]$Partitionid, 
    [Parameter(Mandatory=$true)][string]$ClusterEndpoint,
    [Parameter(Mandatory=$false)][string]$ClientCertificateThumbprint
    )
    $dateTimeBeforeObject = [DateTime]::ParseExact($DateTimeBefore,"yyyy-MM-dd HH.mm.ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)    
    $dateTimeBeforeString = $dateTimeBeforeObject.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") 
    # DateTime Improvement to be done here.
    $url = "http://$ClusterEndpoint/Partitions/$Partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
    
    $backupEnumerations = $null
    try {
        if($ClientCertificateThumbprint)
        {
            $url = "https://$ClusterEndpoint/Partitions/$Partitionid/$/GetBackups?api-version=6.2-preview&EndDateTimeFilter=$dateTimeBeforeString"
            $pagedBackupEnumeration = Invoke-RestMethod -Uri $url -CertificateThumbprint  $ClientCertificateThumbprint
        }
        else {
            $pagedBackupEnumeration = Invoke-RestMethod -Uri $url 
        }
        $backupEnumerations = $pagedBackupEnumeration.Items | Sort-Object -Property @{Expression = {[DateTime]::ParseExact($_.CreationTimeUtc,"yyyy-MM-ddTHH:mm:ssZ",[System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)}; Ascending = $true}
        
        if($backupEnumerations -ne $null -and $backupEnumerations[0].BackupType -ne "Full")
        {
            throw "Data is corrupted for this partition : $Partitionid"
        }
    }
    catch  {
        $err = $_.ToString() | ConvertFrom-Json
        if($err.Error.Code -eq "FABRIC_E_PARTITION_NOT_FOUND")
        {
            Write-Host "Partition: $Partitionid not found, so, could not go through with testing the integrity of data of this partition."
        }
        else {
            throw $_.Exception.Message
        }
    }
}