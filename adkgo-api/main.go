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
    "net"
    "time"
    "strconv"
    "flag"
    "log"
	"os"
	"github.com/AidosKuneen/gadk"
    "io/ioutil"
    "net/http"
    "runtime"
    "encoding/json"
    "github.com/aidoskuneen/adk-node/ethclient"
)


func errorResponse( e string) ([]byte, int){
  response := &ResponseError{Error: e, Duration: 0}
  ret, _ := json.Marshal(response)
  return ret, 400
}

func removeDuplicateStr(strSlice []string) []string {
    allKeys := make(map[string]bool)
    list := []string{}
    for _, item := range strSlice {
        if _, value := allKeys[item]; !value {
            allKeys[item] = true
            list = append(list, item)
        }
    }
    return list
}

func makeTimestamp() int64 {
    return time.Now().UnixNano() / int64(time.Millisecond)
}
func getTimeDiff(ts int64) (int64){
    return makeTimestamp() - ts
}
const defaultMilestone = "999999999999999999999999999999999999999999999999999999999999999999999999999999999"

func processRequest(w http.ResponseWriter, r *http.Request){
  ts := makeTimestamp()
  
  debugLog := false
  if _, errLL := os.Stat("log.enable"); errLL == nil {
     // path/to/whatever exists
	 debugLog = true
  }
  
  w.Header().Set("Content-Type", "application/json; charset=utf-8")
  w.Header().Set("Access-Control-Allow-Origin", "*")
  w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
  jsonBody, _ := ioutil.ReadAll(r.Body)
  if (debugLog) {
     fmt.Println("Request:" + string(jsonBody))
  }
  var ret []byte;
  var result map[string]interface{}

  code := 200 // default
  json.Unmarshal([]byte(jsonBody), &result)

  if (result["command"] != nil){
      command := result["command"].(string);
	  if (!debugLog) {
		 fmt.Println("Request:" + command)
	  }
      switch command {
        case "ping":{
          ip, _, _ := net.SplitHostPort(r.RemoteAddr)
          response := &ResponsePing{IP: ip, Duration: getTimeDiff(ts)}
          ret, _ = json.Marshal(response)
        }
        case "addPeer":{ // obsolete
          response := &ResponseAddPeer{AddedPeer: 0, Duration: getTimeDiff(ts)}
          ret, _ = json.Marshal(response)
        }
        case "getPeerAddresses":{ // obsolete
          response := &ResponseGetPeerAddresses{ Peerlist: []string{},  Duration: getTimeDiff(ts)}
          ret, _ = json.Marshal(response)
        }
        case "attachToMesh":{  // not implemented, client needs to do POW
          ret, code = errorResponse("attachToMesh not available on node, please do your own POW ;)");
        }
        case "interruptAttachingToMesh":{ // obsolete
          response := &ResponseDurationOnly{Duration: getTimeDiff(ts)}
          ret, _ = json.Marshal(response)
        }
        case "findTransactions":{
          hashes := []string{}

          if (result["bundles"] != nil){
            bundles := result["bundles"].([]interface{})
            hashes = FindTransactionsByBundles(nodeClient, bundles)

            for _ , bund := range bundles { //now check if this is a known address
                bund_s := bund.(string)[0:81]
                if IsKnownBundle(bund_s){ // is a known address from v1, so lets add a dummy transaction
                    hashes=append(hashes, getTransactionHashForBundle(bund_s))
                }
            }

            hashes = removeDuplicateStr(hashes)

          } else if (result["addresses"] != nil){
            addresses := result["addresses"].([]interface{})
            hashes = FindTransactionsByAddresses(nodeClient, addresses)

             for _ , addr := range addresses { //now check if this is a known address
                 addr_s := addr.(string)[0:81]
                 if IsKnownAddress(addr_s){ // is a known address from v1, so lets add a dummy transaction
                     hashes=append(hashes, getTransactionHashForAddress(addr_s))
                 }
             }
             hashes = removeDuplicateStr(hashes)

          } else if (result["approvees"] != nil){// obsolete, not implemented
          } else if (result["tags"] != nil){ // obsolete, not implemented
          } else {
              ret, code = errorResponse("missing search key");
          }
          //
          if (code == 200){ // no error
            response := &ResponseFindTransactions{Hashes: hashes, Duration: getTimeDiff(ts)}
            ret, _ = json.Marshal(response)
          }

        }
        case "getBalances":{
          balances := []string{}
          if (result["addresses"] != nil){
            addresses := result["addresses"].([]interface{})
            for _ , value := range addresses {
              //
	      address := value.(string)[0:81]
              bal := GetBalance(nodeClient, address)
              balances = append(balances,strconv.FormatInt(bal, 10));
            }
            blockMilestone := int(GetBlockNumber(nodeClient));
            response := &ResponseGetBalances{Balances: balances, Milestone: defaultMilestone,  MilestoneIndex:blockMilestone, Duration: getTimeDiff(ts)}
            ret, _ = json.Marshal(response)
          } else {
              ret, code = errorResponse("missing addresses key");
          }

        }
        case "getInclusionStates":{ // does transaction exist/is approved? k
          states := []bool{}
          if (result["transactions"] != nil && result["tips"] != nil){ // can ignore tips
            transactions := result["transactions"].([]interface{})
            for _ , value := range transactions {

              transaction := value.(string)
              _state := IsKnownTransaction(transaction) || HashExists(nodeClient,transaction)
              states = append(states, _state);
            }
            response := &ResponseGetInclusionStates{States: states, Duration: getTimeDiff(ts)}
            ret, _ = json.Marshal(response)

          } else {
              ret, code = errorResponse("missing transactions or tips keys");
          }
        }
        case "getNodeInfo":{
          latestBlockNo := GetBlockNumber(nodeClient)
          tipMilestone := GetTip(nodeClient)
          response := &ResponseGetNodeInfo{
              AppName: "ADKgo",
              AppVersion: "2.0.0.0",
              JreAvailableProcessors: 1,
              JreFreeMemory: 99999999,
              JreVersion: runtime.Version(),
              JreMaxMemory: 999999999,
              JreTotalMemory: 999999999,
              LatestMilestone: tipMilestone,
              LatestMilestoneIndex: latestBlockNo,
              LatestSolidSubmeshMilestone: tipMilestone,
              LatestSolidSubmeshMilestoneIndex: latestBlockNo,
              Peers: 1,
              PacketsQueueSize: 0,
              Time: ts,
              Tips: 1,
              TransactionsToRequest: 0,
              Duration: getTimeDiff(ts) }

              ret, _ = json.Marshal(response)

        }
        case "getTips":{
           response := &ResponseGetTips{Hashes: []string{GetTip(nodeClient)}, Duration: getTimeDiff(ts)}
           ret, _ = json.Marshal(response)
        }
        case "getTransactionsToApprove":{
          response := &ResponseGetTransactionsToApprove{
                      TrunkTransaction: GetTip(nodeClient),
                      BranchTransaction: GetTip(nodeClient),
                      Duration: getTimeDiff(ts)}
          ret, _ = json.Marshal(response)
        }
        case "getTrytes":{
          trytes := []string{}

          if (result["hashes"] != nil){
            hashes := result["hashes"].([]interface{})

            trytes  = GetTrytes(nodeClient, hashes)

            // check if any trx is a v1 hash
            for _, hsh := range hashes {
              if IsKnownTransaction(hsh.(string)){ // is a known address from v1, so lets add a dummy transaction
                  trytes=append(trytes, getTransactionForTrxHash(hsh.(string)))
              }
            }

            response := &ResponseGetTrytes{Trytes: trytes, Duration: getTimeDiff(ts)}
            ret, _ = json.Marshal(response)

          } else {
              ret, code = errorResponse("missing transaction hashes");
          }
        }
		case "broadcastTransactions":  // obsolete, is now automatic //- ACTUALLY NO, aidosd (the old one uses this to store implicitly...
          fallthrough
        //
        case "storeTransactions":{
          if (result["trytes"] != nil){
            trytes := result["trytes"].([]interface{})
            transactionTrytes := ""
            for _ , value := range trytes { // concatenate
              transactionTrytes = transactionTrytes + value.(string)
            }
			seen := false
			if len(trytes) >= 1 {
				hashTransaction1, errT := gadk.ToTrytes(trytes[0].(string))
				if (errT != nil){
				   //ignore and let the contract deal with it
				} else {				
					seen = HashExists(nodeClient, string(hashTransaction1.Hash()))
					fmt.Println("Transactions already seen")
				}
			}
			if seen { // we have done this one already...
				response := &ResponseDurationOnly{Duration: getTimeDiff(ts)}
				ret, _ = json.Marshal(response)
			} else {
				_ , err := SendTransactions(nodeClient,transactionTrytes)
				if (err != nil){
				   ret, code = errorResponse(err.Error());
				} else {
					response := &ResponseDurationOnly{Duration: getTimeDiff(ts)}
					ret, _ = json.Marshal(response)
				}
			}
          }else {
              ret, code = errorResponse("missing transactions or tips keys");
          }
        }
        default:{
            ret, code = errorResponse("unknown command");
        }
      }

    } else {
          ret, code = errorResponse("missing command or invalid json");
    }

	if (debugLog) {
		  fmt.Println("Response:" + string(ret))
    } else 
	{
	  fmt.Println("Response sent:", code)
    }
    w.WriteHeader(code)
    w.Write(ret)
}

func setupAPIHandler() *http.Server {
	
    fmt.Println("Setting up API Handler")

	srv := &http.Server{Addr: *apiServe}

    http.HandleFunc("/", processRequest)
    go func() {
		err := srv.ListenAndServe()
        if err != http.ErrServerClosed { // not closed on purpose?
            // unexpected error. port in use?
            log.Fatalf("ListenAndServe(): %v", err)
        }
    }()

    // returning reference so caller can call Shutdown()
    return srv
}

func setupNodeLink()(*ethclient.Client) {
    fmt.Println("Connecting to ADKgo node db " + *nodeLink)
    var err error
    nodeClient, err = ethclient.Dial(*nodeLink)
    if err != nil {
      log.Fatal(err)
    }
    fmt.Println("connected: LatestMilestoneIndex " + strconv.FormatInt(GetBlockNumber(nodeClient),10))
    return nodeClient
}

var nodeClient *ethclient.Client
var nodeLink *string //"http://localhost:8545"
var apiServe *string //":14266"
var ADKTransactionContract *string; // 0x****
var mainAPIServer *http.Server;

func main() {
  vRestarts = 0
	nodeLink = flag.String("adk-node", "http://localhost:8545", "specify the connection to the adk-node backend")
	apiServe = flag.String("wallet-api-port", ":14266", "specify the listening port for the ADK JSON Wallet API")
	ADKTransactionContract = flag.String("mesh-contract", "0x533e5eE8429FCFdBe907408F38Ef91a77573CfD1", "specify the main mesh contract")
	flag.Parse()

  initAddrs() // init known address lookup

  mainAPIServer = setupAPIHandler()

	start()
}

var vRestarts int

func start(){
	defer func() { // prepare error recoveries
      if r := recover(); r != nil { // we had a panic, try to reconnect
		  vRestarts++
		  fmt.Println("Caught panic (#"+strconv.Itoa(vRestarts)+"). Is Node RPC at "+*nodeLink+" available? restarting in 5s...")
		  log.Println(r.(error))
		  time.Sleep(5 * time.Second)
          fmt.Println("recovering...")
		  start() // restart
      }
    }()

	fmt.Println("adk-node: " + *nodeLink)
	fmt.Println("apiServe: " + *apiServe)
	fmt.Println("ADKTransactionContract: " + *ADKTransactionContract)

	nodeClient = setupNodeLink()

	for {
        	fmt.Println("API Active")
	        time.Sleep(500 * time.Second)
    	}
}
