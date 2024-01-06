// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IIns20 {
    function mint(address to, uint256 amount) external payable returns(bool);
    function name() external view returns(string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}