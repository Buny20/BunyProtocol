// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IJsonTool {
    struct JsonValue {
        bool executeFlag;
        string p;
        string op;
        string tick;
        uint256 max;
        uint256 lim;
        uint256 amt;
        uint256 fee;
        address receiver;
        uint256 price;
        uint256 listid;
    }
    function parseJsonAndExecute(string calldata content) external pure returns (JsonValue memory);
}