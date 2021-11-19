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
    "os"
    "encoding/json"
	"time"
    "log"
//    "strings"
    "io/ioutil"
    "math/big"
//    "regexp"
    "flag"
    //"math"
    "github.com/aidoskuneen/adk-node/ethclient"
    "github.com/aidoskuneen/adk-node/accounts/keystore"
    "strconv"
)

type RichList1 struct {
    Addresses []string `json:"addresses"`
    Balances []string `json:"balances"`
    Milestone  string `json:"milestone"`
    MilestoneIndex   int64  `json:"milestoneIndex"`
    Duration   int64  `json:"duration"`
}

// IntPow calculates n to the mth power. Since the result is an int, it is assumed that m is a positive power
func IntPow(n, m int64) int64 {
    if m == 0 {
        return 1
    }
    result := n
    var i int64
    for i = 2; i <= m; i++ {
        result *= n
    }
    return result
}

const defaultMilestone = "999999999999999999999999999999999999999999999999999999999999999999999999999999999"

var nodeClient *ethclient.Client
var nodeLink *string //"http://localhost:8545"
var apiServe *string //":14266"
var ADKTransactionContract *string; // 0x****
var key *keystore.Key;

func main() {

  //initialize

  v_pwd := flag.String("password", "12345678", "specify the password for the key file genesis_account.json")
  v_genesis_filename := flag.String("genesis-file", "genesis_richlist.json", "specify the snapshot json to load ('richlist')")
  v_genesis_account := flag.String("genesis-account", "genesis_account.json", "specify the account")
  nodeLink = flag.String("adk-node", "http://localhost:8545", "specify the connection to the adk-node backend")
  ADKTransactionContract = flag.String("mesh-contract", "0x533e5eE8429FCFdBe907408F38Ef91a77573CfD1", "specify the main mesh contract")

  flag.Parse()

 // LOAD GENESIS SNAPSHOT TO USE

  var richList RichList1

  jsonFile, err := os.Open(*v_genesis_filename)
  if err != nil {
      log.Fatalf("Error opening file: %s", err)
  }
  fmt.Println("Successfully Opened ", v_genesis_filename)
  byteValue, _ := ioutil.ReadAll(jsonFile)

  fmt.Println("Read ", len(byteValue), " bytes")
  stringValue := string(byteValue)
  // surrounding all numbers with "" as we have to avoid float loading/rounding issues, and handle "e" numbers

   if err := json.Unmarshal([]byte(stringValue), &richList); err != nil {
        panic(err)
    }

   defer jsonFile.Close()

   fmt.Println("Checking totals...")
   //
   addressToValueMap := make(map[string]int64)

   for i, addr := range richList.Addresses {
        val, err := strconv.ParseInt(richList.Balances[i], 10, 64)
        if err == nil {
            addressToValueMap[addr] += val
        } else {
          log.Panic("Error parsing balance: ",addr ,richList.Balances[i])
        }
   }
   // check totals -  must contain entire ADK balance
   var total int64
   total = 0

   var addresses_as_array []string

   a_idx := 0
   for _ad , _val := range addressToValueMap {
     addresses_as_array = append(addresses_as_array, _ad)
     total+= _val
	 a_idx++
   }

   if (total != 2500000000000000){
       log.Fatalf("Total is not 2500000000000000 (25000000 ADK). Something's wrong: ",total)
   }
   fmt.Println("Total OK: " + fmt.Sprintf("%v", total))

   //return
   // Now prepare balances, deploy genesis contracts

   jsonFileKEY, err2 := os.Open(*v_genesis_account)
   if err2 != nil {
       log.Fatalf("Error opening file: %s", err2)
   }
   fmt.Println("Successfully Opened genesis_account.json")
   byteValueKEY, _ := ioutil.ReadAll(jsonFileKEY)

   key, err2 = keystore.DecryptKey(byteValueKEY, *v_pwd)
   if err2 != nil {
       log.Fatalf("Error DecryptKey: %s", err2)
   }

   fmt.Println("Connecting to ADKgo node db " + *nodeLink)
   client, err := ethclient.Dial(*nodeLink)
   fmt.Println("Block: " + fmt.Sprintf("%v", GetBlockNumber(client)))

   fmt.Println("Deploying ADK Genesis Contracts ")

   authContract := GetAuthForContract(client);

   vADKTokenAddress, _, c_ADKToken, errC := DeployADKToken(authContract,  client)

    if errC != nil {
      log.Fatalf("Error DeployADKToken: %s", errC)
    }
      vAGSClaimContract, _ := c_ADKToken.AGSClaimContract(nil)
	  vADKTransactionsAddress, _ := c_ADKToken.ADKTransactionsContract(nil)

    for vADKTransactionsAddress.Hex() == "0x0000000000000000000000000000000000000000" || vAGSClaimContract.Hex() == "0x0000000000000000000000000000000000000000" {
	   fmt.Println("waiting for contract to be mined...")
       time.Sleep(5 * time.Second)
       c_ADKToken , _ = NewADKToken(vADKTokenAddress, client)
	   vAGSClaimContract, _ = c_ADKToken.AGSClaimContract(nil)
	   vADKTransactionsAddress, _ = c_ADKToken.ADKTransactionsContract(nil)
	}
     fmt.Println("Deployed ADKToken Contract as "+vADKTokenAddress.Hex())
     fmt.Println("Deployed ADKGAS Contract as "+vAGSClaimContract.Hex())
     fmt.Println("Deployed ADKTransactions Contract as "+vADKTransactionsAddress.Hex())

     fmt.Println("setting genesis balances from mesh snapshot...")

     cADKTransactions , err := NewADKTransactions(vADKTransactionsAddress, client)
	 
	 cAGSContract , err := NewAGSClaim(vAGSClaimContract, client)
	 
     t_opt := GetAuth(client)
     cntAddrs := len(addressToValueMap)

	 idx := 0

	 checkTotal := big.NewInt(0)
	 big_1000000000 := big.NewInt(10)
	 big_1000000000.Exp(big_1000000000,big.NewInt(9),nil)
	
	 for idx < cntAddrs - cntAddrs % 10 { // bulk
		addresses_bulk := ""
		var _vals [10]*big.Int
		var _vals_claim [10]*big.Int
	
		for idx10 := 0; idx10 < 10; idx10++ {
			addresses_bulk += addresses_as_array[idx]
			_vals[idx10] = big.NewInt(addressToValueMap[addresses_as_array[idx]])
			_vals_claim[idx10] = new(big.Int).Mul(_vals[idx10],big_1000000000)  // add 10 zeros to convert to correct AGS, then divide by 10, hecne mul 9 zeros
			fmt.Printf("Bulk Setting (%v/%v): %s %v\n", idx, cntAddrs, addresses_as_array[idx], _vals[idx10])
			checkTotal.Add(checkTotal, _vals[idx10])
			idx++
        }
		_ , errBal := cADKTransactions.ADMLoadADKBalancesBulk(t_opt, addresses_bulk, _vals[0], _vals[1], _vals[2], _vals[3], _vals[4], _vals[5], _vals[6], _vals[7], _vals[8], _vals[9] )
		if errBal != nil {
			log.Fatalf("Error Setting Balance: %s", errBal)
		}
		t_opt.Nonce.Add(t_opt.Nonce,big.NewInt(1))

		// AGS
		_ , errBal2 := cAGSContract.ADMSetClaimableAmountBulk(t_opt, addresses_bulk, _vals_claim[0], _vals_claim[1], _vals_claim[2], _vals_claim[3], _vals_claim[4], _vals_claim[5], _vals_claim[6], _vals_claim[7], _vals_claim[8], _vals_claim[9] )
		if errBal2 != nil {
			log.Fatalf("Error Setting AGS Claim Balance: %s", errBal2)
		}
		t_opt.Nonce.Add(t_opt.Nonce,big.NewInt(1))
	 }

	 for idx < cntAddrs  { // remaining non-bulk
	    _bigIntVal := big.NewInt(addressToValueMap[addresses_as_array[idx]])
		_bigIntValClaim := new(big.Int).Mul( _bigIntVal, big_1000000000)  // add 10 zeros to convert to correct AGS, then divide by 10, hecne mul 9 zeros
			
		fmt.Printf("Setting (%v/%v): %s %v\n", idx, cntAddrs, addresses_as_array[idx], _bigIntVal)
		checkTotal.Add(checkTotal, _bigIntVal)
		_ , errBal := cADKTransactions.ADMLoadADKBalances(t_opt, addresses_as_array[idx], _bigIntVal)
		if errBal != nil {
			log.Fatalf("Error Setting Balance: %s", errBal)
		}
		t_opt.Nonce.Add(t_opt.Nonce,big.NewInt(1))
		
		// AGS 
		fmt.Printf("Setting AGS: %v\n", _bigIntValClaim)
		_ , errBal2 := cAGSContract.ADMSetClaimableAmount(t_opt, addresses_as_array[idx], _bigIntValClaim)
		if errBal2 != nil {
			log.Fatalf("Error Setting AGS Balance: %s", errBal2)
		}
		t_opt.Nonce.Add(t_opt.Nonce,big.NewInt(1))
		
		idx++
		
	 }

	 fmt.Print ("Balances loaded:",checkTotal)

     fmt.Print("completed")
}
