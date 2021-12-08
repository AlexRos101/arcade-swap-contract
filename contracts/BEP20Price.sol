// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./interface/PancakeSwapInterface.sol";

contract BEP20Price is OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    address public factoryAddress;
    address public tokenAddress;
    address public wbnbAddress;
    address public busdAddress;

    /**
     * @notice Initialize variable members
     * @param _factoryAddress PancakeSwap pool factory address
     * @param _tokenAddress ERC20 token address
     * @param _wbnbAddress WBNB token address
     * @param _busdAddress BUSD token address
     * @dev Callable by owner
     */
    function initialize(
        address _factoryAddress,
        address _tokenAddress,
        address _wbnbAddress,
        address _busdAddress
    ) public onlyOwner {
        factoryAddress = _factoryAddress;
        tokenAddress = _tokenAddress;
        wbnbAddress = _wbnbAddress;
        busdAddress = _busdAddress;
    }

    /**
     * @notice Get liquidity info from pancakeswap
     * Get the balance of `token1` and `token2` from liquidity pool
     * @param token1 1st token address
     * @param token2 2nd token address
     * @return (uint256, uint256) returns balance of token1 and token2 from pool
     */
    function _getLiquidityInfo(
        address token1, 
        address token2
    ) internal view returns (uint256, uint256) {
        address pairAddress = 
            IUniswapV2Factory(factoryAddress)
            .getPair(token1, token2);
        
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (uint256 res0, uint256 res1,) = pair.getReserves();
        
        address pairToken0 = pair.token0();
        if (pairToken0 == token1) {
            return (res0, res1);
        } else {
            return (res1, res0);
        }
    }

    /**
     * @notice Get BNB price in USD
     * price = real_price * 10 ** 18
     * @return uint256 returns BNB price in usd
     */
    function getBNBPrice() public view returns (uint256) {
        (uint256 bnbReserve, uint256 busdReserve) = 
            _getLiquidityInfo(wbnbAddress, busdAddress);
        return busdReserve.mul(10 ** 18).div(bnbReserve);
    }

    /**
     * @notice Get ERC20 token price in USD
     * price = real_price * 10 ** 18
     * @return uint256 returns Arcade token price in USD
     */
    function getTokenPrice() public view returns (uint256) {
        (uint256 tokenReserve, uint256 bnbReserve) = 
            _getLiquidityInfo(tokenAddress, wbnbAddress);
        uint256 bnbPrice = getBNBPrice();
        return bnbReserve.mul(bnbPrice).div(tokenReserve);
    }
}