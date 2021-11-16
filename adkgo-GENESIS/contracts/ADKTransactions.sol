// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.8.4;

// ADKTransactions Contract for ADKGO - requires CURL Extended Version of EVM/AVM
//import "contracts/AGSClaim.sol";

interface ADKTokenInterface {
    function AZ9balanceOf(string memory _adkAddr) external view returns (uint256 balance);
    function meshTransaction(string memory _meshaddr, int256 _value) external;
    function AZ9_TO_ADDR (string memory adkString) external pure returns(address);
}

// Implementation of the ADK Mesh Structure and Signature Validation Genesis Contract

contract ADKTransactions {

    address public ADKTokenAddress; // Holds the address of the ADK Genesis Contract managing balances
    address public adkgo_genesis_address; // Contract genesis address

    constructor(
            address _genesis_account,
            address _ADKTokenContract
        ){
        // DEPLOY MAIN ADK CONTRACT
        ADKTokenAddress = _ADKTokenContract; // The ADK Token Contract
        adkgo_genesis_address = _genesis_account;
        ClientProofOfWorkRequirement = 15; // PoW effort required (must be multiple of 3)
        createGenesisTransaction();
    }

    // Create the initial genesis transaction, for all "9" address
    bool genesisCreated = false;
    function createGenesisTransaction() internal {
        // BEGIN Create genesis transaction
        require(!genesisCreated);
        genesisCreated = true;
        baseTransactionHash = "999999999999999999999999999999999999999999999999999999999999999999999999999999999";
        bytes memory baseT = new bytes(2673);
        for (uint i = 0; i < 2673; i++)
            baseT[i] = 0x39; // 0x39 = "9"
        baseTransaction = string(baseT); // thats now 2673 "9" = the Genesis transaction
        bytes32 transactionHashSha3 = keccak256(bytes(baseTransactionHash));
        transactions[transactionHashSha3] = baseTransaction;
        transaction_hashes[transactionHashSha3] = baseTransactionHash;
        meshTip = transactionHashSha3;
        transaction_trunk[transactionHashSha3] = transactionHashSha3;
        transaction_branch[transactionHashSha3] = transactionHashSha3;
        tx_count = 0;
        // END Create genesis transaction
    }


    mapping(bytes32 => string) public transactions; // all stored and confirmed transactions, indexed by their keccak hash
    mapping(bytes32 => string) public transaction_hashes; // all stored and confirmed transaction hashes, indexed by their keccak hash

    mapping(bytes32 => bool) public spent_addresses; // store addresses that have been spent from before. Can be used by clients to avoid sending to already used AZ9 addresses

    mapping(bytes32 => bytes32) public transactionhash_by_address; // stores sha3(transactionhash) by sha3(address), increment by 1 for each further transaction
                                                                   // replaces events as this is faster
    mapping(bytes32 => bytes32) public transactionhash_by_bundle;  // stores sha3(transactionhash) by sha3(bundle), increment by 1 for each further transaction
                                                                   // replaces events as this is faster
    mapping(bytes32 => uint32) public transactionhash_by_address_count;
    mapping(bytes32 => uint32) public transactionhash_by_bundle_count;
    
    mapping(uint256 => bytes32) public transaction_indexed_by_seq; // transaction sha3 indexed by their sequence/occurence
    mapping(bytes32 => uint256) public transaction_index; // transaction sha3 indexed by their sequence/occurence (reversed)
    uint256 public tx_count;
    
    // mesh structure
    string baseTransaction; // always all '9'
    string baseTransactionHash; // always all '9'

    mapping(bytes32 => bytes32) public transaction_trunk; // transactions info indexed by their keccak hash: trunk
    mapping(bytes32 => bytes32) public transaction_branch; // transactions info indexed by their keccak hash: branch

    bytes32 public meshTip; // the highest tip in the mesh

    uint256 public ClientProofOfWorkRequirement;

    // mesh indexing
    event transactions_by_bundle(bytes32 indexed bundleSHA3, bytes32 transactionSHA3); // logs transactions per bundle, tighly packed bytes32 keccak hashes of transactions
    event transactions_by_address(bytes32 indexed addressSHA3, bytes32 transactionSHA3); // logs transactions per address, tighly packed bytes32 keccak hashes of transactions

    // testBundleBalances are used to ensure that a transaction bundle does not cause any balances to go negative
    mapping(string => int256) private testBundleBalances; // before and after balance computations these are always 0;
     // testBundleBalances are used to ensure that a transaction bundle does not cause any balances to go negative
    mapping(uint256 => bytes32) private tmpSha3TransactionHashes; // temp array to hold current transaction hashes for structure check;

    // Get AZ9 balance wrapper function, fetches ADK balance from ADK Token Genesis contract
    function GetAZ9balanceOf(string memory _adkAddr) public view returns (uint256 balance){
        return  ADKTokenInterface(ADKTokenAddress).AZ9balanceOf(_adkAddr); // pass through
    }


    // PostTransactions: This is the main entry point used by clients to submit full transaction bundles.
    //                   It requires an entire bundle of a transaction, in the correct sequence, and with PoW completed

    // This function checks for the minimum POW, valid signatures, valid bundle hashes, sufficient balances

    // If all is ok, the transfer is executed as soon as it is mined (PoA/PoS - depending on the stage)

    bool mutex_PostTransactions = false; // mutex to prevent reentry
    function PostTransactions(string memory transactiondata) public mod_requireAZ9(transactiondata) returns(string memory) {

        // Check mutex
        require (!mutex_PostTransactions,"reentry prevented!");
        mutex_PostTransactions = true; // prevent reentry exploits

        bytes memory b_trytes = bytes(transactiondata); // Load transaction AZ9 string into bytes
        require(b_trytes.length % 2673 == 0 && b_trytes.length > 0 ,"Invalid transaction(s) length");
        uint16 cnt_transactions = uint16(b_trytes.length / 2673);  // count number of included individual transactions

        bytes memory all_essential_parts = new bytes(cnt_transactions*162); // each essential is 162 char long, all essentials make the bundle hash

        int totalBundleValue = 0; // has to be 0  (i.e. input and output values have to net 0)
        int lastIndex = -1;         // initialize
        string memory s_bundle = ""; // initialize
        // process each transaction one by one
        for (uint32 transaction_idx = 0; transaction_idx < cnt_transactions; transaction_idx++){

            TransactionInfoStruct memory tinfo; // will hold all key transaction data (also used to avoid stack errors due to too many variables)
            tinfo.offset = transaction_idx * 2673; // offset of each transaction in the entire string

            tinfo.data = substring(transactiondata,tinfo.offset , tinfo.offset + 2673); // extract the current transaction
            tinfo.trans_hash = bytes(CurlHashOP(tinfo.data));  // Call the Hash Operation in order to get the transaction hash

            // Validate PoW
            // force the last X digits to be 0 (client POW); //

            for ( uint checkIdx = 0; checkIdx < ClientProofOfWorkRequirement/3; checkIdx ++ ){
                uint byte_index = 80 - checkIdx;  // 80,79,78,.. integer division to get byte position to check
                                                      // note we only check full bytes, not by trits. So difficulty can be e.g. ... , 9, 12, 15, 18, 21 ...
                require(tinfo.trans_hash[byte_index] == 0x39, // 0x39 = "9",
                        "TRANSACTION POW NOT COMPLETED"
                        );
            }

            // Transaction Hash Handling
            tinfo.transactionSHA3 = keccak256(tinfo.trans_hash); // get keccak hash of transaction hash for indexing
            require(bytes(transactions[tinfo.transactionSHA3]).length == 0 ,"TRANSACTION ALREADY PROCESSED");
            transactions[tinfo.transactionSHA3] = string(tinfo.data); // store transaction
            transaction_hashes[tinfo.transactionSHA3] = string(tinfo.trans_hash); // store transaction Hash
            tx_count++;
            transaction_indexed_by_seq[tx_count] = tinfo.transactionSHA3;
            transaction_index[tinfo.transactionSHA3] = tx_count;

             // Trunk + Branch Handling
            // Build mesh structure: trunk and branch, just store for now, check later
            transaction_trunk[tinfo.transactionSHA3] = keccak256(subbytes(b_trytes,uint32(tinfo.offset+2430),uint32(tinfo.offset+2430+81)));
            transaction_branch[tinfo.transactionSHA3] = keccak256(subbytes(b_trytes,uint32(tinfo.offset+2511),uint32(tinfo.offset+2511+81)));

            tmpSha3TransactionHashes[transaction_idx] = tinfo.transactionSHA3; // store for later consistency check

            // record highest mesh tip
            if (transaction_idx ==0) {
                meshTip = tinfo.transactionSHA3; // becomes highest mesh tip
            }

            // Bundle Hash: recurd current transaction essential parts for later bundle hash generation

            for (uint16 idx = 0; idx < 162; idx++){ // get essential parts for bunlde hash calculation
                all_essential_parts[(transaction_idx*162) + idx] = b_trytes[tinfo.offset + 2187 + idx];
            }

            // Transaction Address Value Handling

            tinfo.s_address = substring(tinfo.data,2187,2268); // get current transaction address
            testBundleBalances[tinfo.s_address] = 0; // set ot 0 for now, we will use this later to check sufficient balance availability

            // Cummulative bundle value calculation up to current transaction (must be 0 after all transactions loaded, i.e. input total = output total)
            tinfo.transactionValue = TryteToIntValue(subbytes(b_trytes,tinfo.offset+2268,tinfo.offset+2279));
            totalBundleValue += tinfo.transactionValue;

            // just some additional checks, can never be too careful
            require(tinfo.transactionValue >= -2500000000000000,"transaction value too low");
            require(tinfo.transactionValue <= 2500000000000000,"transaction value too high");
            require(totalBundleValue >= -2500000000000000,"bundle cummulative transaction value too low");
            require(totalBundleValue <= 2500000000000000,"bundle cummulative transaction value too high");

            // Validate transaction index - current and total index (ensure transaction is in correct sequence)

            // check transaction indices
            tinfo.b_lastIndex = subbytes(b_trytes,tinfo.offset+2340,tinfo.offset+2349);
            tinfo.b_bundle = subbytes(b_trytes,tinfo.offset+2349,tinfo.offset+2349+81);

            if (transaction_idx==0){
                s_bundle = string(tinfo.b_bundle);
                lastIndex = TryteToIntValue(tinfo.b_lastIndex);
            }
            else {
                require(TryteToIntValue(tinfo.b_lastIndex) == lastIndex,"lastIndex not consistent"); // last index has to be the same across all transactions
                require(compareStrings(s_bundle, string(tinfo.b_bundle)),"bundle not consistent"); // bundle has to be the same across all transactions
            }

            tinfo.b_currentIndex = subbytes(b_trytes,tinfo.offset+2331,tinfo.offset+2340);
            tinfo.currentIndex = TryteToIntValue(tinfo.b_currentIndex);

            require(transaction_idx == uint(tinfo.currentIndex), "transaction sequence invalid"); // transaction number has to match index

            if (transaction_idx == cnt_transactions - 1){
                require(transaction_idx == uint(lastIndex), "last transaction != lastIndex"); // transaction number has to match lastIndex for last transaction
            }

            // SIGNATURE VALIDATIONS FOR SPENDING TRANSACTIONS ///////////////////////
            // Check signature for spending transactions

            if (tinfo.transactionValue < 0){ // only need to check signatures for spending transactions

                // Note: adkgo requires Signature Level 2, meaning the signature is spread across 2 transactions

                // the last transaction can't be a spending transaction, as each spending transaction has one more 0 value signature transaction
                require (transaction_idx < uint(lastIndex),"missing 2nd signature"); // there must be at least one more transaction

                tinfo.sig2_address = substring(transactiondata,tinfo.offset+2673+2187,tinfo.offset+2673+2268);
                tinfo.sig2_value = TryteToIntValue(subbytes(b_trytes,tinfo.offset+2673+2268,tinfo.offset+2673+2279));

                require (compareStrings(tinfo.s_address, tinfo.sig2_address),"2nd signature has invalid address"); // there must be at least one more transaction
                require (tinfo.sig2_value==0,"2nd signature is not 0 value");

                tinfo.sigA = substring(transactiondata,tinfo.offset+0,tinfo.offset+2187);
                tinfo.sigB = substring(transactiondata,tinfo.offset+2673,tinfo.offset+2673+2187);

                // Validate Signature
                require( CurlValidateSignature(tinfo.s_address,
                                              concat(tinfo.sigA,tinfo.sigB),
                                               s_bundle),
                                               "INVALID SIGNATURE");
                //
                spent_addresses[keccak256(bytes(tinfo.sig2_address))] = true;
            }

            emit EventLogInt(tinfo.s_address, tinfo.transactionValue);

            //log for faster retrieval later, also used by "find_transactions"
            bytes32 bundleSHA3 = keccak256(tinfo.b_bundle);
            bytes32 addressSHA3 = keccak256(bytes(tinfo.s_address));

            emit transactions_by_bundle(bundleSHA3, tinfo.transactionSHA3); // logs transactions per bundle, tighly packed bytes32 keccak hashes of transactions
            emit transactions_by_address(addressSHA3, tinfo.transactionSHA3); // logs transactions per address, tighly packed bytes32 keccak hashes of transactions

            // we also log in contract data, not just events, as that is faster for retrieval, and allows fast sync. Cost more storage though,
            // but you know... the things we accept for better performance...
            StoreTransactionsByAddress(addressSHA3, tinfo.transactionSHA3);
            StoreTransactionsByBundle(bundleSHA3, tinfo.transactionSHA3);


        } // END LOOP THROUGH ALL TRANSACTIONS

        // perform further overall checks:

        // Check trunk/branch strucutre solid
        // process each transaction hash we have seen in the bundle
        for (uint32 transaction_idx = 0; transaction_idx < cnt_transactions; transaction_idx++){
            TransactionInfoStruct memory tcheck;
            tcheck.transactionSHA3 = tmpSha3TransactionHashes[transaction_idx] ;
            tcheck.transactionTrunkSHA3 = transaction_trunk[tcheck.transactionSHA3];
            tcheck.transactionBranchSHA3 = transaction_branch[tcheck.transactionSHA3];
            require(bytes(transactions[tcheck.transactionTrunkSHA3]).length != 0 ,"TRUNK TRANSACTION DOES NOT EXIST");
            require(bytes(transactions[tcheck.transactionBranchSHA3]).length != 0 ,"BRANCH TRANSACTION DOES NOT EXIST");
        }

        assert(totalBundleValue==0); // totalBundleValue must be 0 across the bundle;

        // compute and check BUNDLE HASH: calculated bundle hash must match the actual bundle trytes stored in each transaction

        string memory s_hash = CurlHashOP(string(all_essential_parts));
        require (compareStrings(s_bundle,s_hash),"CALCULATED BUNDLE DIFFERS");

        // if we are here, the bundle itself is valid. Now we have to check if there are enough balances available on the spending addresses
        ValidateBalancesAndTransact(transactiondata);

        // AND NOW, as the final step, we call ADKTransactionNotify on each receiving Contract

        // Note: this is done last, to prevent reentry hacks, and we use CALL so we dont revert if the
        // target is not a contract: The low-level functions call, delegatecall and staticcall return true as their first return value if the account called is non-existent, as part of the design of the EVM.

        // note the GAS is limited here to  10000 gas to prevent spam

        for (uint32 transaction_idx = 0; transaction_idx < cnt_transactions; transaction_idx++){
            TransactionInfoStruct memory tinfo2;
            tinfo2.offset = transaction_idx * 2673;
            tinfo2.transactionValue = TryteToIntValue(subbytes(b_trytes,tinfo2.offset+2268,tinfo2.offset+2279));
            if (tinfo2.transactionValue > 0){// only call for positive transactions
                tinfo2.s_address = substring(transactiondata,tinfo2.offset+2187,tinfo2.offset+2268);
                tinfo2.sigA = substring(transactiondata,tinfo2.offset+0,tinfo2.offset+2187);

                // the following calls the receiveing contract notification function (if it exists)
                address _addr = ADKTokenInterface(ADKTokenAddress).AZ9_TO_ADDR(tinfo2.s_address); // get the target address
                (bool success, bytes memory data) = _addr.call{value: 0, gas: 10000 }(
                        abi.encodeWithSignature("ADKMeshTransactionNotify(string,int256)", tinfo2.sigA, tinfo2.transactionValue)
                );
                require (success, "CALLED CONTRACT (ADKTransactionNotify) REVERTED.");
            }
        }

        mutex_PostTransactions = false; // end reentry check
        return s_hash; // bundle hash
    }
    //
    // ValidateBalancesAndTransact - internal function that checks balances (sufficient balance) and performs the actual transfer
    //
    bool mutex2 = false;
    function ValidateBalancesAndTransact(string memory transactiondata) internal returns (bool){

        require (!mutex2, "mutex check failed on ValidateBalancesAndTransact");
        mutex2 = true;

        //check transaction data once again, and then loop through all transactions.
        // NOTE: at this point all signatures have already been validated.

        bytes memory b_trytes = bytes(transactiondata);
        require(b_trytes.length % 2673 == 0 && b_trytes.length > 0 ,"Invalid transaction(s) length");
        uint16 cnt_transactions = uint16(b_trytes.length / 2673);

        int total = 0;

        // first calculate totals per address (in case the same address appears more than once in the bundle)
        for (uint32 transaction_idx = 0; transaction_idx < cnt_transactions; transaction_idx++){ // loop through all transactions once
            uint32 offset = transaction_idx * 2673; // offset of current transaction
            string memory s_address = substring(transactiondata,uint32(offset+2187),uint32(offset+2268));
            int value = TryteToIntValue(subbytes(b_trytes,offset+2268,offset+2279));
            total += value;
            testBundleBalances[s_address] += value; // store it as temporary virtual balance (this entry was set to 0 initially in PostTransactions() )
        }
        assert(total==0); // we did that before already, but doesnt hurt to check again...

        // now check if actual current TOTAL balance for each SPENDING address is sufficient
        for (uint32 transaction_idx2 = 0; transaction_idx2 < cnt_transactions; transaction_idx2++){ // loop through all transactions once again, but know we know each address' final total aready
            uint32 offset = transaction_idx2 * 2673; // offset of current transaction
            string memory s_address = substring(transactiondata,uint32(offset+2187),uint32(offset+2268));

            int availableBalance = int(GetAZ9balanceOf(s_address)); // get this from current ADK balance

            // after the bundle values are applied on each address, the new balance must be >= 0
            require(availableBalance + testBundleBalances[s_address] >= 0, "INSUFFICIENT BALANCE");

            // PERFORM VALUE TRANSACTION. Note: ADKTokenContract.meshTransaction can only be called by this Transfer Contract
            if (testBundleBalances[s_address]!= 0){ // transaction is positive or negative, thus will update the address balance
                ADKTokenInterface(ADKTokenAddress).meshTransaction(s_address, testBundleBalances[s_address]);
            }

            testBundleBalances[s_address] = 0; //  reset to 0 now as we have done the TRANSACTION
        }
        mutex2 = false; // end reentry check
        return true;

    }

     //
    //  Stores transaction hases by address, but depending on the number of tx we increment the SHA hash
    //
    function StoreTransactionsByAddress(bytes32 addressSHA3, bytes32 transactionSHA3) internal {
        uint32 cntAddrTx = transactionhash_by_address_count[addressSHA3];
        bytes32 addressSHA3_incl_cnt = bytes32(uint256(addressSHA3)+cntAddrTx);
        transactionhash_by_address[addressSHA3_incl_cnt] = transactionSHA3;
        cntAddrTx++;
        transactionhash_by_address_count[addressSHA3] = cntAddrTx;
    }
    //
    //  Stores transaction hases by address, but depending on the number of tx we increment the SHA hash
    //
    function StoreTransactionsByBundle(bytes32 bundleSHA3, bytes32 transactionSHA3) internal {
        uint32 cntBundleTx = transactionhash_by_bundle_count[bundleSHA3];
        bytes32 bundleSHA3_incl_cnt = bytes32(uint256(bundleSHA3)+cntBundleTx);
        transactionhash_by_bundle[bundleSHA3_incl_cnt] = transactionSHA3;
        cntBundleTx++;
        transactionhash_by_bundle_count[bundleSHA3] = cntBundleTx;
    }
    //
    // helper function view GetTxByAddress
    function GetTxByAddress(string memory addressString, uint256 numTx) public view returns (string memory) {
        bytes32 addr_b = keccak256(bytes(addressString));
        addr_b = bytes32(uint256(addr_b)+numTx);
        bytes32 txHash = transactionhash_by_address[addr_b];
        if (txHash == 0x000000000000000000000000000000000000000000000000) return "";
        return transaction_hashes[txHash];
    }

    //
    // helper function view GetTxByAddress
    function GetTxByBundle(string memory bundleString, uint256 numTx) public view returns (string memory) {
        bytes32 bundle_b = keccak256(bytes(bundleString));
        bundle_b = bytes32(uint256(bundle_b)+numTx);
        bytes32 txHash = transactionhash_by_bundle[bundle_b];
        if (txHash == 0x000000000000000000000000000000000000000000000000) return "";
        return transaction_hashes[txHash];
    }

    // Transaction Struct, mainly used to avoid stack issues
    struct TransactionInfoStruct {
          string s_address;
          string data; // transaction data
          int transactionValue;
          string sig2_address;
          int sig2_value;
          string sigA;
          string sigB;
          bytes b_lastIndex;
          bytes b_bundle;
          bytes b_currentIndex;
          int currentIndex;
          uint32 offset;
          bytes32 transactionSHA3; // KECCAK hash of transactionSHA3
          bytes trans_hash; // CURL hash of transaction
          bytes32 transactionTrunkSHA3;
          bytes32 transactionBranchSHA3;
    }


    // HELPER FUNCTIONS

    // Allows for upgrade of the ADK Token Contract while in Genesis Mode
    function ADM_SetADKTokenContract (address _newContract) public onlyGenesis {
        ADKTokenAddress = _newContract;
    }

    // Allows for upgrade of the ADK Genesis Address
    // and will be used to force-lock the contract by setting to 0x00000000[..] so no further updates are possible
    function ADM_SetGenesisAddress (address _genesisAddress) public onlyGenesis {
        adkgo_genesis_address = _genesisAddress;
    }

    // Allows Tip adjustment while in Genesis Mode
    function ADM_SetTip (bytes32 _newTip) public onlyGenesis {
          meshTip = _newTip;
    }

    // Allows Difficulty adjustment while in Genesis Mode
    function ADM_SetDifficulty (uint256 _ClientProofOfWorkRequirement) public onlyGenesis {
          ClientProofOfWorkRequirement = _ClientProofOfWorkRequirement;
    }

    // Allows data migration from old ADK node while in Genesis Mode
    function ADM_LoadTransactionsUnchecked (string memory _transaction) public mod_requireAZ9(_transaction) onlyGenesis {
        bytes memory b_trytes = bytes(_transaction);
        require(bytes(_transaction).length == 2673,"INVALID TRANSACTION LENGTH");
        TransactionInfoStruct memory tinfo;
        tinfo.data = _transaction;
		tinfo.trans_hash = bytes(CurlHashOP(tinfo.data));  // Call the Hash Operation in order to get the transaction hash
        tinfo.transactionSHA3 = keccak256(tinfo.trans_hash);
        transactions[tinfo.transactionSHA3] = string(tinfo.data); // store transaction
        transaction_hashes[tinfo.transactionSHA3] = string(tinfo.trans_hash); // store transaction hash

        tinfo.transactionTrunkSHA3 = keccak256(subbytes(b_trytes,uint32(2430),uint32(2430+81)));
        tinfo.transactionBranchSHA3 = keccak256(subbytes(b_trytes,uint32(2511),uint32(2511+81)));

        // store trunk and branch
        transaction_trunk[tinfo.transactionSHA3] = tinfo.transactionTrunkSHA3;
        transaction_branch[tinfo.transactionSHA3] = tinfo.transactionBranchSHA3;

        tinfo.s_address = substring(tinfo.data,2187,2268);
        tinfo.b_bundle = subbytes(b_trytes,2349,2349+81);

        //log for faster retrieval later
        bytes32 addrSHA3 = keccak256(bytes(tinfo.s_address));
        bytes32 bundSHA3 = keccak256(bytes(tinfo.b_bundle));

        emit transactions_by_bundle(bundSHA3, tinfo.transactionSHA3); // logs transactions per bundle, tighly packed bytes32 keccak hashes of transactions
        emit transactions_by_address(addrSHA3, tinfo.transactionSHA3); // logs transactions per address, tighly packed bytes32 keccak hashes of transactions
        StoreTransactionsByBundle(bundSHA3, tinfo.transactionSHA3);
        StoreTransactionsByAddress(addrSHA3, tinfo.transactionSHA3);
    }

    // Allows for initial load of Balances while in Genesis Mode
    function ADM_LoadADKBalances (string memory _address, int _value) public onlyGenesis {
        ADKTokenInterface(ADKTokenAddress).meshTransaction(_address, _value);
    }
    // Allows for initial load of Balances while in Genesis Mode/ bulk mode for speedup
    function ADM_LoadADKBalancesBulk (string memory _addresses,
                                        int _value1,
                                        int _value2,
                                        int _value3,
                                        int _value4,
                                        int _value5,
                                        int _value6,
                                        int _value7,
                                        int _value8,
                                        int _value9,
                                        int _value10
                                        )  public onlyGenesis {
        uint32 pos = 0;
        require (bytes(_addresses).length == 81 * 10 , "String must contain 10 addresses without checksum for bulk processing");
        ADKTokenInterface(ADKTokenAddress).meshTransaction(substring(_addresses,pos,pos+81), _value1); pos+= 81;
        ADKTokenInterface(ADKTokenAddress).meshTransaction(substring(_addresses,pos,pos+81), _value2); pos+= 81;
        ADKTokenInterface(ADKTokenAddress).meshTransaction(substring(_addresses,pos,pos+81), _value3); pos+= 81;
        ADKTokenInterface(ADKTokenAddress).meshTransaction(substring(_addresses,pos,pos+81), _value4); pos+= 81;
        ADKTokenInterface(ADKTokenAddress).meshTransaction(substring(_addresses,pos,pos+81), _value5); pos+= 81;
        ADKTokenInterface(ADKTokenAddress).meshTransaction(substring(_addresses,pos,pos+81), _value6); pos+= 81;
        ADKTokenInterface(ADKTokenAddress).meshTransaction(substring(_addresses,pos,pos+81), _value7); pos+= 81;
        ADKTokenInterface(ADKTokenAddress).meshTransaction(substring(_addresses,pos,pos+81), _value8); pos+= 81;
        ADKTokenInterface(ADKTokenAddress).meshTransaction(substring(_addresses,pos,pos+81), _value9); pos+= 81;
        ADKTokenInterface(ADKTokenAddress).meshTransaction(substring(_addresses,pos,pos+81), _value10);
    }

    // Events (Logging)
    event EventLogString(string indexed info, string strdata);
    event EventLogInt(string indexed info, int intdata);
    event EventLogUInt(string indexed info, uint uintdata);

    //
    // Additional helper functions / tools

    // Convert a single tryte to 3 trits
    function TryteToTrits (uint16 test) public pure returns (int16[3] memory){
               // TO DO  use modulo instead.
               if (test == 57)return [int16(0),int16(0),int16(0)]; // 9 // special case
               require(test >= 65 && test <= 90,"INVALID TRYTE");
               uint16 base = test + 3;  // 68 is the base, that perfectly matches the modulo so that e.g. 65 becomes 1/0/0
               return [
                        int16(base % 3)-1,
                        int16((base/3) % 3)-1,
                        int16((base/9) % 3)-1
                   ];
    }

    // Convert value-trytes to actual values
    function TryteToIntValue(bytes memory data) public pure  returns (int) {
        int ret = 0;

        for (uint i = data.length; i > 0; i--) { // have to use >0 and then -1 because otherwise uint becomes negative and transaction reverts
            int16[3] memory trits = TryteToTrits(uint8(data[i-1]));
            ret = ret * 3 + trits[2];
            ret = ret * 3 + trits[1];
            ret = ret * 3 + trits[0];
        }
        return ret;
    }

    // Checks if two strings are identical
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    // CurlHashOP - calculates a CURL hash for a given Tryte string
    function CurlHashOP(string memory str) public pure returns (string memory){

        bytes memory pdata = bytes(string(abi.encodePacked("{CURL}", "HASH", bytes1(0x00), bytes1(0x00), str)));
        bytes32 r1 = keccak256(pdata);
        pdata[10] = 0x20; // next 32 chars
        bytes32 r2 = keccak256(pdata);
        pdata[10] = 0x40; // next 32 chars
        bytes32 r3 = keccak256(pdata);

        bytes memory ret = new bytes(81);

        for (uint i = 0; i< 32; i++){ // 0-64
            ret[i] = r1[i];
            ret[32+i] = r2[i];
        }
        for (uint i = 0; i < 17; i++){ // 64-81
            ret[64+i] = r3[i];
        }

        return string(ret);
    }

    // Calls the ADK (gadk) Signature Validation Routine via the overloaded keccak function

    function CurlValidateSignature(string memory addr, string memory signature, string memory bundle) internal pure returns (bool){

        bytes memory pdata = bytes(string(abi.encodePacked("{CURL}", "VALSIG", addr,signature,bundle)));
        bytes32 result = keccak256(pdata);

        return uint(result)==0;  // must be 0, only then the signature is valid
    }

    // substring helper function
    function substring(string memory str, uint32 startIndex, uint32 endIndex) internal pure returns (string memory ) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex-startIndex);
        for(uint32 i = startIndex; i < endIndex; i++) {
            result[i-startIndex] = strBytes[i];
        }
        return string(result);
    }

    // subbytes helper function
    function subbytes(bytes memory strBytes, uint startIndex, uint endIndex) internal pure returns (bytes memory ) {
        bytes memory result = new bytes(endIndex-startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            result[i-startIndex] = strBytes[i];
        }
        return result;
    }

    // concat (strings) helper function
    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b,"","",""));
    }

    //
    // Modifiers    /////////////////////////////////////////////////
    //

    modifier mod_requireAZ9 (string memory _adk_string) {
        bytes memory adkBytes = bytes (_adk_string);
        require(adkBytes.length >= 1 );

        bool valid = true;
        for (uint i = 0; i < adkBytes.length; i++) {
            if (
                ! (
                    uint8(adkBytes[i]) == 57 //9
                     || (uint8(adkBytes[i]) >= 65 && uint8(adkBytes[i]) <= 90) //A-Z
                  )
               ) valid = false;
        }
        require (valid, "INVALID TRYTES");
        _;
    }

    // MODIFIERS

    modifier onlyGenesis {
        require(msg.sender == adkgo_genesis_address, "NOT AUTHORIZED");
        _;
    }

}
