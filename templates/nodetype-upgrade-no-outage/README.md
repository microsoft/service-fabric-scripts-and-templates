# Upgrade a Service Fabric cluster primary node type without downtime

These before/after templates represent the steps of upgrading the primary node type of an example cluster to use managed disks, while avoiding any cluster downtime.

The initial state of the example test cluster consists of one node type of Silver durability, backed by a single scale set with five nodes. The upgraded state of the cluster adds an additional, upgraded (to use managed disks), scale set. Follow these commands to walkthrough the complete upgrade scenario. For a more detailed discussion of the procedure, see [Upgrade cluster nodes to use Azure managed disks](https://docs.microsoft.com/azure/service-fabric/service-fabric-upgrade-to-managed-disks).

```powershell
# Sign in to your Azure account
Login-AzAccount -SubscriptionId "<subscription ID>"

# Assign deployment variables
$resourceGroupName="sftestupgradegroup"
$certOutputFolder="c:\certificates"
$certPassword="Password!1" | ConvertTo-SecureString -AsPlainText -Force
$certSubjectName="sftestupgrade.southcentralus.cloudapp.azure.com"
$templateFilePath="C:\Initial-1NodeType-UnmanagedDisks.json"
$parameterFilePath="C:\Initial-1NodeType-UnmanagedDisks.parameters.json"

# Deploy the initial test cluster
New-AzServiceFabricCluster `
    -ResourceGroupName $resourceGroupName `
    -CertificateOutputFolder $certOutputFolder `
    -CertificatePassword $certPassword `
    -CertificateSubjectName $certSubjectName `
    -TemplateFile $templateFilePath `
    -ParameterFile $parameterFilePath

# Import the local .pfx file to your certificate store
cd c:\certificates
$certPfx=".\sftestupgradegroup20200312121003.pfx"

Import-PfxCertificate `
     -FilePath $certPfx `
     -CertStoreLocation Cert:\CurrentUser\My `
     -Password (ConvertTo-SecureString Password!1 -AsPlainText -Force)

# Connect to the cluster and check health
$clusterName="sftestupgrade.southcentralus.cloudapp.azure.com:19000"
$thumb="BB796AA33BD9767E7DA27FE5182CF8FDEE714A70"

Connect-ServiceFabricCluster `
    -ConnectionEndpoint $clusterName `
    -KeepAliveIntervalInSec 10 `
    -X509Credential `
    -ServerCertThumbprint $thumb  `
    -FindType FindByThumbprint `
    -FindValue $thumb `
    -StoreLocation CurrentUser `
    -StoreName My

Get-ServiceFabricClusterHealth

# Find your certificate Key Vault references (in Azure portal)
$certUrlValue="https://sftestupgradegroup.vault.azure.net/secrets/sftestupgradegroup20200309235308/dac0e7b7f9d4414984ccaa72bfb2ea39"
$thumb="BB796AA33BD9767E7DA27FE5182CF8FDEE714A70"
$sourceVaultValue="/subscriptions/########-####-####-####-############/resourceGroups/sftestupgradegroup/providers/Microsoft.KeyVault/vaults/sftestupgradegroup"

# Deploy the updated template with new scale set (upgraded to use managed disks)
$templateFilePath="C:\Upgrade-1NodeType-2ScaleSets-ManagedDisks.json"
$parameterFilePath="C:\Upgrade-1NodeType-2ScaleSets-ManagedDisks.parameters.json"

New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile $templateFilePath `
    -TemplateParameterFile $parameterFilePath `
    -CertificateThumbprint $thumb `
    -CertificateUrlValue $certUrlValue `
    -SourceVaultValue $sourceVaultValue `
    -Verbose

# Ensure cluster is healthy, then disable nodes in the original scale set
Get-ServiceFabricClusterHealth
$nodeNames = @("_NTvm1_0","_NTvm1_1","_NTvm1_2","_NTvm1_3","_NTvm1_4")

Write-Host "Disabling nodes..."
foreach($name in $nodeNames){
    Disable-ServiceFabricNode -NodeName $name -Intent RemoveNode -Force
}

# When disabling operation is complete, remove the original scale set
$scaleSetName="NTvm1"

Remove-AzVmss `
    -ResourceGroupName $resourceGroupName `
    -VMScaleSetName $scaleSetName `
    -Force

Write-Host "Removed scale set $scaleSetName"

# Remove node states for the deleted scale set
foreach($name in $nodeNames){
    Remove-ServiceFabricNodeState -NodeName $name -TimeoutSec 300 -Force
    Write-Host "Removed node state for node $name"
}
