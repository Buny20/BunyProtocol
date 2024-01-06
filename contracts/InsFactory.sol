// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "./interfaces/IFactory.sol";
import "./interfaces/IJsonTool.sol";
import "./interfaces/ICreate.sol";
import "./interfaces/IIns20.sol";
import "./library/Counters.sol";
import "./library/JsmnSolLib.sol";
import "./helpers/Ownable.sol";

contract InsFactory is Ownable, IFactory {
    using Counters for Counters.Counter;
    
    Counters.Counter private _inscriptionIdTracker;
    address public jsonTool;
    address public create;
    mapping(string => address) public override ins20Contracts;
    mapping(address => uint256) public override ins20TokenIndex;
    mapping(address => string[]) public holderTokens;
    mapping(address => bool) public override isOperator;
    INS20Token[] public ins20Tokens;
    mapping(string => ListTick[]) public tickLists;
    mapping(string => mapping(uint256 => uint256))  tickListsindex;
    mapping(uint256 => address) public listOwnerAddr;
    mapping(address => ListTick[]) public ownerList;
    mapping(address => mapping(uint256 => uint256)) ownerListindex;
    uint256 nonce = 0;
    event Deploy(
        address indexed tokenAddress,
        INS20Token  tokenInfo
    );
    event Mint(
        address indexed to,
        address tokenAddress,
        uint256 value
    );
    event Transfer(
        address indexed from, 
        address indexed to,
        address tokenAddress,
        uint256 value
    );
    event List(
        address indexed tokenAddress,
        address indexed seller,
        uint256 indexed liatId,
        string  tick,
        uint256 amount,
        uint256 price,
        uint256 timestamp
    );
    event UnList(
        address indexed tokenAddr,
        address indexed seller,
        uint256 indexed liatId,
        string  tick,
        uint256 amount,
        uint256 price,
        uint256 timestamp
    );
    event Buy(
        address indexed tokenAddr,
        address indexed buyer,
        uint256 indexed liatId,
        string  tick,
        address seller,
        uint256 amount,
        uint256 price,
        uint256 timestamp
    );
   event Sold(
        address indexed tokenAddr,
        address indexed seller,
        uint256 indexed liatId,
        string  tick,
        address buyer,
        uint256 amount,
        uint256 price,
        uint256 timestamp
    );

    constructor(address _jsonToolAddr) {
        isOperator[msg.sender] = true;
        isOperator[address(this)] = true;
        jsonTool = _jsonToolAddr;
        _inscriptionIdTracker.increment(); // default inscription ID 1
    }

    fallback(bytes calldata input) external payable returns (bytes memory) {
        require(msg.sender == tx.origin, "!EOA");
        require(JsmnSolLib.equals(string(input[0:6]),JsmnSolLib.INS_HEADER_HASH), "!header");
        uint256 id = _inscriptionIdTracker.current();
        _inscriptionIdTracker.increment();
        string memory content = string(input[6:bytes(input).length]);
        IJsonTool.JsonValue memory jsonVal = IJsonTool(jsonTool).parseJsonAndExecute(content);
        require(jsonVal.executeFlag, "!json execute failed");
        if (JsmnSolLib.equals(jsonVal.op,JsmnSolLib.INS20_OP_HASH_DEPLOY)) {
            require(ins20Contracts[jsonVal.tick] == address(0),"!deploy");
            createINS20(jsonVal.tick, jsonVal.max, jsonVal.lim, jsonVal.fee, id);
            emit Deploy(ins20Contracts[jsonVal.tick],ins20Tokens[ins20TokenIndex[ins20Contracts[jsonVal.tick]]]);
        } else if (JsmnSolLib.equals(jsonVal.op,JsmnSolLib.INS20_OP_HASH_MINT)) {
            address tokenAddr = ins20Contracts[jsonVal.tick];
            require(tokenAddr != address(0), "!mint");
            bool ret = IIns20(tokenAddr).mint{value:msg.value}(msg.sender, jsonVal.amt);
            if (ret) {
                addHoldTick(msg.sender,jsonVal.tick);
                emit Mint(msg.sender,ins20Contracts[jsonVal.tick],jsonVal.amt);
            } else {
                emit Mint(msg.sender,ins20Contracts[jsonVal.tick],0);
            }
        } else if (JsmnSolLib.equals(jsonVal.op,JsmnSolLib.INS20_OP_HASH_TRANSFER)) {
            address tokenAddr = ins20Contracts[jsonVal.tick];
            IIns20(tokenAddr).transferFrom(msg.sender, jsonVal.receiver,jsonVal.amt);
            addHoldTick(jsonVal.receiver,jsonVal.tick);
            if(balanceOfTick(jsonVal.tick,msg.sender)==0){
                removeHoldTick(msg.sender,jsonVal.tick);
            }
            emit Transfer(msg.sender,jsonVal.receiver,ins20Contracts[jsonVal.tick],jsonVal.amt);
        } else if (JsmnSolLib.equals(jsonVal.op,JsmnSolLib.INS20_OP_HASH_LIST)) {
            require(ins20Contracts[jsonVal.tick] != address(0),"!list");
            uint256 listId = creatNewList(jsonVal.tick,jsonVal.amt,jsonVal.price);
            emit List(ins20Contracts[jsonVal.tick],msg.sender,listId,jsonVal.tick,jsonVal.amt,jsonVal.price,block.timestamp);
        } else if (JsmnSolLib.equals(jsonVal.op,JsmnSolLib.INS20_OP_HASH_UNLIST)) {
            require(ins20Contracts[jsonVal.tick] != address(0) 
                && listOwnerAddr[jsonVal.listid] == msg.sender,"!unlist");
            removeList(jsonVal.tick,msg.sender,jsonVal.listid);
        } else if (JsmnSolLib.equals(jsonVal.op,JsmnSolLib.INS20_OP_HASH_BUY)) {
            require(ins20Contracts[jsonVal.tick] != address(0) 
                && listOwnerAddr[jsonVal.listid] != address(0),"!buy");
            buyToken(jsonVal.tick,listOwnerAddr[jsonVal.listid],jsonVal.listid);
            removeList(jsonVal.tick,listOwnerAddr[jsonVal.listid],jsonVal.listid);
            emit Transfer(listOwnerAddr[jsonVal.listid],msg.sender,ins20Contracts[jsonVal.tick],jsonVal.amt);
        } else {
            revert();
        }
        return abi.encode(0);
    }

    function createINS20(
        string memory tick,
        uint256 maxSupply,
        uint256 amountPerMint,
        uint256 fee,
        uint256 scriptionId
    ) internal {
        require(ins20Contracts[tick] == address(0), "deployed");
        address token = ICreate(create).createINS20(maxSupply, amountPerMint, fee, msg.sender, tick);
        ins20Contracts[tick] = address(token);
        INS20Token memory tokenInfo = INS20Token(
            address(token),
            tick,
            maxSupply,
            amountPerMint,
            fee,
            scriptionId,
            msg.sender,
            block.timestamp
        );
        ins20Tokens.push(tokenInfo);
        ins20TokenIndex[address(token)] = ins20Tokens.length-1;
    }

    receive() external payable {}

    //// management ////
    function withdraw() external onlyOwner {
        require(address(this).balance > 0, "no balance");
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    function setOperator(address operator, bool _isOperator) external onlyOwner {
        isOperator[operator] = _isOperator;
    }

    function setCreate(address _create) external onlyOwner {
        create = _create;
    }

    function getTokenCount() public view override returns (uint256) {
        return ins20Tokens.length;
    }

    function ins20TokensOf(uint256 index) public view override returns(INS20Token memory) {
        return ins20Tokens[index];
    }

    function getTickListsCount(string memory tick) external view override returns(uint256) {
        return tickLists[tick].length;
    }

    function tickListOf(string memory tick, uint256 index) external view override returns(ListTick memory) {
        return tickLists[tick][index];
    }

    function getOwnerListCount(address account) external view override returns(uint256) {
        return ownerList[account].length;
    }

    function ownerListOf(address account, uint256 index) external view override returns(ListTick memory) {
        return ownerList[account][index];
    }

    function checkHoldTick(address holder,string memory tick) public view returns (bool) {
        for (uint256 i = 0; i < holderTokens[holder].length; i++) {
            if (JsmnSolLib.equals(holderTokens[holder][i],tick)) {return true;}
        }
        // if we reach here, then the key doesn't exist
        return false;
    }

    function addHoldTick(address holder,string memory tick) internal returns (bool) {
        if (!checkHoldTick(holder,tick)) {
            holderTokens[holder].push(tick);
        }
        return true;
    }

    function removeHoldTick(address holder,string memory tick) internal returns (bool) {
        if (!checkHoldTick(holder,tick)) {return false;}
        // create a new keyArray array, remove key from it, and set it as the new keyArray array
        string[] memory newkeyArray = new string[](holderTokens[holder].length - 1);
        uint256 j = 0;
        for (uint256 i = 0; i < holderTokens[holder].length; i++) {
        if (!JsmnSolLib.equals(holderTokens[holder][i],tick)) {
            newkeyArray[j] = holderTokens[holder][i];
            j++;
        }
        }
        // set the new keyArray array
        holderTokens[holder] = newkeyArray;
        return true;
    }

    function balanceOfTick(string memory tick,address account) public view returns(uint256 holdbalance) {
        address tokenAddr = ins20Contracts[tick];
        if (tokenAddr != address(0)) {
            holdbalance = IIns20(tokenAddr).balanceOf(account);
        }
    }

    function creatNewList(string memory tick,uint256 amt,uint256 price) internal returns (uint256) {
        require(listamontcheck(tick,amt), "Insufficient balance!");
        uint256 listId = listidCrate(amt,price);
        ListTick memory listInfo = ListTick(
            tick,
            listId,
            msg.sender,
            amt,
            price,
            price/amt,
            block.timestamp
        );
        tickLists[tick].push(listInfo);
        tickListsindex[tick][listId]=tickLists[tick].length-1;

        ownerList[msg.sender].push(listInfo);
        ownerListindex[msg.sender][listId]=ownerList[msg.sender].length-1;

        listOwnerAddr[listId] = msg.sender;
        return listId;
    }

    function removeList(string memory tick,address listowner,uint256 listId) internal returns (bool) {
        //allist
        uint256 index = tickListsindex[tick][listId];
        ListTick memory deletListInfo =tickLists[tick][index];
        uint256 movedListId = tickLists[tick][tickLists[tick].length-1].listId;
        tickLists[tick][index] = tickLists[tick][tickLists[tick].length-1];
        tickLists[tick].pop();
        delete tickListsindex[tick][listId];
        tickListsindex[tick][movedListId]=index;

        //userlist
        uint256 userIndex = ownerListindex[listowner][listId];
        uint256 usermovedListId = ownerList[listowner][ownerList[listowner].length-1].listId;
        ownerList[listowner][userIndex] = ownerList[listowner][ownerList[listowner].length-1];
        ownerList[listowner].pop();
        delete ownerListindex[listowner][usermovedListId];
        ownerListindex[listowner][usermovedListId]=userIndex;
        address ownaddr = listOwnerAddr[listId];
        delete listOwnerAddr[listId];
        if(listowner == ownaddr){
            emit UnList(ins20Contracts[tick],msg.sender,listId,tick,deletListInfo.amt,deletListInfo.price,block.timestamp);
        }else{
            emit Sold(ins20Contracts[tick],listowner,listId,tick,msg.sender,deletListInfo.amt,deletListInfo.price,block.timestamp);
        }
        return true;
    }

    function buyToken(string memory tick,address listowner,uint256 listId) internal returns (bool) {
        ListTick memory listInfo = tickLists[tick][tickListsindex[tick][listId]];
        require(listInfo.price == msg.value, "!Insufficient payvalue");
        IIns20(ins20Contracts[tick]).transferFrom(listowner, msg.sender,listInfo.amt);
        payable(listowner).transfer(msg.value * 995 / 1000);
        return true;
    }

    function listamontcheck(string memory tick,uint256 amt) internal view returns (bool) {
        uint256 listAmut = 0;
        for (uint256 i = 0; i < ownerList[msg.sender].length; i++) {
            if (!JsmnSolLib.equals(ownerList[msg.sender][i].tick,tick)) {
                listAmut=listAmut+ownerList[msg.sender][i].amt;
            }
        }
        return balanceOfTick(tick,msg.sender)>=listAmut+amt;
    }
    
    function listidCrate(uint256 amt,uint256 price) internal returns(uint256) {
        nonce += 1;
        return uint256(keccak256(abi.encodePacked(amt,price,nonce, msg.sender, block.number)));
    }

}