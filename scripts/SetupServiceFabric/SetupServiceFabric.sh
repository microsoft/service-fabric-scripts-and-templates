#!/bin/bash

#
# This script installs and sets up the Service Fabric Runtime and Common SDK.
# It also sets up Azure Service Fabric CLI
#
# Usage: sudo ./SetupServiceFabric.sh
# Setting up Service Fabric from local service fabric runtime and sdk debain packages is all supported, both two debain packages will be needed for installation.
# This script should be called with path of sf runtime and sf sdk. Below is the sample
# sudo ./setup.sh --servicefabricruntime=/mnt/c/Users/sindoria/Downloads/servicefabric_8.2.142.2.deb --servicefabricsdk=/mnt/c/Users/sindoria/Downloads/servicefabric_sdkcommon_1.4.2.deb
# In above scenario sf runtime is located at C:\Users\sindoria\Downloads\servicefabric_8.2.142.2.deb in windows host but in VM it will look like /mnt/c/Users/sindoria/Downloads/servicefabric_8.2.142.2.deb
# Above paths should be provided appropriately as per Linux VM
#

if [ "$EUID" -ne 0 ]; then
    echo Please run this script as root or using sudo
    exit
fi

ExitIfError()
{
    if [ $1 != 0 ]; then
        echo "$2" 1>&2
        exit -1
    fi
}

Distribution=`lsb_release -cs`
if [[ "xenial" != "$Distribution" && "bionic" != "$Distribution" ]]; then
    echo "Service Fabric is not supported on $Distribution"
    exit -1
fi

# Check ServiceFabricRuntimePath and ServiceFabricSdkPath have been provided. If yes, extract that
ServiceFabricRuntimePath=""
ServiceFabricSdkPath=""
for i in "$@"
do
case $i in
    -sfrt=*|--servicefabricruntime=*)
    ServiceFabricRuntimePath="${i#*=}"
    ;;
    -sfs=*|--servicefabricsdk=*)
    ServiceFabricSdkPath="${i#*=}"
    ;;
    *)
    echo Error: Unknown option passed in: $i
    exit 1
    ;;
esac
done

# Check if systemd is running as PID1, if not it should be enabled via systemd-genie
pidone=$(ps --no-headers -o comm 1)
if [[ "systemd" != "$pidone" ]]; then
    # Set systemd-genie to run systemd as PID 1
    echo "Setting up systemd-genie to run systemd as PID 1"
    echo "Installing .NET SDK and runtime 5.0"
    wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb

    echo "Installing the .NET SDK"
    apt-get update; \
    apt-get install -y apt-transport-https && \
    apt-get update && \
    apt-get install -y dotnet-sdk-5.0

    echo "Installing the .NET runtime "
    apt-get update; \
    apt-get install -y apt-transport-https && \
    apt-get update && \
    apt-get install -y aspnetcore-runtime-5.0

    echo "Adding the wsl-translinux repository"
    apt install apt-transport-https

    wget -O /etc/apt/trusted.gpg.d/wsl-transdebian.gpg https://arkane-systems.github.io/wsl-transdebian/apt/wsl-transdebian.gpg
    chmod a+r /etc/apt/trusted.gpg.d/wsl-transdebian.gpg

    file="/etc/apt/sources.list.d/wsl-transdebian.list"
    echo "deb https://arkane-systems.github.io/wsl-transdebian/apt/ $(lsb_release -cs) main" >> $file
    echo "deb-src https://arkane-systems.github.io/wsl-transdebian/apt/ $(lsb_release -cs) main" >> $file
    cat $file

    apt update
    echo "Installing systemd-genie"
    apt install -y systemd-genie

    # Start genie
    echo "Starting genie"
    genie -i
    echo "Genie has been started"
fi

#
# If setup is being done inside WLS2 Distribution, then below helps in doing installation inside genie namespace if needed
#
genieCommand=''
isGenieInstalled=$(apt list --installed | grep systemd-genie)

if [[ ! -z "$isGenieInstalled" ]]; then
    isGenieRunning=$(genie -r)
    isOutsideGenie=$(genie -b)

    if [[ "$isGenieRunning"=="runnning" && "$isOutsideGenie"=="outside" ]]; then
        genieCommand="genie -c"
    fi

    # if genie is used for cluster management, current user should get permission to control service without sudo password.
    # This enables cluster management from windows host via Powershell or LocalClusterManager.
    # find user running the script
    usr=$SUDO_USER
    # if this script is being run by root dont do anything
    if [ -z "$usr" ] || [ "root" = "$usr" ]; then
        echo "This script should be run by default user with sudo, otherwise add <USERNAME ALL = (ALL) NOPASSWD:ALL> in /etc/sudoers manually. This enables linux cluster management from windwos host via powershell or LocalClusterManager."
    else
        # Copy /etc/sudoers to /tmp/sudoers.new
        cp /etc/sudoers /tmp/sudoers.new
        # Remove entery if exists and then make an entry for current user
        userentry="$usr ALL = (ALL) NOPASSWD:ALL"
        sed -i "/${userentry}/d" /tmp/sudoers.new
        sed -i "$ a ${userentry}" /tmp/sudoers.new
        # check validity of entry using visudo, if
        visudo -c -f /tmp/sudoers.new
        if [ "$?" -eq "0" ]; then
            echo "hello world"
            cp /tmp/sudoers.new /etc/sudoers
        fi
        rm /tmp/sudoers.new
    fi
fi

#
# Install all packages
#
MSPackage="https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
wget -q $MSPackage
dpkg -i packages-microsoft-prod.deb
ExitIfError $?  "Error@$LINENO: Failed to add package $MSPackage"

curl -fsSL https://packages.microsoft.com/keys/msopentech.asc | apt-key add -
ExitIfError $?  "Error@$LINENO: Failed to add MS GPG key"

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
ExitIfError $?  "Error@$LINENO: Failed to add Docker GPG key"

add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
ExitIfError $?  "Error@$LINENO: Failed to setup docker repository"

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9
apt-add-repository "deb http://repos.azul.com/azure-only/zulu/apt stable main"
ExitIfError $?  "Error@$LINENO: Failed to add key for zulu repo"

apt-get update

#
# Install Service Fabric SDK.
#
echo "servicefabric servicefabric/accepted-eula-ga select true" | debconf-set-selections
echo "servicefabricsdkcommon servicefabricsdkcommon/accepted-eula-ga select true" | debconf-set-selections

#
#  If local debian packages for ServiceFabricRunTime and ServiceFabricSDK are provided, install SF SDK from these packages
#
if [[ ! -z $ServiceFabricRuntimePath ]] && [[ ! -z $ServiceFabricSdkPath ]]; then
    echo "Copying $ServiceFabricRuntimePath to /opt/servicefabricruntime.deb"
    cp $ServiceFabricRuntimePath /opt/servicefabricruntime.deb
    echo "Copying $ServiceFabricSdkPath to /opt/servicefabricsdkcommon.deb"
    cp $ServiceFabricSdkPath /opt/servicefabricsdkcommon.deb

    echo "Installing servicefabricsdkcommon from local .deb packages"
    $genieCommand apt -y install /opt/servicefabricruntime.deb
    $genieCommand apt -y install /opt/servicefabricsdkcommon.deb
    echo "Removing /opt/servicefabricruntime.deb and /opt/servicefabricsdkcommon.deb"
    rm /opt/servicefabricruntime.deb
    rm /opt/servicefabricsdkcommon.deb
else
    $genieCommand apt-get install servicefabricsdkcommon -f -y
    ExitIfError $?  "Error@$LINENO: Failed to install Service Fabric SDK"
fi

#
# Setup Azure Service Fabric CLI
#

$genieCommand apt-get install python -f -y
ExitIfError $?  "Error@$LINENO: Failed to install python for sfctl setup."

$genieCommand apt-get install python-pip -f -y
ExitIfError $?  "Error@$LINENO: Failed to install pip for sfctl setup."

$genieCommand pip install sfctl
ExitIfError $?  "Error@$LINENO: sfctl installation failed."

export PATH=$PATH:$HOME/.local/bin/

echo "Successfully completed Service Fabric SDK installation and setup."