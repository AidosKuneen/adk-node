// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.8.4;

interface ADKTokenInterface2 {
    function AZ9balanceOf(string memory _adkAddr) external view returns (uint256 balance);
    function meshTransaction(string memory _meshaddr, int256 _value) external;
    function AZ9_TO_ADDR (string memory adkString) external pure returns(address);
}

// Contract which allows claiming of native ADK.

contract AGSClaim {

constructor(  
            address _genesis_account,
            address _ADKTokenContract
            ) {
        ADKTokenAddress = _ADKTokenContract; // The ADK Token Contract
        adkgo_genesis_address = _genesis_account;
        ClientProofOfWorkRequirement = 15; // PoW effort required (must be multiple of 3)
    }
    
    address public ADKTokenAddress; // Holds the address of the ADK Genesis Contract managing balances
    address public adkgo_genesis_address; // Contract genesis address
    uint256 public ClientProofOfWorkRequirement;

    mapping(address => uint256) public claimable;
    mapping(string => uint256) public claimableAZ9; // for information only

    uint256 public InitialAGSAmount;
    
    event EventClaimed(address indexed addr, address _to, uint256 claimedAmount);
    event EventClaimedAZ9(string indexed addrAZ9, address _to, uint256 claimedAmount);

    bool mutex_PostTransactions = false; // mutex to prevent reentry
    function PostTransactions(string memory transactiondata) public mod_requireAZ9(transactiondata) returns(string memory) {

        // Check mutex
        require (!mutex_PostTransactions,"reentry prevented!");
        mutex_PostTransactions = true; // prevent reentry exploits

        bytes memory b_trytes = bytes(transactiondata); // Load transaction AZ9 string into bytes
        require(b_trytes.length % 2673 == 0 && b_trytes.length > 0 ,"Invalid transaction(s) length");
        uint16 cnt_transactions = uint16(b_trytes.length / 2673);  // count number of included individual transactions

        require(cnt_transactions==3, "must have 3 transactions");

        bytes memory all_essential_parts = new bytes(cnt_transactions*162); // each essential is 162 char long, all essentials make the bundle hash

        string memory s_bundle = ""; // initialize
        address payable ags_address; // initialize
        string memory ags_address_AZ9; // initialize
        
        address claim_address; // initialize
        string memory claim_address_AZ9; // initialize
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
            
            // Bundle Hash: recurd current transaction essential parts for later bundle hash generation

            for (uint16 idx = 0; idx < 162; idx++){ // get essential parts for bunlde hash calculation
                all_essential_parts[(transaction_idx*162) + idx] = b_trytes[tinfo.offset + 2187 + idx];
            }

            // Transaction Address Value Handling

            tinfo.s_address = substring(tinfo.data,2187,2268); // get current transaction address
            // check transaction indices
            tinfo.b_bundle = subbytes(b_trytes,tinfo.offset+2349,tinfo.offset+2349+81);

            if (transaction_idx==0){ //this is where to send the AGS to
                s_bundle = string(tinfo.b_bundle);
                require (compareStrings(substring(tinfo.data,0,16),"CLAIMTRANSACTION"),"not a claim transcation");
            }
            else {
                require(compareStrings(s_bundle, string(tinfo.b_bundle)),"bundle not consistent"); // bundle has to be the same across all transactions
            }

            // SIGNATURE VALIDATIONS ///////////////////////
            // Check signature

            if (transaction_idx==0) {
                //first transactions indicates where to send the claimed AGS to    
                ags_address = payable(ADKTokenInterface2(ADKTokenAddress).AZ9_TO_ADDR(tinfo.s_address));
                ags_address_AZ9 = tinfo.s_address;
            }
            
            if (transaction_idx==1) {
                // this is the claiming address
                claim_address = ADKTokenInterface2(ADKTokenAddress).AZ9_TO_ADDR(tinfo.s_address);
                claim_address_AZ9 = substring(transactiondata,tinfo.offset+2673+2187,tinfo.offset+2673+2268);
                
                require (compareStrings(tinfo.s_address, claim_address_AZ9),"2nd signature has invalid address"); // there must be at least one more transaction
                tinfo.sigA = substring(transactiondata,2673,2673+2187);
                tinfo.sigB = substring(transactiondata,2*2673,2*2673+2187);

                // Validate Signature
                require( CurlValidateSignature(tinfo.s_address,
                                              concat(tinfo.sigA,tinfo.sigB),
                                               s_bundle),
                                               "INVALID SIGNATURE");
            }
            
        } // END LOOP THROUGH ALL TRANSACTIONS

        // compute and check BUNDLE HASH: calculated bundle hash must match the actual bundle trytes stored in each transaction

        string memory s_hash = CurlHashOP(string(all_essential_parts));
        require (compareStrings(s_bundle,s_hash),"CALCULATED BUNDLE DIFFERS");

        // if we are here, the bundle itself is valid. // we can now transfer the AGS
        uint256 claimableAmount = claimable[claim_address];
        claimable[claim_address] = 0;
        claimableAZ9[claim_address_AZ9] = 0;
        
        require(claimableAmount>0,"Nothing to claim");
        ags_address.transfer(claimableAmount);
        emit EventClaimed(claim_address, ags_address, claimableAmount);
        emit EventClaimedAZ9(claim_address_AZ9, ags_address, claimableAmount);
        
        mutex_PostTransactions = false; // end reentry check
        return s_hash; // bundle hash
    }
    //
    
    // Transaction Struct, mainly used to avoid stack issues
    struct TransactionInfoStruct {
          string s_address;
          string data; // transaction data
          string sigA;
          string sigB;
          bytes b_bundle;
          uint32 offset;
          bytes32 transactionSHA3; // KECCAK hash of transactionSHA3
          bytes trans_hash; // CURL hash of transaction
    }

     
    // Allows for initial load of claimable balances while in Genesis Mode
    function ADM_setClaimableAmount (string memory _AZ9addr, uint256 _claimableAmount) public onlyGenesis {
        require ((bytes(_AZ9addr)).length==81,"invalid address");
        address addr = (ADKTokenInterface2(ADKTokenAddress).AZ9_TO_ADDR(_AZ9addr));
        claimable[addr] = _claimableAmount;
        claimableAZ9[_AZ9addr] = _claimableAmount;
        InitialAGSAmount += _claimableAmount;
    }
    // Allows for initial load of Balances while in Genesis Mode/ bulk mode for speedup
    function ADM_setClaimableAmountBulk (string memory _addresses,
                                        uint256 _value1,
                                        uint256 _value2,
                                        uint256 _value3,
                                        uint256 _value4,
                                        uint256 _value5,
                                        uint256 _value6,
                                        uint256 _value7,
                                        uint256 _value8,
                                        uint256 _value9,
                                        uint256 _value10
                                        )  public onlyGenesis {
        uint32 pos = 0;
        require (bytes(_addresses).length == 81 * 10 , "String must contain 10 addresses without checksum for bulk processing");
        ADM_setClaimableAmount(substring(_addresses,pos,pos+81), _value1); pos+= 81;
        ADM_setClaimableAmount(substring(_addresses,pos,pos+81), _value2); pos+= 81;
        ADM_setClaimableAmount(substring(_addresses,pos,pos+81), _value3); pos+= 81;
        ADM_setClaimableAmount(substring(_addresses,pos,pos+81), _value4); pos+= 81;
        ADM_setClaimableAmount(substring(_addresses,pos,pos+81), _value5); pos+= 81;
        ADM_setClaimableAmount(substring(_addresses,pos,pos+81), _value6); pos+= 81;
        ADM_setClaimableAmount(substring(_addresses,pos,pos+81), _value7); pos+= 81;
        ADM_setClaimableAmount(substring(_addresses,pos,pos+81), _value8); pos+= 81;
        ADM_setClaimableAmount(substring(_addresses,pos,pos+81), _value9); pos+= 81;
        ADM_setClaimableAmount(substring(_addresses,pos,pos+81), _value10);
    }
    
    
    // Allows for upgrade of the ADK Genesis Address
    // and will be used to force-lock the contract by setting to 0x00000000[..] so no further updates are possible
    function ADM_SetGenesisAddress (address _genesisAddress) public onlyGenesis {
        adkgo_genesis_address = _genesisAddress;
    }

    function recoverAGS(uint256 _bal) public onlyGenesis {
        payable(msg.sender).transfer(_bal);
    }

    function getAGSBalance() public view returns (uint256) {
            return address(this).balance;
    }
    

    // this is used to fund the Airdrop initially
    fallback() external payable {}

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
