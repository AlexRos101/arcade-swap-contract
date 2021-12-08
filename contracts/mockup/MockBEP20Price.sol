// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interface/IBEP20Price.sol";

contract MockBEP20Price is Ownable, IBEP20Price {
    using SafeMath for uint256;

    uint256 private _bnbPrice = 30 * 10 ** 18;

    function _getBNBPrice() internal view returns (uint256) {
        return _bnbPrice;
    }

    /**
     * @notice Get BNB price in USD
     * price = real_price * 10 ** 18
     * @return uint256 returns BNB price in usd
     */
    function getBNBPrice() external override view returns (uint256) {
        return _getBNBPrice();
    }

    /**
     * @notice Get BEP20 token price in USD
     * price = real_price * 10 ** 18
     * @param _token BEP20 token address
     * @param _digits BEP20 token digits
     * @return uint256 returns Arcade token price in USD
     */
    function getTokenPrice(
        address _token,
        uint256 _digits
    ) external override view returns (uint256) {
        uint256 bnbPrice = _getBNBPrice();
        return bnbPrice.mul(5);
    }
}