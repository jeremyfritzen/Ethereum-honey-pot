# Ethereum Honey Pot
This honey pot allows you to trap Ethereum hackers who want to steal your altcoins from you.

## Prerequisites
- Required packages: web3 (gochain), jq, httpie
- Required accounts:
	- account on infura.io in order to be able to communicate with the Ethereum blockchain
	- account on etherscan.io in order to check the transaction status
	- account on pushbullet if you want to receive notifications
	- 2 "corrupted" Ethereum addresses: 1 "corrupted" and another one to receive the ETH balance.

## How does it work?
The script will monitor a given Ethereum address balance, the one that might be corrupted.
Once some amount of Ethereum is received, the script will try to send the ETH balance to another given address. the script will automatically set the gas fess based on ethgasstation.info.

## Installation & Configuration
1. Copy the "template.conf" in 2 new files: TEST.conf and PROD.conf
2. Set your own configuration in the conf files.
3. In eth_honey_pot.sh file, set testMode variable to true or false depending on your self-confidence.

## Usage
1. Run the script and let it run. You may want to use screen program for convenience.
2. Add some DAI in your corrupted address.
3. Wait for the thief to send some ETH (he will need to send some if he wants to get your DAI).
4. Enjoy your new ETH :)

## Warnings
The script is not perfect.
At the moment, it is still possible for the thief to put high transaction fees in order to make sure his transaction will be processed before yours. The script is not able to adapt gas fees to his gas fees. Any help would be appreciated :)

## Next devs
- Monitor transactions in order to make sure the thief's transaction won't be processed before yours.
- Put the program into a container in order to make it more portable, to avoid dependencies issues and to restart it automatically in case it would crash.
