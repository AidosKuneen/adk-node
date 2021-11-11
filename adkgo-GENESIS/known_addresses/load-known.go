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
    "log"
    "bufio"
    "github.com/AidosKuneen/gadk"
)

type AddressValue struct {
    Address   string `json:"Address"`
    Value   string `json:"Value"`
}

type RichList struct {
    CreatedOn string `json:"CreatedOn"`
    UpdatingEvery  string `json:"UpdatingEvery"`
    Lists  []AddressValue `json:"Lists"`
    Total   float64 `json:"Total"`
}

func main() {

   file, err := os.Open("known_addresses_at_genesis.txt")
   if err != nil {
       log.Fatal(err)
   }
   defer file.Close()

   scanner := bufio.NewScanner(file)
   //dummy transaction
   var trs9 string;
   trs9 =   "999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999";

   //_, pow := gadk.GetBestPoW()

  var addrs []string
  var trxs []string
  var bundles []string

  cnt := 0
   for scanner.Scan() {
         addrs = append(addrs, scanner.Text()[0:81])

  		   dummyTransaction := trs9[:2187]+scanner.Text()+trs9[2268:2349]+"MIGRATED"+scanner.Text()[8:]+trs9[2349+81:]
  		   fmt.Println(scanner.Text(), len(dummyTransaction))
         cnt++
         trytes2,err2:=gadk.ToTrytes(dummyTransaction)
         if err2 != nil {
    		   log.Fatal(err2)
    	   }
         //transaction
         tx,err3:=gadk.NewTransaction(trytes2)

         bundleHash := GetBundleHash(*tx) // calculate bundle hash
         tx.Bundle = bundleHash

         if err3 != nil {
          log.Fatal(err3)
        }
        trxs = append(trxs,(string(tx.Hash()))[0:81])
        bundles = append( bundles, (string(tx.Bundle)))
        //}
         fmt.Println("Transaction",cnt, tx.Hash())
  	   }

	   if err := scanner.Err(); err != nil {
		   log.Fatal(err)
	   }

     fmt.Print("writing to file template.txt")

     f, err5 := os.OpenFile("template.txt", os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0755)
     if err5 != nil {
             log.Fatal(err5)
     }
     defer f.Close()

    if (len(addrs) != len(trxs) || len(addrs) != len(bundles) ){
        log.Fatal("len missmatch")
    }

     //fmt.Fprintf(f, "%d", len(b))
     fmt.Fprintf(f, "package main\n\n")
     fmt.Fprintf(f, "var knownAddressesStr string = `\n")
     for _, line := range addrs {
       fmt.Fprintf(f, line)
       fmt.Fprintf(f, "\n")
     }
     fmt.Fprintf(f, "`")
     fmt.Fprintf(f, "\n")
     fmt.Fprintf(f, "\n")
     fmt.Fprintf(f, "var knownAddressesTransactions string = `\n")
     for _, line2 := range trxs {
       fmt.Fprintf(f, line2)
       fmt.Fprintf(f, "\n")
     }
     fmt.Fprintf(f, "`")
     fmt.Fprintf(f, "\n")

     fmt.Fprintf(f, "var knownBundleStr string = `\n")
     for _, line3 := range bundles {
       fmt.Fprintf(f, line3)
       fmt.Fprintf(f, "\n")
     }
     fmt.Fprintf(f, "`")
     fmt.Fprintf(f, "\n")
     fmt.Fprintf(f, "\n")

     fmt.Print("completed")
}

func GetBundleHash(b gadk.Transaction) gadk.Trytes {
	c := gadk.NewCurl()
	buf := make(gadk.Trits, 243+81*3)

		copy(buf, gadk.Trytes(b.Address).Trits())
		copy(buf[243:], gadk.Int2Trits(b.Value, 81))
		copy(buf[243+81:], b.Tag.Trits())
		copy(buf[243+81+81:], gadk.Int2Trits(b.Timestamp.Unix(), 27))
		copy(buf[243+81+81+27:], gadk.Int2Trits(int64(0), 27))            //CurrentIndex
		copy(buf[243+81+81+27+27:], gadk.Int2Trits(int64(0), 27)) //LastIndex
		c.Absorb(buf.Trytes())

	return c.Squeeze()
}
