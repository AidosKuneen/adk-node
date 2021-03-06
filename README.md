# ADKGo SmartNode (MAINNET v2.1)

Official Golang implementation of the ADK protocol with Smart Contract funtionality and Client PoW

Note: This version retires the AZ9 address system entirely, and only allows 0x transactions going forward. You can still migrate old AZ9 (v1) balances to 0x addresses.

The node accepts two kind of transactions:
<ul>
   <li>FREE PoW Transactions (0 GAS Fee): User has performed client-side Proof of Work (requires ADK v2.1 Wallet)
	   <ul>
			<li>Requires ADK v2.1 Wallet (Option: SEND with PoW)</li>
	   </ul>
   </li>
   <li>PAID Instant Transactions (1000 uADK/Gwei GAS fee) - approx. 0.021 ADK fee per standard ADK transfer
   <ul>
			<li>Metamask, other standard Clients</li>
			<li>ADK v2.1 Wallet (Option: SEND with GAS)</li>
	</ul>
    </li>
</ul>

## BASE NODE SETUP STEPS (on clean UBUNTU server)

### Install prerequisites  (git. build-essentials, go)
```
apt-get update
apt-get install git

sudo apt install build-essential

wget https://dl.google.com/go/go1.16.7.linux-amd64.tar.gz
tar -xvf go1.16.7.linux-amd64.tar.gz
mv go /usr/local
mkdir $HOME/goprojects
```

### add the following lines to ~/.profile for future logins
```
export GOROOT=/usr/local/go
export GOPATH=$HOME/goprojects
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
```

### reload . ~/.profile     (or log out and back in)
```
. ~/.profile
```

### adding new user (re will run the node under a user, not root, for added security)
```
adduser adkgo
usermod -aG sudo adkgo
su - adkgo
mkdir $HOME/goprojects
```

### add the following lines to ~/.profile for future logins
```
export GOROOT=/usr/local/go
export GOPATH=$HOME/goprojects
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
```

### reload . ~/.profile     (or log out and back in)
```
. ~/.profile
```

### build adkgo-node (the main node):
```
cd goprojects
git clone https://github.com/AidosKuneen/adk-node.git

cd ~/goprojects/adk-node

go get github.com/AidosKuneen/gadk
go run build/ci.go install ./adkgo-node

mkdir $GOPATH/bin
cp ~/goprojects/adk-node/build/bin/* $GOPATH/bin/
```
### configuring the adkgo network (genesis block/setup), initialize the network from the genesis json
```
cd ~
mkdir -p adkgo-mainnet/node1
adkgo-node --datadir adkgo-mainnet/node1 init  ~/goprojects/adk-node/adkgo-GENESIS/adkmainnet-genesis.json
```

### prepare the node with connection details
```
cd ~/adkgo-mainnet/node1/adkgo-node
```
### create file static-nodes.json in ~/adkgo-mainnet/node1/adkgo-node with the enode of an existing node to connect to
```
[ "enode://   [TBD]    @    [TBD]    .aidoskuneen.com:40310" ]
```
Note: this is just an example enode. Please reach out in the telegram group https://t.me/joinchat/6S4CUWRDeQk2NDAy for the latest enode of an operational node
(A permanent bootnode will be configured for the mainnet, stay tuned.)

DONE. THATS THE NODE FULLY PREPARED. The steps up to here only need to be performed once. Now you can just start the node:

#  START THE NODE
```
cd ~/adkgo-mainnet/node1
nohup adkgo-node --datadir= --syncmode full --port 40310 --rpc.gascap 550000000 --rpc.txfeecap 0 --http.addr 0.0.0.0 --http --http.api eth,net,web3 --http.port 9545 --rpccorsdomain "*" > stdout.txt 2> log.txt &
```
### to view output 'live' you can use:  
```
tail -f log.txt log2.txt
```
### Additional info: How to connect your running node to additional other nodes manually, if you dont use static-nodes.json

1) Connect via IPC to the adkgo-node console:
```
cd ~/adkgo-mainnet/node1
adkgo-node attach geth.ipc
```
2) add the enode (this is only stored for the local session. use static-nodes.json to store permanently):
```
admin.addPeer("enode://   [TBD]    @    [TBD]    .aidoskuneen.com:40310")
```
Note: this is just an example enode. Please reach out in the telegram group https://t.me/joinchat/6S4CUWRDeQk2NDAy for the latest enode of an operational mainnet node
