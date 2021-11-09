#!/bin/bash

#
# This script installs and sets up the Service Fabric Runtime and Common SDK.
# It also sets up Azure Service Fabric CLI
#
# Usage: sudo ./SetupServiceFabric.sh
# Setting up Service Fabric from local .deb packages is supported for WSL2 based Linux VM
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

# Check if systemd is running as PID1, if not it should be enabled via system-genie
pidone=$(ps --no-headers -o comm 1)
if [ "systemd" != "$pidone" ]; then
    # Set system-genie to run systemd as PID 1
    echo "Setting up system-genie to run systemd as PID 1"
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
    echo "Installing system-genie"
    apt install -y systemd-genie

    # Start genie
    echo "Starting genie"
    genie -i
    echo "Genie has been started"

	if [[ ! -z $ServiceFabricRuntimePath ]] && [[ ! -z $ServiceFabricSdkPath ]]
	then
		echo "Copying $ServiceFabricRuntimePath to /opt/servicefabricruntime.deb"
		cp $ServiceFabricRuntimePath /opt/servicefabricruntime.deb
		echo "Copying $ServiceFabricSdkPath to /opt/servicefabricsdkcommon.deb"
		cp $ServiceFabricSdkPath /opt/servicefabricsdkcommon.deb
fi

    # Setup service fabric runtime and sdk inside genie namespace
    sudo -i -u root bash << EOF
        genie -c wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
        genie -c dpkg -i packages-microsoft-prod.deb

        genie -c curl -fsSL https://packages.microsoft.com/keys/msopentech.asc | sudo apt-key add -

        genie -c curl -fsSL https://download.docker.com/linux/ubauntu/gpg | sudo apt-key add -

        genie -c add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

        genie -c apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9
        genie -c apt-add-repository "deb http://repos.azul.com/azure-only/zulu/apt stable main"

        genie -c apt-get -y update

        genie -c echo "servicefabric servicefabric/accepted-eula-ga select true" | sudo debconf-set-selections
        genie -c echo "servicefabricsdkcommon servicefabricsdkcommon/accepted-eula-ga select true" | sudo debconf-set-selections
EOF

if [[ ! -z $ServiceFabricRuntimePath ]] && [[ ! -z $ServiceFabricSdkPath ]]
then
    sudo -i -u root bash << EOF
        echo "Installing servicefabricsdkcommon from local .deb packages"

        genie -c apt -y install /opt/servicefabricruntime.deb
        genie -c apt -y install /opt/servicefabricsdkcommon.deb
        echo "Removing /opt/servicefabricruntime.deb and /opt/servicefabricsdkcommon.deb"
        genie -c rm /opt/servicefabricruntime.deb
        genie -c rm /opt/servicefabricsdkcommon.deb
EOF

else
	sudo -i -u root bash << EOF
        echo "Installing servicefabricsdkcommon"
        genie -c apt-get -y install servicefabricsdkcommon
EOF
fi

    sudo -i -u root bash << EOF
        # install pyton-pip and sfctl
        genie -c apt-get -y install python-pip
        genie -c pip install sfctl
EOF

else

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

apt-get install servicefabricsdkcommon -f -y
ExitIfError $?  "Error@$LINENO: Failed to install Service Fabric SDK"


#
# Setup Azure Service Fabric CLI
#

apt-get install python -f -y
ExitIfError $?  "Error@$LINENO: Failed to install python for sfctl setup."

apt-get install python-pip -f -y
ExitIfError $?  "Error@$LINENO: Failed to install pip for sfctl setup."

pip install sfctl
ExitIfError $?  "Error@$LINENO: sfctl installation failed."

export PATH=$PATH:$HOME/.local/bin/

echo "Successfully completed Service Fabric SDK installation and setup."

fi
