// SPDX-License-Identifier: MIT
import "./library/JsmnSolLib.sol";
import "./interfaces/IJsonTool.sol";

pragma solidity ^0.8.18;

contract JsonTool is IJsonTool{
    constructor(){}
    function parseJsonAndExecute(string calldata content) public override pure returns (JsonValue memory jsonValue) {
        uint returnValue;
        JsmnSolLib.Token[] memory tokens;
        uint actualNum;
        (returnValue, tokens, actualNum) = JsmnSolLib.parse(content, JsmnSolLib.INS20_MAX_JSON_TOKEN + 1);
        require (returnValue == JsmnSolLib.RETURN_SUCCESS, "json parse");
            // check json format
            {
                string memory p = JsmnSolLib.getBytes(content, tokens[1].start, tokens[1].end);
                string memory pVal = JsmnSolLib.getBytes(content, tokens[2].start, tokens[2].end);
                string memory op = JsmnSolLib.getBytes(content, tokens[3].start, tokens[3].end);
                string memory tick = JsmnSolLib.getBytes(content, tokens[5].start, tokens[5].end);
                require (JsmnSolLib.equals(p,JsmnSolLib.INS20_P_HASH) && JsmnSolLib.equals(op,JsmnSolLib.INS20_OP_HASH) && JsmnSolLib.equals(tick,JsmnSolLib.INS20_TICK_HASH) && JsmnSolLib.equals(pVal,JsmnSolLib.INS20_P_HASH_INS20), "!json");
                jsonValue.p=pVal;
            }
            // parse and execute
            {
                string memory opVal = JsmnSolLib.getBytes(content, tokens[4].start, tokens[4].end);
                string memory tickVal = JsmnSolLib.getBytes(content, tokens[6].start, tokens[6].end);
                string memory tok7 = JsmnSolLib.getBytes(content, tokens[7].start, tokens[7].end);
                string memory tok7Val = JsmnSolLib.getBytes(content, tokens[8].start, tokens[8].end);
                require(JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_DEPLOY) ||JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_MINT)||JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_TRANSFER)||JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_LIST)||JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_UNLIST)||JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_BUY), "!op");
                jsonValue.op=opVal;
                jsonValue.tick=tickVal;
                if (JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_DEPLOY)) {
                    string memory lim = JsmnSolLib.getBytes(content, tokens[9].start, tokens[9].end);
                    string memory limVal = JsmnSolLib.getBytes(content, tokens[10].start, tokens[10].end);
                    string memory fee = JsmnSolLib.getBytes(content, tokens[11].start, tokens[11].end);
                    string memory feeVal = JsmnSolLib.getBytes(content, tokens[12].start, tokens[12].end);
                    require(JsmnSolLib.equals(lim,JsmnSolLib.INS20_LIM_HASH)
                        && JsmnSolLib.equals(tok7,JsmnSolLib.INS20_MAX_HASH)
                        && JsmnSolLib.equals(fee, JsmnSolLib.INS20_MINT_FEE)
                        && JsmnSolLib.isDigit(tok7Val) && JsmnSolLib.isDigit(limVal) && JsmnSolLib.isDigit(feeVal), "!deploy");
                        jsonValue.executeFlag=true;
                        jsonValue.max=JsmnSolLib.toUint(tok7Val);
                        jsonValue.lim=JsmnSolLib.toUint(limVal);
                        jsonValue.fee=JsmnSolLib.toUint(feeVal);
                } else if (JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_MINT)) {
                    require(JsmnSolLib.equals(tok7,JsmnSolLib.INS20_AMT_HASH) && JsmnSolLib.isDigit(tok7Val), "!mint");
                    jsonValue.executeFlag=true;
                    jsonValue.amt=JsmnSolLib.toUint(tok7Val);
                } else if (JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_TRANSFER)) {
                    string memory receiver = JsmnSolLib.getBytes(content, tokens[9].start, tokens[9].end);
                    string memory receiverVal = JsmnSolLib.getBytes(content, tokens[10].start, tokens[10].end);
                    require(JsmnSolLib.equals(tok7,JsmnSolLib.INS20_AMT_HASH)
                        && JsmnSolLib.equals(receiver,JsmnSolLib.INS20_RECEIVER_HASH)
                        && JsmnSolLib.isDigit(tok7Val) && JsmnSolLib.isAddr(receiverVal),"!transfer");
                    jsonValue.executeFlag=true;
                    jsonValue.amt=JsmnSolLib.toUint(tok7Val);
                    jsonValue.receiver=JsmnSolLib.toAddress(receiverVal);
                }else if (JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_LIST)) {
                    string memory price = JsmnSolLib.getBytes(content, tokens[9].start, tokens[9].end);
                    string memory priceVal = JsmnSolLib.getBytes(content, tokens[10].start, tokens[10].end);
                    require(JsmnSolLib.equals(tok7,JsmnSolLib.INS20_AMT_HASH)
                        && JsmnSolLib.equals(price,JsmnSolLib.INS20_PRICE_HASH)
                        && JsmnSolLib.isDigit(tok7Val) && JsmnSolLib.isDigit(priceVal),"!list");
                    jsonValue.executeFlag=true;
                    jsonValue.amt=JsmnSolLib.toUint(tok7Val);
                    jsonValue.price=JsmnSolLib.toUint(priceVal);
                }else if (JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_UNLIST)) {
                    require(JsmnSolLib.equals(tok7,JsmnSolLib.INS20_LISTID_HASH)
                        && JsmnSolLib.isDigit(tok7Val),"!unlist");
                    jsonValue.executeFlag=true;
                    jsonValue.listid=JsmnSolLib.toUint(tok7Val);
                }else if (JsmnSolLib.equals(opVal,JsmnSolLib.INS20_OP_HASH_BUY)) {
                    require(JsmnSolLib.equals(tok7,JsmnSolLib.INS20_LISTID_HASH)
                        && JsmnSolLib.isDigit(tok7Val),"!buy");
                    jsonValue.executeFlag=true;
                    jsonValue.listid=JsmnSolLib.toUint(tok7Val);
                } else {
                    revert();
                }
            }
    }

}