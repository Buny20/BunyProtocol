// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakePair.sol";
import "../library/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Liquidity is OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IPancakeRouter02 public router;
    function initialize(
        address _router
    ) external initializer {
        require(_router != address(0));
        __Ownable_init();
        router = IPancakeRouter02(_router);
    }

    function createPair(address _token0, address _token1) external returns(address pair){
        if (_token0 == address(0)) {
            _token0 = router.WETH();
        }

        if (_token1 == address(0)) {
            _token1 = router.WETH();
        }
        require(_token0 != _token1);
        pair = IPancakeFactory(router.factory()).createPair(
            _token0,
            _token1
        );
    }

    function addLiquidityEth(address _token, uint256 _amount, address _to) external payable {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        IERC20(_token).approve(address(router), type(uint256).max);
        router.addLiquidityETH{value:msg.value}(_token, _amount, 0, 0, _to, block.timestamp + 60);
    }

    function withdrawETH(address _to) external onlyOwner {
        require(address(this).balance > 0, "no balance");
        uint256 balance = address(this).balance;
        payable(_to).transfer(balance);
    }

    receive() external payable {}
}


