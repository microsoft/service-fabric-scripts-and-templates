
# About the scripts:
These module are used to cleanup the storage configured for BRS service in service fabric. It allows you to delete data older than specific date time.

## Usage
Import all the modules, and the use of these modules is same as of RetentionScript.ps1.
Example:
```powershell
 Start-RetentionScript -DateTimeBefore "2018-06-18 23.44.03Z" -ConnectionString "your-connection-string" -ClusterEndPoint "clustername.centralus.cloupapp.azure.com:19080" -SSLCertificateThumbPrint "Client#Certificate#Thumbpring" -ServiceId "WebReferenceApplication~RestockRequestManager"
```
These modules come in handy while scheduling the script from azure time trigger.
