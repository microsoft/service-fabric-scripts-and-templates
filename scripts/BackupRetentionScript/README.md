
# About the scripts:
 Service Fabric Backup Restore Service (https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-backuprestoreservice-quickstart-azurecluster),
  currently in preview, allows you to take periodic backups of your Reliable stateful service and Reliable Actors. Depending on the frequency of your backup interval, backups can really grow fast. 
 While we work on providing retention support integrated with the service, this script would help you manage your storage till that time. It allows you to delete backups older than a specified time.
 
## Usage
This script support both the storage types supported by Backup Restore service:
1) Azure blob store
2) File Share

 ## How to use with Azure Storage:
 
 You can run the script by providing single azure storage connection string as parameter or you can also provide azure account name and key separately.
 Examples:
1) The below example will delete all the backups in the storage(specifed with connection string) of the service with serviceid *WebReferenceApplication~RestockRequestManager*.
```powershell
 .\RetentionScript.ps1 -DateTimeBefore "2018-06-18 23.44.03Z" -ConnectionString "your-connection-string" -ClusterEndPoint "clustername.centralus.cloupapp.azure.com:19080" -ClientCertificateThumbprint "Client#Certificate#Thumbpring" -ServiceId "WebReferenceApplication~RestockRequestManager"
```
2) In this example, passing storage account name and key separately. 
```powershell
 .\RetentionScript.ps1 -DateTimeBefore "2018-06-18 23.44.03Z" -StorageAccountName "storageaccountname" -StorageAccountName "storgeAccountName" -ClusterEndPoint "clustername.centralus.cloupapp.azure.com:19080" -ClientCertificateThumbprint "Client#Certificate#Thumbpring" -ServiceId "WebReferenceApplication~RestockRequestManager"
 ```
 3) You can also filter the container for cleanup. This example will delete backup data for all the partitions available on the container named brstorage:
```powershell
 .\RetentionScript.ps1 -ContainerName "brstorage"-DateTimeBefore "2018-06-18 23.44.03Z" -StorageAccountName "storageaccountname" -StorageAccountName "storgeAccountName" -ClusterEndPoint "clustername.centralus.cloupapp.azure.com:19080" -ClientCertificateThumbprint "Client#Certificate#Thumbpring"
 ```
 3) Similarly you can also filter the application by providing the ApplicationId. If Application name is *fabric:/WebReferenceApplication* then,
      application id is *WebReferenceApplication*:
```powershell
 .\RetentionScript.ps1 -ContainerName "brstorage"-DateTimeBefore "2018-06-18 23.44.03Z" -StorageAccountName "storageaccountname" -StorageAccountName "storgeAccountName" -ClusterEndPoint "clustername.centralus.cloupapp.azure.com:19080" -ClientCertificateThumbprint "Client#Certificate#Thumbpring" -ApplicationId "WebReferenceApplication"
 ```
 4) Filtering for parition with partitionId *18cf9495-7233-42a0-929d-5ca9c110b861*
```powershell
 .\RetentionScript.ps1 -ContainerName "brstorage"-DateTimeBefore "2018-06-18 23.44.03Z" -StorageAccountName "storageaccountname" -StorageAccountName "storgeAccountName" -ClusterEndPoint "clustername.centralus.cloupapp.azure.com:19080" -ClientCertificateThumbprint "Client#Certificate#Thumbpring" -PartitionId "18cf9495-7233-42a0-929d-5ca9c110b861"
 ```
    
 ## How to use with File Storage:
 
  If the storage is protected with userName(in the format Domain\user) and password, then, you need to provide password as securestring to the input variable *Password*
  Examples: 
  The below example  will delete backups of  the paritition with partition id "18cf9495-7233-42a0-929d-5ca9c110b861" before "2018-06-18 23.44.03Z".
```powershell
$pass = "Passoword" | ConvertTo-SecureString -AsPlainText -Force
 .\RetentionScript.ps1 -DateTimeBefore "2018-06-18 23.44.03Z" -FileShareUserName "Domain\brsuser"  -ClusterEndPoint "clustername.centralus.cloupapp.azure.com:19080" -ClientCertificateThumbprint "Client#Certificate#Thumbpring" -Password $pass -FileSharePath "\\fileshare\sharedfolder" -PartitionId "18cf9495-7233-42a0-929d-5ca9c110b861"  
 ```
 
  The below example  will delete backups of  the application with application id *WebReferenceApplication* before "2018-06-18 23.44.03Z".
```powershell
 .\RetentionScript.ps1 -DateTimeBefore "2018-06-18 23.44.03Z" -FileShareUserName "Domain\brsuser"  -ClusterEndPoint "clustername.centralus.cloupapp.azure.com:19080" -ClientCertificateThumbprint "Client#Certificate#Thumbpring" -Password $pass -FileSharePath "\\fileshare\sharedfolder" -ApplicationId "WebReferenceApplication"
 ```
 
  The below example  will delete backups of  the service with service id *WebReferenceApplication~RestockRequestManager* before "2018-06-18 23.44.03Z". 
 ```powershell
 .\RetentionScript.ps1 -DateTimeBefore "2018-06-18 23.44.03Z" -FileShareUserName "Domain\brsuser"  -ClusterEndPoint "clustername.centralus.cloupapp.azure.com:19080" -ClientCertificateThumbprint "Client#Certificate#Thumbpring" -Password $pass -FileSharePath "\\fileshare\sharedfolder" -ServiceId "WebReferenceApplication~RestockRequestManager"
 ```
  
 ## Notes:
 
 1) DateTimeBefore should be provided in the format(*yyyy-MM-dd HH.mm.ssZ*)
 2) ClientCertificateThumbprint is required if you are cleaning up storage of a secured cluster.
 3) If the management end point of the cluster is this *https://cluster.centralus.cloudapp.azure.com:19080/*, then, the clusterendpoint will be *cluster.centralus.cloudapp.azure.com:19080*
 4) The above script will delete the data for only those partitions on the storage which are found active on the cluster end point provided. 
    If you need to delete data for the partitions which are not active on the cluster, then add -DeleteNotFoundPartitions flag while running the retention script.

## How to schedule the script?

For azure storage, it is recommended to use azure function time trigger to schedule the script. For more information, please visit https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-timer
For file share, you can use windows task scheduler.

## More details
For more information about the parameters , please read description of RetentionScript.ps1 file by opening it in any text editor.
