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
