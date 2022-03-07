// Copyright 2021 The adkgo Authors
// This file is part of adkgo.
//
// adkgo is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// adkgo is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with adkgo. If not, see <http://www.gnu.org/licenses/>.

package main

import (
    "fmt"
    "log"
    "context"
    "math/big"
    "crypto/ecdsa"
    "github.com/aidoskuneen/adk-node/accounts/abi/bind"
    "github.com/aidoskuneen/adk-node/common"
    "github.com/aidoskuneen/adk-node/crypto"
    "github.com/aidoskuneen/adk-node/ethclient"
)

var adkTransactionsContract common.Address;

var adk *ADKTransactions;
var initialized bool; //default is false

func GetADKInstance(client *ethclient.Client)(*ADKTransactions) {
  if (!initialized){
    address := common.HexToAddress(*ADKTransactionContract) // main contract
    var err error
    adk , err = NewADKTransactions(address, client)
    if err != nil {
         log.Fatal(err)
    } else {
      initialized = true
    }
  }
  return adk;
}

func GetAuth(client *ethclient.Client)(*bind.TransactOpts){
   publicKey := key.PrivateKey.Public()
   publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
   if !ok {
       log.Fatal("error casting public key to ECDSA")
   }
   fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)
   nonce, err := client.PendingNonceAt(context.Background(), fromAddress)
   if err != nil {
       log.Fatal(err)
   }

   chainID := big.NewInt(40272) //40272 is mainnet  //40271 is testnet
   auth, _ := bind.NewKeyedTransactorWithChainID(key.PrivateKey,chainID)
   auth.Nonce = big.NewInt(int64(nonce))
   auth.Value = big.NewInt(0)     // in wei
   auth.GasLimit = uint64(100000000) // in units
   auth.GasPrice = big.NewInt(0)
   return auth
}

func GetAuthForContract(client *ethclient.Client)(*bind.TransactOpts){ //
   publicKey := key.PrivateKey.Public()
   publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
   if !ok {
       log.Fatal("error casting public key to ECDSA")
   }
   fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)
   nonce, err := client.PendingNonceAt(context.Background(), fromAddress)
   if err != nil {
       log.Fatal(err)
   }

   chainID := big.NewInt(40272)  //40272 is mainnet   //40271 is testnet
   auth, _ := bind.NewKeyedTransactorWithChainID(key.PrivateKey,chainID)
   auth.Nonce = big.NewInt(int64(nonce))
   auth.Value = big.NewInt(0)     // in wei
   auth.GasLimit = uint64(100000000) // in units
   auth.GasPrice = big.NewInt(0)  // genesis account does not need GAS, all others do
   return auth
}

func GetBlockNumber(client *ethclient.Client)(int64) {
    fmt.Println("GetBlockNumber") // 5671744
    header, err := client.HeaderByNumber(context.Background(), nil)
    if err != nil {
      log.Fatal(err)
      return -1
    }
    return header.Number.Int64()
}

func toByte32(s []byte) ([32]byte) {
    ret := [32]byte{}
    if len(s) >= 32 {
        for i := 0; i < 32; i++ {
          ret[i] = s[i]
        }
    }
    return ret
}
