#!/bin/bash

#
# This script installs and sets up the Service Fabric Runtime and Common SDK.
# It also sets up Azure Service Fabric CLI
#
# Usage: sudo ./SetupServiceFabric.sh
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

# Check if systemd is running as PID1, if not it should enabled via system-genie
pidone=$(ps --no-headers -o comm 1)
if [ "systemd"!="$pidone" ]; then
	# Setting up system-genie to run systemd as PID 1
    echo "Setting up system-genie to run systemd as PID 1"
    echo "Installing .NET SDK and runtime 5.0"
    wget https://packages.microsoft.com/config/ubuntu/21.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
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

    echo "Starting genie"
    genie -i
    echo "Genie has been started"

    sudo -i -u root bash << EOF
        # sed -i 's/nameserver.*/nameserver 172.17.176.1/' /etc/resolv.conf

        genie -c wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
        genie -c dpkg -i packages-microsoft-prod.deb
        # genie -c ExitIfError $?  "Error@$LINENO: Failed to add package $MSPackage"

        genie -c curl -fsSL https://packages.microsoft.com/keys/msopentech.asc | sudo apt-key add -
        # genie -c ExitIfError $?  "Error@$LINENO: Failed to add MS GPG key"

		genie -c curl -fsSL https://download.docker.com/linux/ubauntu/gpg | sudo apt-key add -
        # genie -c ExitIfError $?  "Error@$LINENO: Failed to add Docker GPG key"

        genie -c add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        # genie -c ExitIfError $?  "Error@$LINENO: Failed to setup docker repository"

        genie -c apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9
        genie -c apt-add-repository "deb http://repos.azul.com/azure-only/zulu/apt stable main"

        genie -c apt-get -y update

		echo "Installing servicefabricsdkcommon"
        genie -c echo "servicefabric servicefabric/accepted-eula-ga select true" | sudo debconf-set-selections
        genie -c echo "servicefabricsdkcommon servicefabricsdkcommon/accepted-eula-ga select true" | sudo debconf-set-selections
        genie -c apt-get -y install servicefabricsdkcommon
        # genie -c ExitIfError $?  "Error@$LINENO: Failed to install Service Fabric SDK"

        # install pyton-pip and sfctl
        genie -c apt-get -y install python-pip
		# genie -c ExitIfError $?  "Error@$LINENO: Failed to install python for sfctl setup."

        genie -c pip install sfctl
		# genie -c ExitIfError $?  "Error@$LINENO: sfctl installation failed."

        #echo "Starting cluster"
        #genie -c /opt/microsoft/sdk/servicefabric/common/clustersetup/devclustersetup.sh
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
