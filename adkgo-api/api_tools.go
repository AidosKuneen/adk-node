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
    "github.com/aidoskuneen/adk-node"
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
    // the generic API client private key is 0x8ddda563583494672352748957abccceff773867dafe5187263541827ffaee8f
    // the generic API client public key is 0x2B5f3EC809994eD4549d4305fCf430129Dd96A3D
    // this is OK to be PUBLIC as this account is used for PoW validation, and not to keep any ADK or AGS itself

   //privateKey, err := crypto.GenerateKey() // private key
   //
   // we use a KNOWN private key, and it is OK this key is known. It is not used for anything but to submit MESH transactions
   privateKey, err := crypto.HexToECDSA("8ddda563583494672352748957abccceff773867dafe5187263541827ffaee8f")

   if err != nil {
       log.Fatal(err)
   }
   publicKey := privateKey.Public()
   publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
   if !ok {
       log.Fatal("error casting public key to ECDSA")
   }
   fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)
   nonce, err := client.PendingNonceAt(context.Background(), fromAddress)
   if err != nil {
       log.Fatal(err)
   }

   //chainID := big.NewInt(40269) // 40269 is testnet
   chainID := big.NewInt(40270) // 40270 is mainnet
   auth, _ := bind.NewKeyedTransactorWithChainID(privateKey,chainID)
   auth.Nonce = big.NewInt(int64(nonce))
   auth.Value = big.NewInt(0)     // in wei

   auth.GasLimit = (GetGasLimit(client) / 10) * 9 // 90% of actual gas limit from last block

   auth.GasPrice = big.NewInt(0)
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

func GetGasLimit(client *ethclient.Client)(uint64) {
    fmt.Println("GasLimit in LastBlock") //
    header, err := client.HeaderByNumber(context.Background(), nil)
    if err != nil {
      log.Fatal(err)
      return 450000000
    }
    return header.GasLimit
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

// find transactions, using contract
func FindTransactionsByBundles(client *ethclient.Client, bundles []interface {})([]string) {
  //GetTxByAddress
  ret := []string{}
  for _, element := range bundles { // convert and add as keccak hash to filter
      bundleHash_SHA3 := toByte32(crypto.Keccak256([]byte(element.(string))))
      cnt, err := GetADKInstance(client).TransactionhashByBundleCount(nil, bundleHash_SHA3)
      if (err != nil){
        log.Fatal(err)
      } else {
        var idx int64 = 0
        for idx = 0; idx <= int64(cnt); idx++ {
          txdata, _ := GetADKInstance(client).GetTxByBundle(nil, element.(string), big.NewInt(idx))
          if len(txdata) > 0 {
             ret = append(ret, txdata)
          }
        }
      }
  }
  return ret;
}

// find transactions, using contract
func FindTransactionsByAddress(client *ethclient.Client, addresses []interface {})([]string) {
  //GetTxByAddress
  ret := []string{}
  for _, element := range addresses { // convert and add as keccak hash to filter
      addrHash_SHA3 := toByte32(crypto.Keccak256([]byte(element.(string))))
      cnt, err := GetADKInstance(client).TransactionhashByAddressCount(nil, addrHash_SHA3)
      if (err != nil){
        log.Fatal(err)
      } else {
        var idx int64 = 0
        for idx = 0; idx <= int64(cnt); idx++ {
          txdata, _ := GetADKInstance(client).GetTxByAddress(nil, element.(string), big.NewInt(idx))
          if len(txdata) > 0 {
             ret = append(ret, txdata)
          }
        }
      }
  }
  return ret;
}


// find transactions, using events
func FindTransactionsByBundles_EVENTS(client *ethclient.Client, bundles []interface {})([]string) {
    searchFilter := [][32]byte{}
    for _, element := range bundles { // convert and add as keccak hash to filter
        bundlesha3 := toByte32(crypto.Keccak256([]byte(element.(string))))
        searchFilter = append(searchFilter, bundlesha3)
    }
    ret := []string{}

    filterOpts := &bind.FilterOpts{Context: context.Background(), Start: 0, End: nil}
    itr, _ := GetADKInstance(client).FilterTransactionsByBundle(filterOpts,searchFilter)
    // Loop over all found events
    for itr.Next() {
        transByBundleEvt := itr.Event //ADKMeshTransactionsTransactionsByBundle
        transSHA3 := transByBundleEvt.TransactionSHA3
        // get the SHA3 transaction hash
        // now need to get the transaction string
        transAZ9, err := GetADKInstance(client).TransactionHashes(nil, transSHA3)
        if (err != nil){
          log.Fatal(err)
        } else {
             ret = append(ret, transAZ9)
        }
    }
    return ret;
}

func FindTransactionsByAddresses(client *ethclient.Client, addresses []interface {})([]string) {
    searchFilter := [][32]byte{}
    for _, element := range addresses { // convert and add as keccak hash to filter
	    addresssha3 := toByte32(crypto.Keccak256([]byte(element.(string)[0:81])))
        searchFilter = append(searchFilter, addresssha3)
    }
    ret := []string{}

    filterOpts := &bind.FilterOpts{Context: context.Background(), Start: 0, End: nil}
    itr, _ := GetADKInstance(client).FilterTransactionsByAddress(filterOpts, searchFilter)
    // Loop over all found events
    for itr.Next() {
        transByAddressEvt := itr.Event //ADKMeshTransactionsTransactionsByAddress
        transSHA3 := transByAddressEvt.TransactionSHA3
        // get the SHA3 transaction hash
        // now need to get the transaction string
        transAZ9, err := GetADKInstance(client).TransactionHashes(nil, transSHA3)
        if (err != nil){
          log.Fatal(err)
        } else {
             ret = append(ret, transAZ9)
        }
    }
    return ret;
}

func GetTrytes(client *ethclient.Client, tryteHashes []interface {})([]string) {
    ret := []string{}
    for _, element := range tryteHashes { // convert and add as keccak hash to filter
        tryteHash_SHA3 := toByte32(crypto.Keccak256([]byte(element.(string))))
        transAZ9, err := GetADKInstance(client).Transactions(nil, tryteHash_SHA3)
        if (err != nil){
          //log.Fatal(err)
        } else {
             if (len(transAZ9) > 0){
                ret = append(ret, transAZ9)
             }
        }
    }
    return ret;
}

func HashExists(client *ethclient.Client, trytesHash string)(bool) {
    tryteHash_SHA3 := toByte32(crypto.Keccak256([]byte(trytesHash)))
    transAZ9, err := GetADKInstance(client).TransactionHashes(nil, tryteHash_SHA3)
    if (err != nil){
      log.Fatal(err)
      return false
    }
    if (len(transAZ9) != 81){ // doesnt exist
      return false
    }
    return true;
}

func GetBalance(client *ethclient.Client, _addr string)(int64){
    bal, err := GetADKInstance(client).GetAZ9balanceOf(nil, _addr)
    if (err != nil){
      log.Fatal(err)
      return 0
    }
    return bal.Int64()
}

func GetTip(client *ethclient.Client)(string) {
    meshTip_b32, err := GetADKInstance(client).MeshTip(nil)
    ret, err := GetADKInstance(client).TransactionHashes(nil, meshTip_b32)

    if (err != nil){
         log.Println(err)
         ret = defaultMilestone
    }
    return ret;
}

func SendTransactions(client *ethclient.Client, transactions string)(bool, error) {
    auth := GetAuth(client)
    tx, err := GetADKInstance(client).PostTransactions(auth, transactions)
    if err != nil {
        fmt.Println(err)
        return false, err
    }

    fmt.Println("tx sent: "+tx.Hash().Hex()) // tx sent: 0x8d490e535678e9a24360e955d75b27ad307bdfb97a1dca51d0f3035dcee3e870
    receipt, err := bind.WaitMined(context.Background(), client, tx)
    if err != nil {
        fmt.Println(err)
        return false, err
    }
    if (receipt.Status != 1){ // reverted, extract the revert reason
         msg := ethereum.CallMsg{
          		From:     auth.From,
          		To:       tx.To(),
          		Gas:      tx.Gas(),
          		GasPrice: tx.GasPrice(),
          		Value:    tx.Value(),
          		Data:     tx.Data(),
        	}
        	result , err := client.CallContract(context.Background(), msg, receipt.BlockNumber)
          fmt.Printf("Result: %+v\n %+v\n", result, err)
  		    return false, err
    } else {
      fmt.Println("TRANSACTION MINED AND PROCESSED OK")
    }
    return true, nil

}
