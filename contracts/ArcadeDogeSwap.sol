// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/ByteUtils.sol";
import "./utils/AccountUtils.sol";
import "./base/ArcadeDogeRate.sol";
import "hardhat/console.sol";

/**
 * @notice Swap ArcadeDoge(ERC20) token to individual game point.
 * Serveral games are registered on this contract and each contract has their 
 * own keys for the verification.
 * And when the user calls the contract function to withdraw game point to 
 * ArcadeDoge token, these keys are used for the verification.
 */
contract ArcadeDogeSwap is 
    Ownable, ReentrancyGuard, ArcadeDogeRate 
{
    using SafeMath for uint256;

    mapping(uint256 => uint256) public gamePointPrice;

    bytes32 private _arcadedogeBackendKey;   
    mapping(uint256 => bytes32) private _gameKeys;

    mapping(address => mapping (uint256 => uint256)) private _totalDepositedArcadeDoge;
    mapping(address => mapping (uint256 => uint256)) private _totalDepositedGamePoint;

    /**
     * @notice event of deposit request
     * @param id game id
     * @param tokenAmount deposited ArcadeDoge token amount
     * @param gamePointAmount deposited game point amount
     * @param lastRate deposited rate * 10 ** 15
     */
    event BuyGamePoint(
        uint256 indexed id,
        uint256 indexed tokenAmount,
        uint256 gamePointAmount,
        uint256 lastRate
    );

    /** 
     * @notice event of withdraw request
     * @param id game id
     * @param tokenAmount withdrawn ArcadeDoge token amount
     * @param gamePointAmount withdrawn game point amount
     * @param rate withdrawn rate
     */
    event SellGamePoint(
        uint256 indexed id,
        uint256 tokenAmount,
        uint256 gamePointAmount,
        uint256 rate
    );

    constructor(
        address _arcadedogeTokenAddress,
        address _factoryAddress,
        address _wbnbAddress,
        address _busdAddress
    ) {
        arcadedogeTokenAddress = _arcadedogeTokenAddress;
        pancakeswapFactoryAddress = _factoryAddress;
        wbnbAddress = _wbnbAddress;
        busdAddress= _busdAddress;
    }

    /** 
     * @notice set ArcadeDoge backend team's key
     * @param key ArcadeDoge Backend key
     */
    function setArcadeDogeBackendKey(string memory key) 
        external onlyOwner 
    {
        require(bytes(key).length > 0, "key can't be none string");
        _arcadedogeBackendKey = keccak256(abi.encodePacked(key));
    }

    /** 
     * @notice set individual game backend team's key
     * @param id game id
     * @param key game backend key
    */
    function setGameBackendKey(uint256 id, string memory key) 
        external onlyOwner 
    {
        require(id != 0, "game id can't be zero");
        require(bytes(key).length > 0, "key can't be none string");
        _gameKeys[id] = keccak256(abi.encodePacked(key));
    }

    /** 
     * @notice deposit ArcadeDoge token to game point
     * @param id game id
     * @param amount ArcadeDoge token amount 
     */
    function buyGamePoint(uint256 id, uint256 amount) external nonReentrant {
        require(id != 0, "game id can't be zero");
        require(amount != 0, "amount can't be zero");
        require(_gameKeys[id] !=  0, "Not registered game key.");
        require(gamePointPrice[id] != 0, "Not registered game point price.");

        bool successed = 
            IERC20(arcadedogeTokenAddress)
            .transferFrom(msg.sender, address(this), amount);
        require(successed, "Failed to transfer Arcade token.");

        uint256 rate = getAracadeDogeRate().div(gamePointPrice[id]);
        uint256 gamePoint = amount.mul(rate).div(10 ** 15).div(10 ** 18);

        addDepositInfo(msg.sender, id, amount, gamePoint);

        console.log("--------BuyGamePoint--------");
        console.log(id);
        console.log(amount);
        console.log(gamePoint);
        console.log(rate);
        console.log("----------------------------");

        emit BuyGamePoint(id, amount, gamePoint, rate);
    }

    /** 
     * @notice withdraw game point to ArcadeDoge token
     * @param id game id
     * @param amount amount to withdraw
     * @param verificationData data to verify the withdraw request
     */
    function sellGamePoint(
        uint256 id,
        uint256 amount,
        bytes32 verificationData
    ) external nonReentrant {
        bytes32 gameBackendVerification = 
            keccak256(abi.encodePacked(
                id,
                msg.sender,
                amount,
                _gameKeys[id]
            ));
        bytes32 arcadedogeBackendVerification = 
            keccak256(
                abi.encodePacked(gameBackendVerification, _arcadedogeBackendKey)
            );
        
        require(
            verificationData == arcadedogeBackendVerification,
            "Verification data is incorrect."
        );

        uint256 gamePointRate = getGamePointRate(msg.sender, id);
        console.log(gamePointRate);

        uint256 arcadedogeAmount = 
            amount.mul(gamePointRate);

        console.log(arcadedogeAmount);

        bool success = 
            IERC20(arcadedogeTokenAddress)
            .transfer(msg.sender, arcadedogeAmount);
        require(success, "Failed to transfer $Arcade.");

        console.log("--------SellGamePoint--------");
        console.log(id);
        console.log(arcadedogeAmount);
        console.log(amount);
        console.log(gamePointRate);
        console.log("----------------------------");

        emit SellGamePoint(id, arcadedogeAmount, amount, gamePointRate);
    }

    /** 
     * @notice withdraw ArcadeDoge token
     * @param to "to" address of withdraw request
     * @param amount amount to withdraw
     */
    function transferTo(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Transfer to zero address.");
        IERC20(arcadedogeTokenAddress).transfer(to, amount);
    }

    /** 
     * @notice set price of individual game point in usd
     * registered price = real price * 10**3
     * @param id game id
     * @param price game point price
     */
    function setGamePointPrice(uint256 id, uint256 price) external onlyOwner {
        require(price != 0, "Price can't be zero.");
        gamePointPrice[id] = price;
    }

    /**
     * @notice add total deposited ArcadeDoge token amount and 
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

        _totalDepositedArcadeDoge[from][id] += tokenAmount;
        _totalDepositedGamePoint[from][id] += gamePoint;
    }

    /**
     * @notice Get game point rate to ArcadeDoge token
     * rate = real_rate * 10 ** 18
     * @param from wallet address to withdraw game point
     * @param id game id
     * @return uint256 returns rate of game point to arcadedoge token
     */
    function getGamePointRate(address from, uint256 id) 
        public view returns (uint256) 
    {
        return 
            _totalDepositedArcadeDoge[from][id]
            .div(_totalDepositedGamePoint[from][id]);
    }
}