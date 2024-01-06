// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IFactory {
    struct INS20Token {
        address tokenAddress;
        string tick;
        uint256 maxSupply;
        uint256 amountPerMint;
        uint256 fee;
        uint256 deployId;
        address deployer;
        uint256 timestamp;
    }

    struct ListTick {
        string tick;
        uint256 listId;
        address listOwner;
        uint256 amt;
        uint256 price;
        uint256 perPrice;
        uint256 timestamp;
    }

    function isOperator(address) external view returns (bool);
    function getTokenCount() external view returns (uint256);
    function ins20TokensOf(uint256 index) external view returns(INS20Token memory);
    function ins20Contracts(string memory) external view returns(address);
    function ins20TokenIndex(address) external view returns(uint256);
    function getTickListsCount(string memory tick) external view returns(uint256);
    function tickListOf(string memory tick, uint256 index) external view returns(ListTick memory);
    function getOwnerListCount(address account) external view returns(uint256);
    function ownerListOf(address account, uint256 index) external view returns(ListTick memory);
}