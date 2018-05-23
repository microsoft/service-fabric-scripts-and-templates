
# About CreateDockerPackage.ps1 Script
This script is a utility used to help convert your service fabric code package to a container package.

## Usage

```powershell
$codePackagePath = 'Path to the code package to containerize.'
 $dockerPackageOutputDirectoryPath = 'Output path for the generated docker folder.'
 $applicationExeName = 'Name of the ode package executable.'
 CreateDockerPackage.ps1 -CodePackageDirectoryPath $codePackagePath -DockerPackageOutputDirectoryPath $dockerPackageOutputDirectoryPath -ApplicationExeName $applicationExeName
```

## More details
For more information, see the [How to containerize your Service Fabric Services](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-services-inside-containers)
