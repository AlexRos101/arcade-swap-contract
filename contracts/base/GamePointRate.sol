// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GamePointRate {
    using SafeMath for uint256;

    mapping(address => mapping (uint256 => uint256)) internal totalDepositedArcade;
    mapping(address => mapping (uint256 => uint256)) internal totalDepositedGamePoint;

    /**
     * @notice add total deposited Arcade token amount and 
     * total deposited game point
     * @param from wallet address which is going to deposit
     * @param id game id
     * @param tokenAmount deposited token amount
     * @param gamePoint deposited game point
     */
    function addDepositInfo(
        address from,
        uint256 id,
        uint256 tokenAmount,
        uint256 gamePoint
    ) internal {
        require(from != address(0), "Address can't be zero.");

        totalDepositedArcade[from][id] += tokenAmount;
        totalDepositedGamePoint[from][id] += gamePoint;
    }

    /**
     * @notice Get game point rate to Arcade token
     * rate = real_rate * 10 ** 18
     * @param from wallet address to withdraw game point
     * @param id game id
     * @return uint256 returns rate of game point to arcade token
     */
    function getGamePointRate(address from, uint256 id) 
        public view returns (uint256) 
    {
        return 
            totalDepositedArcade[from][id]
            .div(totalDepositedGamePoint[from][id]);
    }
}