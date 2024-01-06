// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface ICreate {
    function createINS20(
        uint256 maxSupply,
        uint256 amountPerMint,
        uint256 fee,
        address deployer,
        string memory tick
    ) external returns(address);
}