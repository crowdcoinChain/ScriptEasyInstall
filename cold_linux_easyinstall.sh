#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='crowdcoin.conf'
CONFIGFOLDER='/root/.crowdcoinbrain'
COIN_DAEMON='crowdcoind'
COIN_VERSION='v2.0.1'
COIN_CLI='crowdcoin-cli'
COIN_PATH='/usr/local/bin/'
COIN_REPO='https://github.com/crowdcoinChain/Crowdcoin'
COIN_TGZ='https://github.com/crowdcoinChain/Crowdcoin/releases/download/2.0.1/Crowdcoin_command_line_binaries_linux_2.0.1.tar.gz'
COIN_BINDIR='Crowdcoin_command_line_binaries_linux_2.0.1'
COIN_ZIP=$(echo $COIN_TGZ | awk -F'/' '{print $NF}')
SENTINEL_REPO='https://github.com/crowdcoinChain/sentinelLinux.git'
#COIN_BOOTSTRAP='XX'
COIN_NAME='crowdcoin'
COIN_PORT=8585
RPC_PORT=11998
NODEIP=$(curl -s4 icanhazip.com)

BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m" 
PURPLE="\033[0;35m"
RED='\033[0;31m'
GREEN="\033[0;32m"
NC='\033[0m'
MAG='\e[1;35m'

purgeOldInstallation() {
    echo -e "${GREEN}Searching and removing old $COIN_NAME files and configurations${NC}"
    #kill wallet daemon
    systemctl stop $COIN_NAME.service > /dev/null 2>&1
    sudo killall $COIN_DAEMON > /dev/null 2>&1
    #remove old ufw port allow
    sudo ufw delete allow 8585/tcp > /dev/null 2>&1
    #remove old files
	rm /root/$CONFIGFOLDER/bootstrap.dat.old > /dev/null 2>&1
	cd /usr/local/bin && sudo rm $COIN_CLI $COIN_DAEMON > /dev/null 2>&1 && cd
    cd /usr/bin && sudo rm $COIN_CLI $COIN_DAEMON > /dev/null 2>&1 && cd
        sudo rm -rf ~/$CONFIGFOLDER > /dev/null 2>&1
    #remove binaries and Crowdcoin utilities
    cd /usr/local/bin && sudo rm crowdcoin-cli crowdcoin-tx crowdcoind > /dev/null 2>&1 && cd
}

function install_sentinel() {
  echo -e "${GREEN}Installing sentinel${NC}"
  apt-get -y install python-virtualenv virtualenv >/dev/null 2>&1
  git clone $SENTINEL_REPO $CONFIGFOLDER/sentinelLinux >/dev/null 2>&1
  cd $CONFIGFOLDER/sentinelLinux
  export LC_ALL=C
  virtualenv ./venv >/dev/null 2>&1
  ./venv/bin/pip install -r requirements.txt >/dev/null 2>&1
  sed -i -e 's/dash_conf=\/home\/YOURUSERNAME\/\.crowdcoinbrain\/crowdcoin\.conf/dash_conf=\/root\/.crowdcoinbrain\/crowdcoin.conf/g' sentinel.conf
  echo  "* * * * * cd $CONFIGFOLDER/sentinelLinux && ./venv/bin/python bin/sentinel.py >> $CONFIGFOLDER/sentinel.log 2>&1" > $CONFIGFOLDER/$COIN_NAME.cron
  crontab $CONFIGFOLDER/$COIN_NAME.cron
  rm $CONFIGFOLDER/$COIN_NAME.cron >/dev/null 2>&1
}

function download_node() {
  echo -e "${GREEN}Downloading and installing $COIN_NAME daemon${NC}"
  cd $TMP_FOLDER >/dev/null 2>&1
  git clone $COIN_REPO
  cd Crowdcoin
  ./autogen.sh
  ./configure.sh --without-gui --with-boost-libdir=/usr/local/lib
  make -j
  make install
  compile_error
  tar xvzf $COIN_ZIP >/dev/null 2>&1
  cd $COIN_BINDIR
  chmod +x $COIN_DAEMON $COIN_CLI
  cp $COIN_DAEMON $COIN_CLI $COIN_PATH
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}
function configure_systemd() {
  cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target

[Service]
User=root
Group=root

Type=forking
#PIDFile=$CONFIGFOLDER/$COIN_NAME.pid

ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME.service"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}


function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
rpcthreads=8
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
port=$COIN_PORT
staking=0
discover=1
EOF
}

function grab_bootstrap() {
cd $CONFIGFOLDER
  wget -q $COIN_BOOTSTRAP
}

function create_key() {
  echo -e "${YELLOW}Enter your ${RED}$COIN_NAME masternode genkey${NC}:"
  read -e COINKEY
  if [[ -z "$COINKEY" ]]; then
  $COIN_PATH$COIN_DAEMON -daemon
  sleep 30
  if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
   echo -e "${RED}$COIN_NAME server couldn not start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  if [ "$?" -gt "0" ];
    then
    echo -e "${RED}Wallet not fully loaded. Let us wait and try again to generate the GEN Key${NC}"
    sleep 30
    COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  fi
  $COIN_PATH$COIN_CLI stop
fi
clear
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $CONFIGFOLDER/$CONFIG_FILE
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
logintimestamps=1
maxconnections=256
masternode=1
externalip=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY

#ADDNODES
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

EOF
}


function enable_firewall() {
  echo -e "Installing and setting up firewall to allow port ${GREEN}$COIN_PORT${NC}"
  ufw allow $COIN_PORT/tcp comment "$COIN_NAME MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}


function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $COIN_NAME. Please investigate.${NC}"
  exit 1
fi
}


function checks() {

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $COIN_DAEMON)" ] || [ -e "$COIN_DAEMOM" ] ; then
  echo -e "${RED}$COIN_NAME is already installed.${NC}"
  exit 1
fi
}

function prepare_system() {
echo -e "Preparing the VPS to setup: ${RED}$COIN_NAME masternode${NC}"
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${PURPLE}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install pwgen -y >/dev/null 2>&1
apt-get install libzmq3-dev -y >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autotools-dev autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev libboost-all-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev  libdb5.3++ unzip libzmq5 >/dev/null 2>&1
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool autotools-dev software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev libboost-all-dev sudo automake git curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev libdb5.3++ unzip libzmq5"
 exit 1
fi
clear
}

function important_information() {
 clear
 echo
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${CYAN}Guide: https://github.com/crowdcoinChain/ScriptEasyInstall/blob/master/README.md${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${RED}$COIN_NAME${NC} masternode is up and running and listening on port ${PURPLE}$COIN_PORT${NC}."
 echo -e "${BLUE}${NC}"
 echo -e "${GREEN}Service start: ${NC}${RED}systemctl start $COIN_NAME.service${NC}"
 echo -e "${GREEN}Service stop: ${NC}${RED}systemctl stop $COIN_NAME.service${NC}"
 echo -e "${GREEN}Service status: ${NC}${RED}systemctl status $COIN_NAME.service${NC}"
 echo -e "${GREEN}Configuration file: ${NC}${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 if [[ -n $SENTINEL_REPO  ]]; then
 echo -e "${GREEN}Sentinel folder: ${NC}${RED}$CONFIGFOLDER/sentinelLinux${NC}"
 echo -e "${GREEN}Sentinel logfile: ${NC}${RED}$CONFIGFOLDER/sentinel.log${NC}"
 fi
 echo -e "${BLUE}${NC}"
 echo -e "${GREEN}VPS_IP:PORT ${NC}${PURPLE}$NODEIP:$COIN_PORT${NC}"
 echo -e "${GREEN}MASTERNODE GENKEY: ${NC}${PURPLE}$COINKEY${NC}"
 echo -e "${BLUE}${NC}"
 echo -e "${CYAN}Ensure your masternode is fully SYNCED with the BLOCKCHAIN${NC}"
 echo -e "https://explorer.crowdcoin.site/"
 echo -e "Masternode config: ${PURPLE}<ALIAS> $NODEIP:$COIN_PORT $COINKEY <TX> <ID>${NC}"
 echo -e "${BLUE}${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "To monitor, run the following commands on your vps:"
 echo -e "${RED}crowdcoin-cli masternode status${NC}"
 echo -e "${RED}crowdcoin-cli getinfo${NC}"
 echo -e "${RED}crowdcoin-cli mnsync status${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${YELLOW}DONATION (CRC): CV8WdSZKp4rcTUxMLoPg8WcS1PdqEjgREV${NC}"
 echo -e "${YELLOW}DONATION (ETH): 0x06E4454CB946038E3252eD1d5B3fDafb85E089F5${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
}

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  #grab_bootstrap
  install_sentinel
  important_information
  configure_systemd
}

##### Main #####
clear

#purgeOldInstallation
checks
prepare_system
download_node
setup_node
