#!/bin/bash
# linux_easyinstall.sh
# Version 0.1
# Date : 06.06.2018
# This script will install a CRC Hot Wallet Masternode in the default folder location

if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    ...
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    ...
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi

if [ "$OS" == "Ubuntu" ] && [ "$VER" == "16.04" ]; then
  echo "$OS $VER : OK"
else
  echo "This script should be run on Ubuntu 16.04 only"
  exit 1
fi


ADD_SWAP=N
GITHUB_DL=https://github.com/crowdcoinChain/Crowdcoin/releases/download/2.0.1/Crowdcoin_command_line_binaries_linux_2.0.1.tar.gz
RPCPORT=11998
CRCPORT=8585

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
echo "This script will setup a CRC Masternode in a Hot Wallet Setup"
echo "--------------------------------------------------------------"
#read -p "Do you want to continue ? (Y/N)? " -n 1 -r
#echo
#if [[ ! $REPLY =~ ^[Yy]$ ]]
# then
#        echo "End of the script, nothing has been change."
#    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
#fi

#Check if current user is allowd to sudo
sudo -v
A=$(sudo -n -v 2>&1);test -z "$A" || echo $A|grep -q asswor
if [[ "$A" == "" ]]; then
        echo "user allowed to run Sudo"
else
        echo "current user is not member of Sudo users"
        echo "correct the problem and restart the script"
        exit 1
fi

# Add swap if needed
#read -p "Do you want to add memory swap file to your system (Y/n) ?" -n 1 -r -s ADD_SWAP
ADD_SWAP="y"
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
sudo apt-get -y -q update -y
sudo apt-get -y -q upgrade -y
sudo apt-get -y -q dist-upgrade -y
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
sudo apt-get -y install python-virtualenv virtualenv
cd ~
git clone https://github.com/crowdcoinChain/sentinelLinux.git && cd sentinelLinux
export LC_ALL=C
virtualenv ./venv
./venv/bin/pip install -r requirements.txt
#change line of sentinelconf with correct path
sed -i -e 's/dash_conf=\/home\/YOURUSERNAME\/\.crowdcoinbrain\/crowdcoin\.conf/dash_conf=~\/\.crowdcoinbrain\/crowdcoin.conf/g' sentinel.conf

cd ~
sudo apt-get install pwgen
sudo apt-get install libzmq3-dev libminiupnpc-dev libssl-dev libevent-dev -y
sudo apt-get install build-essential libtool autotools-dev automake pkg-config -y
sudo apt-get install libssl-dev libevent-dev bsdmainutils software-properties-common -y
sudo apt-get install libboost-all-dev -y
sudo add-apt-repository ppa:bitcoin/bitcoin -y
sudo apt-get update
sudo apt-get install libdb4.8-dev libdb4.8++-dev wget -y

wget $GITHUB_DL
tar -zxvf ./Crowdcoin_command_line_binaries_linux_2.0.1.tar.gz

echo ""
echo "==============================================="
echo " Installation finished, starting configuration"
echo "==============================================="
echo "" 
if pgrep -x "crowdcoind" > /dev/null
then
    cd ~/Crowdcoin_command_line_binaries_linux_2.0.1
    echo "Found crowdcoind is running, stopping it..."
    ./crowdcoin-cli stop
    echo "Waiting 60 seconds before continuing..." 
    sleep 60
fi
echo "-----------------------------------------------"
echo "Setting up crowdcoin.conf RPC user and password"
echo "-----------------------------------------------"
echo ""
cd ~
mkdir -p .crowdcoinbrain
cd .crowdcoinbrain
rpcuser=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
rpcpass=`pwgen -1 20 -n`
echo "rpcuser=${rpcuser}
rpcpassword=${rpcpass}" >> crowdcoin.conf

cd ~/Crowdcoin_command_line_binaries_linux_2.0.1
echo "Starting Crowdcoind from $PWD"
./crowdcoind -daemon
sleep 60
crowdcoinGetInfoOutput=$(./crowdcoin-cli getinfo)
while [[ ! ($crowdcoinGetInfoOutput = *"version"*) ]]; do
	sleep 60
	$crowdcoinGetInfoOutput
done	
masterNodeAccountAddress=$(./crowdcoin-cli getaccountaddress 0)
masternodeGenKey=$(./crowdcoin-cli masternode genkey)
echo "----------------------------------------------------------------------"
echo "masterNodeAccountAddress : $masterNodeAccountAddress"
echo "masternodeGenKey : $masternodeGenKey"
echo "----------------------------------------------------------------------"
echo ""
echo "Stopping CrowdCoin daemon to update configuration file..."
./crowdcoin-cli stop
sleep 60
#write all data into ../crowdcoind
locateCrowdCoinConf=~/.crowdcoinbrain/crowdcoin.conf
cat >> $locateCrowdCoinConf <<EOF
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
rpcport=$RPCPORT
rpcthreads=8
listen=1
server=1
daemon=1
staking=0
discover=1
masternode=1
masternodeprivkey=$masternodeGenKey
addnode=96.126.124.245
addnode=121.200.4.203
addnode=188.165.52.69
addnode=207.148.121.239
addnode=84.17.23.43:8585
addnode=18.220.138.90:8585
addnode=86.57.164.166:8585
addnode=86.57.164.146:8585
addnode=18.217.78.145:8585
addnode=23.92.30.230:8585
addnode=35.190.182.68:8585
addnode=80.209.236.4:8585
addnode=91.201.40.89:8585 
addnode=80.211.157.98:8585
addnode=80.211.63.80:8585
addnode=80.211.164.94:8585
addnode=54.36.163.216:8585
EOF

echo "Configuration $locateCrowdCoinConf updated."
echo " Waiting 60 seconds before restarting..."
sleep 60
./crowdcoind -daemon
sleep 10
## now on you have to get the privatekeY and the address 0
masternodeOutputs=`./crowdcoin-cli masternode outputs | tr -d "{}:\""`
echo "-----------------------------------------------"
echo "Wait Masternode Syncronization..."
echo "-----------------------------------------------"
echo ""
if [ ${#masternodeOutputs} -le 3 ]; then
 echo "if not already done, send the Masternode collateral to this new address: $masterNodeAccountAddress"
fi
echo "Now waiting Masternode Sync and collateral confirmation"
echo "Checking every 5 seconds ..."
spin='-\|/'
while [ ${#masternodeOutputs} -le 3 ]; do
        i=$(( (i+1) %4 ))
        block=`./crowdcoin-cli getinfo | grep block | tr -d ,`
        balance=`./crowdcoin-cli getbalance`
        printf "\r$block | Balance : $balance ${spin:$i:1}"
        sleep 5
        masternodeOutputs=`./crowdcoin-cli masternode outputs | tr -d "{}:\""`
done
echo "OK, Transaction ID found :  $masternodeOutputs"
echo "Stopping CrowdCoin daemon to update Masternode configuration file..."
./crowdcoin-cli stop
sleep 10
locateMasternode=~/.crowdcoinbrain/masternode.conf
masternodeConfSample="mn1 127.0.0.1:$CRCPORT $masternodeGenKey $masternodeOutputs"
echo $masternodeConfSample >> $locateMasternode
echo "Masternode configuration updated. Waiting 60 seconds before restarting..."
sleep 60
./crowdcoind -daemon
sleep 10
masternodeStartOutput=$(./crowdcoin-cli masternode start-all)
echo $masternodeStartOutput
while [[ ! ($masternodeStartOutput = *"started"*) ]]; do
        i=$(( (i+1) %4 ))
        block=`./crowdcoin-cli getinfo | grep block | tr -d ,`
        balance=`./crowdcoin-cli getbalance`
        masternodeStartOutput=$(./crowdcoin-cli masternode start-all)
        printf "\r$block | Balance : $balance ${spin:$i:1} : $masternodeStartOutput                "
        sleep 5
done
echo ""
echo "Add sentinelLinux in crontab"
(crontab -l 2>/dev/null; echo "* * * * * cd ~/sentinelLinux && ./venv/bin/python bin/sentinel.py 2>&1 >> sentinel-cron.log") | crontab -
echo ""
echo "Add check MN Status in crontab"
(crontab -l 2>/dev/null; echo "* * * * * cd ~/ScriptEasyInstall &  bash check_status.sh 2>&1 >> mn-check-cron.log") | crontab -
sudo service cron reload
echo "$masternodeStartOutput"
sudo apt-get autoremove -y
sudo apt-get clean -y
