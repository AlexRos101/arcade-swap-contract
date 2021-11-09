pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ArcadeDoge is ERC20 {
    constructor(uint256 initialSupply) ERC20("ArcadeDoge", "ARCADEDOGE") {
        _mint(msg.sender, initialSupply);
    }
}