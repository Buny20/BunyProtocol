// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./interfaces/IFactory.sol";
import "./interfaces/IIns20.sol";

contract Dashboard {

    IFactory public factory;

    constructor(address _factory) {
        require(_factory != address(0));
        factory = IFactory(_factory);
    }

    function getTokenCount() public view returns (uint256) {
        return factory.getTokenCount();
    }

    function getTickListsCount(string memory tick) external view returns(uint256) {
        return factory.getTickListsCount(tick);
    }

    function getOwnerListCount(address account) external view returns(uint256) {
        return factory.getOwnerListCount(account);
    }

    function getTokensByPage(uint256 page, uint256 pageSize) external view returns (IFactory.INS20Token[] memory tokens, uint256[] memory totalSupplies) {
        require(page > 0, "!pNumber");
        require(pageSize > 0, "!pSize");
        uint256 start = (page - 1) * pageSize;
        uint256 end = start + pageSize;
        uint256 length = factory.getTokenCount();
        if (end > length) {
            end = length;
        }
        if (end < start) {
            end = start;
        }

        tokens = new IFactory.INS20Token[](end - start);
        totalSupplies = new uint256[](end - start);
        for (uint256 i = start; i < end; i++) {
            tokens[i - start] = factory.ins20TokensOf(i);
            totalSupplies[i - start] = IIns20(tokens[i - start].tokenAddress).totalSupply();
        }
    }

    function getTokenByTick(string memory tick) public view returns (IFactory.INS20Token memory tokenInfo, uint256 totalSupply) {
        address tokenAddr = factory.ins20Contracts(tick);
        if (tokenAddr != address(0)) {
            tokenInfo = factory.ins20TokensOf(factory.ins20TokenIndex(tokenAddr));
            totalSupply = IIns20(tokenAddr).totalSupply();
        }
    }

    function getTickListeds(string memory tick,uint256 page, uint256 pageSize) public view returns (IFactory.ListTick[] memory listedTicks) {
        require(page > 0, "!pNumber");
        require(pageSize > 0, "!pSize");
        uint256 start = (page - 1) * pageSize;
        uint256 end = start + pageSize;
        uint256 length = factory.getTickListsCount(tick);
        if (end > length) {
            end = length;
        }
        if (end < start) {
            end = start;
        }
        listedTicks = new IFactory.ListTick[](end - start);
        for (uint256 i = start; i < end; i++) {
            listedTicks[i - start] = factory.tickListOf(tick, i);
        }
    }

    function getUserListeds(address addr,uint256 page, uint256 pageSize) public view returns (IFactory.ListTick[] memory listedTicks) {
        require(page > 0, "!pNumber");
        require(pageSize > 0, "!pSize");
        uint256 start = (page - 1) * pageSize;
        uint256 end = start + pageSize;
        uint256 length = factory.getOwnerListCount(addr);
        if (end > length) {
            end = length;
        }
        if (end < start) {
            end = start;
        }
        listedTicks = new IFactory.ListTick[](end - start);
        for (uint256 i = start; i < end; i++) {
            listedTicks[i - start] = factory.ownerListOf(addr, i);
        }
    }
}