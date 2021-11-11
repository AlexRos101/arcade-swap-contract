// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interface/pcs/PancakeSwapInterface.sol";

contract ArcadeDogeRate is Ownable {
    using SafeMath for uint256;

    address public pancakeswapFactoryAddress;
    address public arcadedogeTokenAddress;
    address public wbnbAddress;
    address public busdAddress;

    /** 
     * @notice set PancakeSwap factory Address
     * @param factoryAddress PancakeSwap pool factory address
     */
    function setPancakeSwapFactoryAddress(address factoryAddress) 
        external onlyOwner 
    {
        require(factoryAddress != address(0), "Factory can't be zero address.");
        pancakeswapFactoryAddress = factoryAddress;
    }

    /** 
     * @notice set ArcadeDoge token's address
     * @param tokenAddress ArcadeDoge token's address
     */
    function setArcadeDogeTokenAddress(address tokenAddress) 
        external onlyOwner 
    {
        require(tokenAddress != address(0), "$Arcade can't be zero address.");
        arcadedogeTokenAddress = tokenAddress;
    }

    /** 
     * @notice set WBNB address
     * @param _wbnbAddress WBNB Address on BSC
     */
    function setWBNBAddress(address _wbnbAddress) external onlyOwner {
        require(_wbnbAddress != address(0), "WBNB can't be zero address.");
        wbnbAddress = _wbnbAddress;
    }

    /** 
     * @notice set BUSD address
     * @param _busdAddress WBNB Address on BSC
     */
    function setBUSDAddress(address _busdAddress) external onlyOwner {
        require(_busdAddress != address(0), "BUSD can't be zero address.");
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
    ) private view returns (uint256, uint256) {
        address pairAddress = 
            IUniswapV2Factory(pancakeswapFactoryAddress)
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
     * @notice Get ArcadeDoge price in USD
     * price = real_price * 10 ** 18
     * @return uint256 returns ArcadeDoge token price in USD
     */
    function getAracadeDogeRate() public view returns (uint256) {
        // (uint256 arcadedogeReserve, uint256 bnbReserve) = 
        //     _getLiquidityInfo(arcadedogeTokenAddress, wbnbAddress);
        // uint256 bnbPrice = getBNBPrice();
        // return bnbReserve.mul(bnbPrice).div(arcadedogeReserve);
        return 10 * 10 ** 18;
    }
}