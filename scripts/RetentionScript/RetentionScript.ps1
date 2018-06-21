<#
 .SYNOPSIS
    This powershell module deletes backups from the azure storage.

 .PARAMETER UserName
    UserName associated with file share.

 .PARAMETER FileSharePath
    The file share path of the storage configured for backup.

 .PARAMETER StorageType
    It could be one of the two storages supported:
    1. AzureBlob
    2. FileShare

 .PARAMETER DateTimeBefore(Required)
    It is the date time value for deleting the backups before that time. It should be provided in the format(yyyy-MM-dd HH.mm.ssZ)
    Example: 
    $DateTimeBefore = [DateTime]::Now.ToString("yyyy-MM-dd HH.mm.ssZ")

 .PARAMETER ConnectionString
    Connection string to the azure storage configured for backup.

 .PARAMETER Pass
    File share password for the user name $UserName.It must be specified in Secured String
    Example:
    $pass ="Password" | ConvertTo-SecureString -AsPlainText -Force

 .PARAMETER ContainerName(Optional)
    Container name of storage in which backups are stored.

 .PARAMETER StorageAccountName
    Azure storage account name
    
 .PARAMETER StorageAccountKey
    Azure storage account key

 .PARAMETER ClusterEndPoint(Required)
    It is the management end point of the cluster.
    example:
    ManagementEndpoint : https://clustername.centralus.cloudapp.azure.com:19080
    $ClusterEndPoint : clustername.centralus.cloudapp.azure.com:19080

 .PARAMETER DeleteNotFoundPartitions(Optional)
    If there are partitions on the storage which are not found on the cluster, and you want to delete complete data in the partition
    then, enable the flag and run the script.
    
 .PARAMETER PartitionId(Optional)
    Filter to delete data for a particular partition on the cluster
        
 .PARAMETER ApplicationId
    Filter to delete data for a particular Application on the cluster
    Example:
    if ApplicationName(without fabric:) is  "application/Name" then,
    $ApplicationId = "application~Name"(Replace "/" with "~")
        
 .PARAMETER ServiceId
    Filter to delete data for a particular service on the cluster
    Example:
    if ServiceName(without fabric:) is  "Service/Name" then,
    $ServiceId = "Service~Name"(Replace "/" with "~")
        
 .PARAMETER ClientCertificateThumbprint(Required in case of secured cluster)
    Thumbprint of the client certificate
#>

[CmdletBinding(PositionalBinding = $false)]
param (
    [Parameter(Mandatory=$false)]
    [String] $UserName,

    [Parameter(Mandatory=$false)]
    [String] $FileSharePath,

    [Parameter(Mandatory=$true)]
    [String] $StorageType,

    [Parameter(Mandatory=$true)]
    [String] $DateTimeBefore,
    
    [Parameter(Mandatory=$false)]
    [String] $ConnectionString,
    
    [Parameter(Mandatory=$false)]
    [SecureString] $Pass,

    [Parameter(Mandatory=$false)]
    [String] $ContainerName,

    [Parameter(Mandatory=$false)]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$false)]
    [String] $StorageAccountKey,

    [Parameter(Mandatory=$true)]
    [String] $ClusterEndPoint,

    [Parameter(Mandatory=$false)]
    [Switch] $DeleteNotFoundPartitions,

    [Parameter(Mandatory=$false)]
    [String] $PartitionId,

    [Parameter(Mandatory=$false)]
    [String] $ServiceId,
 
    [Parameter(Mandatory=$false)]
    [String] $ApplicationId,

    [Parameter(Mandatory=$false)]
    [String] $ClientCertificateThumbprint
)

$command = ""
if($StorageType -eq "FileShare")
{
  if(!$FileSharePath)
  {
    $FileSharePath = Read-Host -Prompt "Please enter the FileShare path"
  }

  if($UserName)
  {
      $command = $command +  ".\RetentionScriptFileShare.ps1 -UserName `"$UserName`" -FileSharePath `"$FileSharePath`" -DateTimeBefore `"$DateTimeBefore`" -ClusterEndPoint `"$ClusterEndPoint`""
    if(!$Pass)
    {
        $Pass = Read-Host -Prompt "Please enter password for the userName: $UserName" -AsSecureString
    }
    $Global:Password = $Pass    
  }
  else {
    $command = $command +  ".\RetentionScriptFileShare.ps1 -FileSharePath `"$FileSharePath`" -DateTimeBefore `"$DateTimeBefore`" -ClusterEndPoint `"$ClusterEndPoint`""
  }
}
elseif($StorageType -eq "AzureBlob")
{
    if($ConnectionString)
    {
        if($ContainerName)
        {
            $command = $command + ".\RetentionScriptAzureShare.ps1 -ConnectionString `"$ConnectionString`" -DateTimeBefore `"$DateTimeBefore`" -ClusterEndPoint `"$ClusterEndPoint`""
        }
        else {
            $command = $command + ".\RetentionScriptAzureShare.ps1 -ConnectionString `"$ConnectionString`" -DateTimeBefore `"$DateTimeBefore`" -ClusterEndPoint `"$ClusterEndPoint`""
        }
    }
    else {
        if(!$StorageAccountName)
        {
            $StorageAccountName = Read-Host -Prompt "Please enter the Storage account name"
        }
        if(!$StorageAccountKey)
        {
            $StorageAccountKey = Read-Host -Prompt "Please enter the Storage account key"
        }
        $command = $command + ".\RetentionScriptAzureShare.ps1 -StorageAccountName `"$StorageAccountName`" -StorageAccountKey `"$StorageAccountKey`" -DateTimeBefore `"$DateTimeBefore`" -ContainerName `"$ContainerName`" -ClusterEndPoint `"$ClusterEndPoint`""    
    }

    if($ContainerName)
    {
        $command = $command + " -ContainerName `"$ContainerName`""
    }
}
else {
    throw "The storage of type $StorageType not supported"
}

if($ApplicationId)
{
    $command = $command + " -ApplicationId `"$ApplicationId`""
}
if($ServiceId)
{
    $command = $command + " -ServiceId `"$ServiceId`""
}

if($ClientCertificateThumbprint)
{
    $command = $command + " -ClientCertificateThumbprint `"$ClientCertificateThumbprint`""
}

if($PartitionId)
{
    $command = $command + " -PartitionId `"$PartitionId`""
}

if($DeleteNotFoundPartitions)
{
    $command = $command + " -DeleteNotFoundPartitions"    
}

$scriptBlock = [ScriptBlock]::Create($command)
Invoke-Command $scriptBlock