// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "./interfaces/ICreate.sol";
import "./Ins20.sol";

contract Create is ICreate{
    address public factory;
    constructor (address _factory) {
        require(_factory != address(0));
        factory = _factory;
    }

    function createINS20(
        uint256 maxSupply,
        uint256 amountPerMint,
        uint256 fee,
        address deployer,
        string memory tick
    ) external override returns(address) {
        require(msg.sender == factory, "no auth");
        require(bytes(tick).length == 4, "!tick");
        require(maxSupply > 0, "!maxSupply");
        require(amountPerMint > 0, "!amountPerMint");
        require(maxSupply >= amountPerMint, "maxSupply < amountPerMint");
        Ins20 token = new Ins20(maxSupply, amountPerMint, fee, factory, deployer, tick);
        return address(token);
    }
}