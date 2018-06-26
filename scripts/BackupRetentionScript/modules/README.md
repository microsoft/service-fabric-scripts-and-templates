
# About the scripts:
 Service Fabric Backup Restore Service (https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-backuprestoreservice-quickstart-azurecluster),
  currently in preview, allows you to take periodic backups of your Reliable stateful service and Reliable Actors. Depending on the frequency of your backup interval, backups can really grow fast. 
 While we work on providing retention support integrated with the service, this script would help you manage your storage till that time. It allows you to delete backups older than a specified time.

## Usage
Import all the modules, and the use of these modules is same as of RetentionScript.ps1.
Example:
```powershell
 Start-RetentionScript -DateTimeBefore "2018-06-18 23.44.03Z" -ConnectionString "your-connection-string" -ClusterEndPoint "clustername.centralus.cloupapp.azure.com:19080" -SSLCertificateThumbPrint "Client#Certificate#Thumbpring" -ServiceId "WebReferenceApplication~RestockRequestManager"
```
These modules come in handy while scheduling the script from azure time trigger.
