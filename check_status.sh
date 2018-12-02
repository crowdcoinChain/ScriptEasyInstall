#!/bin/bash
#----------------------------------------------------------------------------
#
# This script is a basic monitoring script
# 
# it check your masternode status by runing the following command
#  
#  "./crowdcoin-cli masternode status" to grab your tx-id
#  "./crowdcoin-cli masternode list" to search for your node state
#
# then it's parse the output return returned
# 
# if the masternode is in "NEW_START_REQUIRED" it will lanch the command
# 
# ./crowdcoin-cli masternode start-all
# 
# this Script suppose that you install the masternode software using the 
# linux_easyinstall.sh from https://github.com/crowdcoinChain/ScriptEasyInstall
# so and that the binary are install in default location used by this script
# if not, you will have to modify the BIN_DIR Variable

BIN_DIR=~/Crowdcoin_command_line_binaries_linux_2.0.1
CRC_CLI=crowdcoin-cli

TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`

if [ -d "$BIN_DIR" ]; then
  # BIN_DIR exist
  cd $BIN_DIR
  if [ -f "$CRC_CLI" ]; then
        masternodestatus=""
        masternodestatus="$(./$CRC_CLI masternode status 2>/dev/null | grep "vin" | tr -d "{},:\"")"
        if [[ $masternodestatus = "" ]]; then
                echo "$TIMESTAMP : ERROR : can not connect to masternode"
                exit 1
        else
            str_array=($masternodestatus)
            tx=${str_array[1]#CTxIn\(COutPoint\(}
            id=${str_array[2]:0:1}
            #echo $tx-$id
            masternodelist=`./crowdcoin-cli masternode list | grep "$tx-$id" | tr -d "\":," | cut -d : -f 1`
            masternodestate_line="$masternodelist"
            if [[ $masternodestate_line = "" ]]; then
                    echo "$TIMESTAMP : ERROR : can not found masternode with transaction-id : $tx-$id"
                    echo "$TIMESTAMP : $masternodestate_line"
                    exit 1
            else
                    #echo $masternodestate_line
                    str_array=($masternodestate_line)
                    masternodestate=${str_array[1]}
                    #if [[ $masternodestate = *ENABLE* ]]; then
                    if [[ $masternodestate = *NEW_START_REQUIRED* ]] || [[ $masternodestate = *error* ]] ; then
                            restart="$(./crowdcoin-cli masternode start-all)"
                            echo "$TIMESTAMP : Masternode start command send : $restart"
                    else
                            #echo $masternodestate
                            exit 0
                    fi
            fi
        fi
  else
        echo "$TIMESTAMP : ERROR : can not found $CRC_CLI  in $BIN_DIR"
        echo "$TIMESTAMP : please check you run the script as the user containing the crowdcoin binaries and crowdcoind config file"
        exit 1
  fi
else
  echo "$TIMESTAMP : ERROR : $BIN_DIR does not exist"
  echo "$TIMESTAMP : please check you run the script as the user containing the crowdcoin binaries and crowdcoind config file"
  exit 1
fi
