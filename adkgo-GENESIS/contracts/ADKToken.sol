pragma solidity >0.8.4;

import "contracts/ADKTransactions.sol";

contract ADKToken {

    // ADKGO Genesis Contract for ADK
    //
    // This contract handles the ERC20 interface as well as the AZ9 total ADK balances
    //
    // All tools/clients wanting to interact with ADK via its ERC20 interface will use this contract as the Token Contract

    uint256 public totalSupply;

    uint256 constant private MAX_UINT256 = 2**256 - 1;

    mapping (address => uint256) public balances;      // balances and mesh-balances are always identical, just different representation of the account

    mapping (address => address) public linked_list_all_balances; // a linked ring with all addresses that have a balance, with the ADKTransactionsContract as the root element
    mapping (address => address) linked_list_all_balances_reverse; // a reversed linked ring with all addresses that have a balance

    mapping (address => mapping (address => uint256)) public allowed;

    string public name;     // Aidos Kuneen ADK
    uint8 public decimals;  // 8
    string public symbol;   // ADK

    address public adkgo_genesis_address;  // the 'mesh owner', holds all token still inside the ADK Mesh (if not in circulation as wADK)

    ADKTransactions public ADKTransactionsContract; // the contract that validates MESH transactions

    // CONSTRUCTOR
    constructor() {

        // build Genesis contract structure
        adkgo_genesis_address = msg.sender;
        new BlankContract(); // we do this solely to keep the same old 0x transaction address for ADKTransactionsContract as we removed the ADKGAS contract
        ADKTransactionsContract = new ADKTransactions(adkgo_genesis_address, address(this));

        name = "ADK"; //_tokenName;                               // Set the name for display purposes
        decimals = 8; //_decimalUnits;                            // Amount of decimals for display purposes (8 for ADK)
        symbol = "\u24B6"; // _tokenSymbol;                       // Set the symbol for display purposes
        balances[msg.sender] = 2500000000000000;//_initialAmount; // Give the mesh address all initial tokens
        totalSupply = 2500000000000000;//_initialAmount;          // 2500000000000000 ADK

        // prepare the linked list
        linked_list_all_balances[address(ADKTransactionsContract)] = address(ADKTransactionsContract);
        linked_list_all_balances_reverse[address(ADKTransactionsContract)] = address(ADKTransactionsContract);

    }

    // this updates the ring of all balances (ADK ERC20, not ADKTransactionsContract) that hold a value
    function UpdateBalanceRing(address _addr) internal {
        if (_addr == address(ADKTransactionsContract)) return; // do nothing on ADKTransactionsContract
        bool address_in_ring = linked_list_all_balances[_addr] != address(0);

        if (balances[_addr] == 0){ // if balance is 0, remove from the ring.
            if (address_in_ring){ //it exists
                address _next  = linked_list_all_balances[_addr];
                address _prev  = linked_list_all_balances_reverse[_addr];
                linked_list_all_balances[_prev] = _next; // remove _addr
                linked_list_all_balances_reverse[_next] = _prev;  // remove _addr
                linked_list_all_balances[_addr] = address(0);  // set _addr mapping to 0
                linked_list_all_balances_reverse[_addr] = address(0);  // set _addr mapping to 0
            }
        }
        else { // check if already in ring, then do nothing
            if ( ! address_in_ring){ // if it doesnt exist, we add it to the ring after the ADKTransactionsContract (first element))
                address _next = linked_list_all_balances[address(ADKTransactionsContract)];
                linked_list_all_balances[address(ADKTransactionsContract)] = _addr; // insert forward
                linked_list_all_balances[_addr] = _next;

                linked_list_all_balances_reverse[_next] = _addr; // insert backwards
                linked_list_all_balances_reverse[_addr] = address(ADKTransactionsContract);
            }
        }
    }

    // ERC20 ADK events

    // solhint-disable-next-line no-simple-event-func-name
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    //AZ9Transfer is for transactions from/to the mesh. As there is no direct from/to relationship,
    //   there is no from/to counterpart, just a transaction positive or negative.
    event AZ9Transfer(string indexed _meshaddr, address indexed _addr, int256 _value);

    // Standard ERC20 transfer Function
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value);
        require(address(this) != _to); // prevent accidental send of tokens to the contract itself
        balances[msg.sender] -= _value;
        balances[_to] += _value;

        // now we notify the receiving contract (if it exists)
        // Note: This is to allow other smart contracts to 'react' to receiving ADK token.

        require(notifyReceiver(msg.sender, _to, _value), "CALLED CONTRACT (notifyReceiver) REVERTED EXECUTION.");

        UpdateBalanceRing(msg.sender); // update ring of addresses with balances as needed
        UpdateBalanceRing(_to); // update ring of addresses with balances as needed

        emit Transfer(msg.sender, _to, _value); //solhint-disable-line indent, no-unused-vars
        return true;
    }

    // Standard ERC20 transferFrom Function
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 vallowance = allowed[_from][msg.sender];
        require(balances[_from] >= _value && vallowance >= _value);
        balances[_to] += _value;
        balances[_from] -= _value;
        if (vallowance < MAX_UINT256) {
            allowed[_from][msg.sender] -= _value;
        }
        // now we notify the receiving contract (if it exists)
        // Note: This is to allow other smart contracts to 'react' to receiving ADK token.

        require(notifyReceiver(_from, _to, _value), "CALLED CONTRACT (notifyReceiver) REVERTED.");

        UpdateBalanceRing(msg.sender); // update ring of addresses with balances as needed
        UpdateBalanceRing(_to); // update ring of addresses with balances as needed

        emit Transfer(_from, _to, _value); //solhint-disable-line indent, no-unused-vars
        return true;
    }

    // Standard ERC20 approve Function
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value); //solhint-disable-line indent, no-unused-vars
        return true;
    }

    // Standard ERC20 balanceOf Function
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

     // Standard ERC20 allowance Function
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /// END DEFAULT ERC20 FUNCTIONS

     // notifyReceiver: to notify contracts that received tokens via standard ERC20 transactions,
     //                 this allows ERC transfer triggered smart contract operations
     //
     // note the GAS is limited here to  10000 gas to prevent spam
     //
     function notifyReceiver(address _from, address _to, uint256 _value) internal returns (bool) {
          (bool success, bytes memory data) = _to.call{value: 0, gas: 10000}(
                    abi.encodeWithSignature("ADKERC20TransactionNotify(address,address,uint256)", _from, _to, _value)
            );
          return success;
     }


    // MESH TRANSACTION FUNCTIONS, CAN ONLY BE CALLED BY THE ADKTransaction Contract
    // Note: these are one-sided transaction as the ADK Transaction contract handles these individually, ensuring they total 0 across bundles
    // and there can be a combination of 1-n FROM and 1-m TO addresses

    function meshTransaction(string memory _meshaddr, int256 _value) public onlyADKTransactionContract requireValidADKAddress(_meshaddr) {

        address addr = AZ9_TO_ADDR(_meshaddr); // convert an AZ9 address to an 'address' address

        require(int(balances[addr]) + _value >= 0, "Critical: Invalid transaction, insufficient amount");

        balances[addr] = uint(int(balances[addr]) + _value); // update balance
        //
        UpdateBalanceRing(addr); // update ring of addresses with balances as needed
        //
        emit AZ9Transfer(_meshaddr, addr, _value); //solhint-disable-line indent, no-unused-vars
    }


    event GENESISTransaction(string indexed _meshaddr, address indexed _addr, int256 _value);


    // balanceOf Function for ADK style addresses
    //
    // Note: uses 81 char addresses (no checksum!)
    function AZ9balanceOf(string memory _adkAddr) public view returns (uint256 balance) {
        return balances[AZ9_TO_ADDR(_adkAddr)];
    }

    // performs a genesis transaction, i.e. load initial Snapshot balances for Mesh AZ9 balances

    function genesisTransaction(string memory _meshaddr, int256 _value) public onlyGenesis requireValidADKAddress(_meshaddr) {
        address addr = AZ9_TO_ADDR(_meshaddr);
        balances[addr] = uint(int(balances[addr]) + _value);
        // sync with main balances
        emit GENESISTransaction(_meshaddr, addr, _value); //solhint-disable-line indent, no-unused-vars
    }

    ////////////////////////////////////////////////////////
    // MODIFIERS

    modifier onlyGenesis {
        require(msg.sender == adkgo_genesis_address,"NOT OWNER");
        _;
    }

    modifier onlyADKTransactionContract {
        require(msg.sender == address(ADKTransactionsContract), "NOT ADK CONTRACT");
        _;
    }

    // Check if an address only contains 9A-Z, and is 81 char long
    modifier requireValidADKAddress (string memory _adk_address) {
        bool valid = true;
        bytes memory adkBytes = bytes (_adk_address);
        require(adkBytes.length == 81); //address without checksum

        for (uint i = 0; i < adkBytes.length; i++) {
            if (
                ! (
                    uint8(adkBytes[i]) == 57 //9
                     || (uint8(adkBytes[i]) >= 65 && uint8(adkBytes[i]) <= 90) //A-Z
                  )
               ) valid = false;
        }
        require (valid,"INVALID ADK ADDRESS");
        _;
    }

    // CONVERTER functions to translate from AZ9 addressses (Mesh Format) to 0x style Addresses

    // encode a 0x type address in a 9AZ format. This is needed e.g. when sending from the original ADK wallet
    // to a 0x type address (as ADK Token)

    function ADDR_TO_AZ9 (address ethAddr) public pure returns(string memory) {
         return BADDR_TO_AZ9(abi.encodePacked(ethAddr));
    }

     // byte version of ADDR_TO_AZ9 / helper function
    function BADDR_TO_AZ9 (bytes memory ethAddr) public pure returns(string memory) {
         bytes memory alphabet = "GHIJKLMNOPABCDEF"; // really only the first 16 char used...
                                                                // A-F remains A-F,  0-9 becomes GHI...
         require(ethAddr.length == 20); //20 bytes / an 0x address

         bytes memory str = new bytes(81);
         string memory header = "ZEROXADDRESS99";
         bytes memory header_b = bytes(header);
         for (uint i = 0; i < header_b.length; i++) { // len 13
              str[i] = header_b[i];
         }

         for (uint i = 7; i < 27; i++) {//first 40 chars (20 but double)
             str[i*2+1] = alphabet[uint(uint8(ethAddr[i-7] & 0x0f))]; // first hex char of set of 2
             str[i*2] = alphabet[uint(uint8(ethAddr[i-7] >> 4))];     // second hex char of set of 2
         }
         for (uint i = 54; i < 81; i++) { // rest 9s
             str[i] = 0x39; // 0x39 = "9"
         }
         return string(str);
    }

    // convert AZ9 string to 0x Address:
    //    uses 2-way format if it is a ZEROXADDRESS9 (meaning its actually a 0x address encoded as 0x address, so its 2 way convertible)
    //    Otherwise, we are using a 1-way keccak hash, which is used to store the actual address balance

    function AZ9_TO_ADDR (string memory adkString) public pure requireValidADKAddress(adkString) returns(address) {
        // 2-way conversion for ZEROXADDRESS9 addresses, and one-way conversions for others
        string memory header = "ZEROXADDRESS99";
        bytes memory header_b = bytes(header);
        bytes memory adkString_b = bytes(adkString);
        bool twoWay = true;

        bytes memory str = new bytes(20); //2*40 hex char plus leading 0x

        // check header for 2-WAY ID
        for (uint i = 0; twoWay && i < header_b.length; i++) { // len 13
              if (adkString_b[i] != header_b[i]) twoWay = false;
        }

        if (twoWay){ // found header flag, now validate remainder
            // check trailing 999s
             for (uint i = 7; i < 27; i++) {//first 40 chars have to be between 'A' and 'P'
                 require(adkString_b[i*2+1] >= 0x41 && adkString_b[i*2+1] <= 0x50,"MALFORMED 0x AZ9 ADDRESS"); // 0x39 = "9"
                 require(adkString_b[i*2] >= 0x41 && adkString_b[i*2] <= 0x50,"MALFORMED 0x AZ9 ADDRESS"); // 0x39 = "9"
                 //  translate
                 uint8 low;
                 uint8 high;
                 if (adkString_b[i*2+1] <= 0x46){ // A-F
                    low = uint8(adkString_b[i*2+1]) - 65 + 10; // A=10 B=11 etc...
                 } else { // G-P  0-9
                    low = uint8(adkString_b[i*2+1]) - 71; // G=0, H=1,....
                 }
                 if (adkString_b[i*2] <= 0x46){ // A-F
                    high = uint8(adkString_b[i*2]) - 65 + 10; // A=10 B=11 etc...
                 } else { // G-P  0-9
                    high = uint8(adkString_b[i*2]) - 71; // G=0, H=1,....
                 }
                 str[i-7] = bytes1(high * 16 + low); // High+Low Hex Char
             }
             // check trailing 999s
             for (uint i = 54; i < 81; i++) {//first 40 chars (20 but double)
                 require(adkString_b[i] == 0x39,"MALFORMED 0x AZ9 ADDRESS"); // 0x39 = "9"
             }
            //
            return utilBytesToAddress(str);
            //
        } else { // not a dedicated 0x Address, so 1-way translate
            //
            return utilBytesToAddress(keccak256(adkString_b));
            //
        }
    }

    // utilBytesToAddress: Helper function to convert 20 bytes to a properly formated Ethereum address

    function utilBytesToAddress(bytes memory bys) private pure returns (address addr) {
        require(bys.length == 20);
        assembly {
          addr := mload(add(bys,20))
        }
    }

    function utilBytesToAddress(bytes32 bys) private pure returns (address addr) {
        bytes memory b = new bytes(20);
        for (uint i = 0; i < 20; i++) {
            b[i] = bys[i];
        }
        return utilBytesToAddress(b);
    }

}

contract BlankContract { // we need this as we removed ADKGAS, but we want the same contract addresses as before for ADKTransactions

}
