#!/bin/bash
# Linux_Easyinstall.sh
# Version 0.1
# Date : 06.06.2018
# This script will install a CRC Hot Wallet Masternode in the default folder location

ADD_SWAP=N
GITHUB_DL=https://github.com/crowdcoinChain/Crowdcoin/releases/download/1.1.0/Crowdcoin_command_line_binaries_linux_1.1.tar.gz
RPCUSER=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
RPCPASS=`pwgen -1 20 -n`
RPCPORT=19470
CRCPORT=12875

DAEMON=crowdcoind
CLI=crowdcoin-cli
GENKEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXX
CONF=~/.crowdcoincore/crowdcoin.conf


NONE='\033[00m'
YELLOW='\033[01;33m'
clear
cd ~
echo $PWD

echo -e "${YELLOW}
            ***************
        (*********************/
      ****************,  *,  ****
    (*********.  .       *.  *****/
   ********    ..            *******
  *******.    ..******.      ********
  ******     ,***********     *******%
 ******.    **************************
 ******    .**************************
 ******    ,**************************
 ******.    **************************
  ******     ,***********,,,,,*******
  *******.     .******.      ********
   ********     ...          *******
    ,*********.   ..     *.  ******
      ****************,  *.  ****
        ,*********************,
            ***************
${NONE}
"
echo "--------------------------------------------------------------"
echo "This script will setup a CRC Masternode in a Cold Wallet Setup"
echo "--------------------------------------------------------------"
read -p "Do you want to continue ? (Y/N)? " -n 1 -r
echo 
if [[ ! $REPLY =~ ^[Yy]$ ]]
 then
	echo "End of the script, nothing has been change."
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 
fi

#Check if current user is allowd to sudo
A=$(sudo -n -v 2>&1);test -z "$A" || echo $A|grep -q asswor
if [[ "$A" == "" ]]; then
        echo "user allowed to run Sudo"
else
        echo "current user is not member of Sudo users"
	echo "correct the problem and restart the script"
        exit 1
fi

# Add swap if needed
read -p "Do you want to add memory swap file to your system (Y/n) ?" -n 1 -r -s ADD_SWAP
if [[ ("$ADD_SWAP" == "y" || "$ADD_SWAP" == "Y" || "$ADD_SWAP" == "") ]]; then
	if [ ! -f /swapfile ]; then
	    echo && echo "Adding swap space..."
	    sleep 3
	    sudo fallocate -l $swap_size /swapfile
	    sudo chmod 600 /swapfile
	    sudo mkswap /swapfile
	    sudo swapon /swapfile
	    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
	    sudo sysctl vm.swappiness=10
	    sudo sysctl vm.vfs_cache_pressure=50
	    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
	    echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
	else
	    echo && echo "WARNING: Swap file detected, skipping add swap!"
	    sleep 3
	fi
fi
echo
echo "updating system, please wait..."
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
echo && echo "Installing UFW..."
sleep 3
sudo apt-get -y install ufw
echo && echo "Configuring UFW..."
sleep 3
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw limit ssh/tcp
sudo ufw allow $CRCPORT/tcp
sudo ufw logging on
echo "y" | sudo ufw enable
echo && echo "Firewall installed and enabled!"

echo "installing sentinel"
sudo apt-get update
sudo apt-get install git -y
sudo apt-get -y install python-virtualenv
cd ~
git clone https://github.com/crowdcoinChain/sentinelLinux.git && cd sentinelLinux
export LC_ALL=C
virtualenv ./venv
./venv/bin/pip install -r requirements.txt
#change line of sentinelconf with correct path
sed -i -e 's/dash_conf=\/home\/YOURUSERNAME\/\.crowdcoincore\/crowdcoin\.conf/dash_conf=~\/\.crowdcoincore\/crowdcoin.conf/g' sentinel.conf

cd ~
sudo apt-get install pwgen libzmq4-dev libminiupnpc-dev libssl-dev libevent-dev -y
sudo apt-get install build-essential libtool autotools-dev automake pkg-config -y
sudo apt-get install libssl-dev libevent-dev bsdmainutils software-properties-common -y
sudo apt-get install libboost-all-dev -y
sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get update 
sudo apt-get install libdb4.8-dev libdb4.8++-dev wget -y
wget $GITHUB_DL
tar -zxf Crowdcoin_command_line_binaries_linux_1.1.tar.gz

echo $PWD

mkdir .crowdcoincore
cd .crowdcoincore
rpcuser=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
rpcpass=`pwgen -1 20 -n`
echo "rpcuser=${rpcuser}
rpcpassword=${rpcpass}" >> crowdcoin.conf
echo $PWD
cd ..
cd Crowdcoin_command_line_binaries_linux_1.1
echo $PWD
./crowdcoin-cli stop
sleep 10
./crowdcoind -daemon
sleep 5
crowdcoinGetInfoOutput=$(./crowdcoin-cli getinfo)
while [[ ! ($crowdcoinGetInfoOutput = *"version"*) ]]; do
	sleep 60
	$crowdcoinGetInfoOutput
done	
echo "Testing"  masterNodeAccountAddress=$(./crowdcoin-cli getaccountaddress 0)
echo "Testing" masternodeGenKey=$(./crowdcoin-cli masternode genkey)
echo "Send the collateral to the following address: ".$masterNodeAccountAddress
./crowdcoin-cli stop
sleep 10
#write all data into ../crowdcoind
locateCrowdCoinConf=~/.crowdcoincore/crowdcoin.conf
echo "rpcallowip=127.0.0.1
rpcport=$RPCPORT
rpcthreads=8
listen=1
server=1
daemon=1
staking=0
discover=1
addnode=96.126.124.245
addnode=121.200.4.203
addnode=188.165.52.69
addnode=207.148.121.239
addnode=84.17.23.43:12875
addnode=18.220.138.90:12875
addnode=86.57.164.166:12875
addnode=86.57.164.146:12875
addnode=18.217.78.145:12875
addnode=23.92.30.230:12875
addnode=35.190.182.68:12875
addnode=80.209.236.4:12875
addnode=91.201.40.89:12875
masternode=1
masternodeprivkey=$masternodeGenKey" >> $locateCrowdCoinConf
./crowdcoind -daemon
## now on you have to get the privatekeY and the address 0
echo "Testing"  masternodeOutputs=$(./crowdcoin-cli masternode outputs) | tr -d "{}:\""
exit
while [[ $masternodeOutputs -ge 3 ]]; do
        sleep 60
        masternodeOutputs=$(./crowdcoin-cli masternode outputs) | tr -d "{}:\""
done
#cd Crowdcoin_command_line_binaries_linux_1.1
./crowdcoin-cli stop
sleep 10
locateMasternode=~/.crowdcoincore/masternode.conf
masternodeConfSample="mn1 127.0.0.1:12875".$masternodeGenKey.$masternodeOutputs
echo $masternodeConfSample >> $locateMasternode
./crowdcoind -daemon -reindex
masternodeStartOutput=$(./crowdcoin-cli masternode start)
while [[ ! ($masternodeStartOutput = *"started"*) ]]; do
        sleep 60
        $masternodeStartOutput
done
echo "$masternodeStartOutput"
