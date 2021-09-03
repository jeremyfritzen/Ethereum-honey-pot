#!/bin/bash

#----------------------#
#      VARIABLES       #
#----------------------#
testMode=true
notifyPushbullet=true
notifyMail=true
programName="Ethereum Honey Pot"

script_path=`dirname $0`

case $testMode in
  true)
  echo "Test mode: activated"
  . $script_path/TEST.conf
  ;;
  false)
  echo "/!\ BE CAREFUL ! PRODUCTION MODE ACTIVATED ! /!\ "
  echo "Waiting 5 seconds before continuing... Press Ctrl + c to stop the script."
  sleep 5
  . $script_path/PROD.conf
  ;;
  *) echo "testMode variable not set properly" ; exit 1;;
esac

publicAddress=$(web3 myaddress --pk $privateKey | awk '{print tolower($0)}')
limit=0
gasAPI="https://ethgasstation.info/api/ethgasAPI.json"

#----------------------#
#      FUNCTIONS       #
#----------------------#

# Notification function
notify()
{
	# The function will send a Pushbullet notification.

	# 2 arguments are required: Title and Message
  if [[ $notifyPushbullet == true ]]; then
    curl -s -u $pushbulletKey: -X POST https://api.pushbullet.com/v2/pushes \
    --header 'Content-Type: application/json' \
    --data-binary '{"type": "note", "title": "'"$1"'", "body": "'"$2"'", "device_iden": "'"$pushbulletDevice"'"}'
  fi

  if [[ $notifyMail == true ]]; then
    echo $2 | mail $email --subject="$1"
  fi

}

# Error Function used to exit the program while sending a notification
error_exit()
{
	# 1 argument is required: Message
    echo "${programName}: $1" 1>&2
	notify "ERROR on Eth Honey Pot!" "$1" >/dev/null 2>&1
    exit 1
}

#----------------------#
#       PROGRAM        #
#----------------------#

# For verbose mode, uncomment the following line
#set -x

date

echo "ETH Honey pot Public Key: $publicAddress"
echo "Target address: $targetAddress"

while true ; do
  # Récupération du nonce
  nonce=$(echo "$(http "${etherscanAPI}?module=account&action=txlist&address=${publicAddress}&sort=desc&apikey=${etherscanApiKey}" | jq -r '[.result[] | select(.from=="'${publicAddress}'").nonce][0]') + 1" | bc -l)
  if [ ! $nonce ]; then
    nonce=0
  fi
  echo "nonce de la prochaine transaction : $nonce"

  # Récupération de la balance initiale
  retry=1
  balance=-1
  while [ "$(bc <<< "$balance < 0")" == "1" ]  && [ "$(bc <<< "$retry >= 0")" == "1" ]; do
    balance=$(web3 $network balance --private-key $privateKey | cut -d' ' -f1)
    if [ ! $balance ]; then
      echo "Variable balance (initial) not set. Trying switching network (attempt n° $retry)"
      balance=-1
      network0=$network
      network=$networkBackup1
      networkBackup1=$networkBackup2
      networkBackup2=$network0
      echo "New network: $network"
    fi
    retry=$(($retry+1))
  done
  echo "balance intiale : $balance";
  limit=$balance;

  # Surveillance de la balance (si la balance ETH augmente, on passe à la suite)
  retry=1
  while [ "$(bc <<< "$balance <= $limit")" == "1" ] && [ "$(bc <<< "$retry >= 0")" == "1" ]; do
    while [ "$(bc <<< "$balance <= $limit")" == "1" ] ; do
      balance=$(web3 $network balance --private-key $privateKey | cut -d' ' -f1);
      echo "balance actuelle : $balance";
    done

    if [ ! $balance ]; then
      echo "Variable balance (current) not set. Trying switching network (attempt n° $retry)."
      balance=-1
      network0=$network
      network=$networkBackup1
      networkBackup1=$networkBackup2
      networkBackup2=$network0
      echo "New network: $network"
    fi
    retry=$(($retry+1))
  done


  # Récupérer les gas prices (low, standard, fast, trader) sur ethgasstation
  gasPrice=( $(http https://ethgasstation.info/api/ethgasAPI.json | jq '.safeLow,.average,.fast,.fastest') )
  echo "Gas prices : ${gasPrice[@]}"

  for (( i = 3; i >= 0; i-- )); do
    echo "Let's try with Gas price at $(( ${gasPrice[$i]} / 10 ))"
    fees=$(echo "${gasPrice[$i]} / 10 * 21000 / 1000000000 " | bc -l)
    echo "fees : $fees"
    amount=$(echo "$balance - $fees" | bc -l)
    echo "montant à envoyer : $amount"
    gasPriceGwei=$(( ${gasPrice[$i]} / 10 ))
    if [[ "$(bc <<< "$amount >= 0")" == "1" ]]; then
      break ;
    fi
  done
  echo "Gas price set to $gasPriceGwei gwei."

  # Envoyer l'ETH ($amount) sur  une autre adresse
  retry=1
  transactionHash=""
  while [ ! $transactionHash ] && [ "$(bc <<< "$retry >= 0")" == "1" ]; do
    echo "transaction à réaliser pour un montant de $amount"
    transactionHash=$(web3 $network replace --private-key $privateKey --nonce $nonce --to $targetAddress --amountd $amount --gas-price-gwei $gasPriceGwei | tee -a $script_path/logs | awk '/^Replaced/ {print $5}')
    if [ ! $transactionHash ]; then
      echo "Variable transactionHash not set. Trying switching network (attempt n° $retry)"
      network0=$network
      network=$networkBackup1
      networkBackup1=$networkBackup2
      networkBackup2=$network0
      echo "New network: $network"
      retry=$(($retry+1))
    fi
  done
  echo "transactionHash: $transactionHash"


  #Vérifier si la transaction s'est bien déroulée
  while true ; do

    if [ ! $transactionHash ]; then
      error_exit "Error when trying to send the transaction! Please check your wallet quickly!"
    fi

    transactionStatus=$(http "${etherscanAPI}?module=transaction&action=gettxreceiptstatus&txhash=${transactionHash}&apikey=${etherscanApiKey}" | jq '.result.status')
    echo $transactionStatus
    case $transactionStatus in
      '"1"') echo "Transaction is validated" ; notify "$programName" "We got him! Please check your wallet!" ; break ;;
      '"0"') echo "Transaction failed" ; error_exit "Transaction failed! Please check your wallet quickly." ;;
      '""') echo "Transaction is pending";;
    esac
  done


done


exit 0
