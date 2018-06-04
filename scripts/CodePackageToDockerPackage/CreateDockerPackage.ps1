param (
    [Parameter(Mandatory=$true, ParameterSetName = "Exe")]
    [Parameter(Mandatory=$true, ParameterSetName = "Dll")]
    [string] $CodePackageDirectoryPath,

    [Parameter(Mandatory=$true, ParameterSetName = "Exe")]
    [Parameter(Mandatory=$true, ParameterSetName = "Dll")]
    [string] $DockerPackageOutputDirectoryPath,

    [Parameter(Mandatory=$false, ParameterSetName = "Exe")]
    [string] $ApplicationExeName,

    [Parameter(Mandatory=$false, ParameterSetName = "Dll")]
    [string] $DotnetCoreDllName
)

if(!(Test-Path -Path $CodePackageDirectoryPath))
{
    Write-Error "CodePackageDirectoryPath does not exist."
    exit 1
}

if(!(Test-Path -Path $DockerPackageOutputDirectoryPath))
{
    Write-Host $DockerPackageOutputDirectoryPath "does not exist. Creating directory.."
    New-Item -ItemType directory $DockerPackageOutputDirectoryPath | Out-Null
    Write-Host "Created " $DockerPackageOutputDirectoryPath
}

$DockerPublishPath = Join-Path $DockerPackageOutputDirectoryPath -ChildPath "publish"
if(!(Test-Path -Path $DockerPublishPath))
{
    New-Item -ItemType directory $DockerPublishPath | Out-Null
    Write-Host "Created " $DockerPublishPath
}

Write-Host "Copying all files from " $CodePackageDirectoryPath " to " $DockerPublishPath
$SourceCopyPath = Join-Path $CodePackageDirectoryPath -ChildPath "*"
Copy-Item -Path $SourceCopyPath -Destination $DockerPublishPath -Recurse -Force
Write-Host "Files successfully copied."

Remove-Item $CodePackageDirectoryPath -Recurse -Force
Write-Host "Removed " $CodePackageDirectoryPath

$ServiceFabricDataInterfacesPath = Join-Path $DockerPublishPath -ChildPath "Microsoft.ServiceFabric.Data.Interfaces.dll"
if(Test-Path -Path $ServiceFabricDataInterfacesPath)
{
    Remove-Item $ServiceFabricDataInterfacesPath -Force
    Write-Host "Microsoft.ServiceFabric.Data.Interfaces.dll removed."
}

Get-ChildItem $DockerPublishPath | Where-Object{$_.Name -Match "System.Fabric.*.dll"} | Remove-Item -Force
Write-Host "Removed System.Fabric.*.dll"

$initScriptPath = Join-Path $DockerPublishPath -ChildPath "init.bat"

if ($ApplicationExeName)
{
    $initScriptContents = [System.IO.Path]::GetFileNameWithoutExtension($ApplicationExeName) + ".exe"
}
elseif ($DotnetCoreDllName) 
{
    $initScriptContents = "dotnet " + [System.IO.Path]::GetFileNameWithoutExtension($DotnetCoreDllName) + ".dll"
}
else
{
    $warning = "Modify init.bat inside " + $DockerPublishPath + " to include the name of your startup executable."
    Write-Warning $warning
}

Write-Host "Creating init.bat for docker package"
New-Item -ItemType file $initScriptPath -Value $initScriptContents -Force | Out-Null

$dockerfilePath = Join-Path $DockerPackageOutputDirectoryPath -ChildPath "Dockerfile"
$dockerfileContents = "FROM microsoft/service-fabric-reliableservices-windowsservercore:latest
ADD publish/ /
CMD C:\init.bat"

Write-Host "Creating Dockerfile"				   
New-Item -ItemType file $dockerfilePath -Value $dockerfileContents -Force | Out-Null

Write-Host "Docker package successfully created at " $DockerPackageOutputDirectoryPath
