// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "./ArcadeSwapV1.sol";

/**
 * @dev V4 upgrade template. Use this if update is needed in the future.
 */
contract ArcadeSwapV2 is ArcadeSwapV1 {
  /**
   * @dev Must call this jsut after the upgrade deployement, to update state
   * variables and execute other upgrade logic.
   * Ref: https://github.com/OpenZeppelin/openzeppelin-upgrades/issues/62
   */
  function upgradeToV2() public {
    require(version < 2, "SpecialLottery: Already upgraded to version 4");
    version = 2;
    console.log("v", version);
  }
}
