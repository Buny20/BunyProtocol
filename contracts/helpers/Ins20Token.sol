// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../library/SafeMath.sol";
import "./ERC20Permit.sol";
import "./Ownable.sol";

contract Ins20Token is ERC20Permit, Ownable {

    using SafeMath for uint256;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_, decimals_) {
    }

    function mint(address account_, uint256 amount_) external onlyOwner() {
        _mint(account_, amount_);
    }

    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
    }
     
    function burnFrom(address account_, uint256 amount_) public virtual {
        _burnFrom(account_, amount_);
    }

    function _burnFrom(address account_, uint256 amount_) public virtual {
        uint256 decreasedAllowance_ =
            allowance(account_, msg.sender).sub(
                amount_,
                "ERC20: burn amount exceeds allowance"
            );

        _approve(account_, msg.sender, decreasedAllowance_);
        _burn(account_, amount_);
    }
}