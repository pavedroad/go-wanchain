#!/bin/bash
# set -x
DOCKERIMG=wanchain/client-go:3.0.2

echo ''
echo ''
echo ''
echo ''
echo '=========================================='
echo '|   Welcome to testnet Validator Update  |'
echo ''
echo 'If you have deployed your validator with deployValidator.sh, you can update with this script'
echo 'Please make sure that only one gwan docker is running on the current machine.'
echo 'Otherwise, please update the gwan version manually.'
echo 'gwan binary URL: https://github.com/wanchain/go-wanchain/releases'
echo 'gwan docker image: ' ${DOCKERIMG}
echo ''
echo ''

freeDisk=$(df -k $HOME | sed -n 2p | awk '{print $4}')
if [ $freeDisk -lt 20000000 ] ; then
	echo " Your disk free storage is not enough(less than 20G), please check and try again"
	exit -1
fi

echo 'Please Enter your validator Name:'
read YOUR_NODE_NAME
echo 'Please Enter your validator Address'
read addrNew
echo 'Please Enter your password of Validator account:'
read -s PASSWD
read -p "Do you want save your password to disk for auto restart? (N/y): " savepasswd
read -p "Do you want to upload the host information (CPU, Memory, Disk, etc.) to the Wanchain log server? (N/y): " allowMonitor
echo ''
echo ''
echo ''
echo ''
echo ''


NETWORK=--testnet
NETWORKPATH=testnet
DOCKERID=$(sudo docker ps|grep gwan|awk '{print $1}')
GCMODE='full'
if [ "$GCMODEENV" = "archive" ]; then
    GCMODE='archive'
fi

sudo docker pull ${DOCKERIMG}
if [ $? -ne 0 ]; then
    echo "Docker Pull failed. Please verify your Access of docker command."
    echo "You can add yourself into docker group by this command, and re-login:"
    echo "sudo usermod -aG docker ${USER}"
    exit 1
else
    echo "docker pull succeed"
fi

sudo docker stop ${DOCKERID} >/dev/null 2>&1

sudo docker rm ${DOCKERID} >/dev/null 2>&1

sudo docker stop gwan >/dev/null 2>&1

sudo docker rm gwan >/dev/null 2>&1

waddrCount=$(sudo docker run --privileged --name gwan -v ${HOME}/.wanchain:/root/.wanchain ${DOCKERIMG} /bin/gwan --testnet account  pubkeys ${addrNew} ${PASSWD} | grep waddress | wc -l)
sudo docker rm gwan >/dev/null 2>&1
echo waddrCount $waddrCount
if [ $waddrCount -ne 1 ]; then
    echo 'Invalid password, please try again'
    exit 1
fi

echo ${PASSWD} | sudo tee ~/.wanchain/pw.txt > /dev/null
if [ $? -ne 0 ]; then
    echo "Write pw.txt failed"
    exit 1
fi

sudo touch ~/.wanchain/startGwan.sh
sudo chmod 666 ~/.wanchain/startGwan.sh
sudo echo '#!/bin/bash'  > ~/.wanchain/startGwan.sh
sudo echo ''  >> ~/.wanchain/startGwan.sh
if [ "$allowMonitor" == "Y" ] || [ "$allowMonitor" == "y" ]; then
    sudo echo "/bin/monitor.sh 1515 &" >> ~/.wanchain/startGwan.sh
fi
sudo echo "/bin/gwan ${NETWORK} --gcmode=${GCMODE} --miner.etherbase ${addrNew} --unlock ${addrNew} --password /root/.wanchain/pw.txt --mine --miner.threads=1 --ethstats ${YOUR_NODE_NAME}:admin@testnet.wanstats.io" >> ~/.wanchain/startGwan.sh
sudo chmod 755 ~/.wanchain/startGwan.sh

IPCFILE="$HOME/.wanchain/testnet/gwan.ipc"
sudo rm -f $IPCFILE

sudo docker run --privileged -d --log-opt max-size=100m --log-opt max-file=3 --name gwan -p 17717:17717 -p 17717:17717/udp -v ~/.wanchain:/root/.wanchain ${DOCKERIMG} /root/.wanchain/startGwan.sh

if [ $? -ne 0 ]; then
    echo "docker run failed"
    exit 1
fi

echo 'Please wait a few seconds...'

sleep 30

if [ "$savepasswd" == "Y" ] || [ "$savepasswd" == "y" ]; then
    echo ''
else
    while true
    do
        sudo ls -l $IPCFILE > /dev/null 2>&1
        Ret=$?
        if [ $Ret -eq 0 ]; then
            cur=`date '+%s'`
            ft=`sudo stat -c %Y $IPCFILE`
            if [ $cur -gt $((ft + 6)) ]; then
                break
            fi
        fi
        echo -n '.'
        sleep 1
    done
    sudo rm ~/.wanchain/pw.txt
    if [ $? -ne 0 ]; then
        echo "rm pw.txt failed"
        exit 1
    fi
fi

echo ''
echo ''
echo ''
echo ''

if [ $(ps -ef | grep -v "grep\b" | grep -c "/bin/gwan\b") -gt 0 ];
then 
    if [ "$savepasswd" == "Y" ] || [ "$savepasswd" == "y" ]; then
        sudo docker container update --restart=always gwan
    fi
    echo "Validator Start Success";
else
    echo "Validator Start Failed";
    echo "Please use command 'sudo docker logs gwan' to check reason." 
fi
