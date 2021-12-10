// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./abstracts/AbstractArcadeUpgradeable.sol";
import "./interface/IBEP20Price.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/**
 * @notice Swap Arcade(ERC20) token to individual game point.
 * Serveral games are registered on this contract and each contract has their 
 * own keys for the verification.
 * And when the user calls the contract function to withdraw game point to 
 * Arcade token, these keys are used for the verification.
 */
contract ArcadeSwapV1 is AbstractArcadeUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public arcadeToken;
    IBEP20Price public bep20Price;

    struct Commission {
        uint256 commission1; // 100% in 10000
        uint256 commission2; // 100% in 10000
        address treasuryAddress1;
        address treasuryAddress2;
    }
    mapping(uint256 => Commission) internal _commissions;

    /**
     * game id => price(in 3 digits for 100%)
     * e.g. price is 1000 for 100%
     * game id starts from 1
     */
    mapping(uint256 => uint256) public gamePointPrice;

    bytes32 internal _arcadeBackendKey;
    // <game id => byte32>
    mapping(uint256 => bytes32) internal _gameKeys;

    // <address => <game id => accumulated value>>
    mapping(address => mapping (uint256 => uint256))
        internal _totalDepositedArcade;
    // <address => <game id => accumulated value>>
    mapping(address => mapping (uint256 => uint256))
        internal _totalDepositedGamePoint;

    /**
     * @notice event of deposit request
     * @param id game id
     * @param tokenAmount deposited Arcade token amount
     * @param gamePointAmount deposited game point amount
     * @param lastRate deposited rate * 10 ** 15
     */
    event BuyGamePoint(
        uint256 indexed id,
        uint256 indexed tokenAmount,
        uint256 indexed gamePointAmount,
        uint256 lastRate
    );

    /** 
     * @notice event of withdraw request
     * @param id game id
     * @param tokenAmount withdrawn Arcade token amount
     * @param gamePointAmount withdrawn game point amount
     * @param rate withdrawn rate
     */
    event SellGamePoint(
        uint256 indexed id,
        uint256 indexed tokenAmount,
        uint256 indexed gamePointAmount,
        uint256 rate
    );

    function __ArcadeSwap_init(
        IERC20Upgradeable _arcadeToken,
        IBEP20Price _bep20Price
    ) public initializer {
        AbstractArcadeUpgradeable.initialize();
        arcadeToken = _arcadeToken;
        bep20Price = _bep20Price;
    }

    function setArcadeToken(IERC20Upgradeable _arcadeToken) external onlyOwner {
        arcadeToken = _arcadeToken;
    }

    function setBep20Price(IBEP20Price _bep20Price) external onlyOwner {
        bep20Price = _bep20Price;
    }

    /** 
     * @notice set Arcade backend team's key
     * @param _key Arcade Backend key
     */
    function setArcadeBackendKey(string memory _key) 
        external onlyOwner 
    {
        require(bytes(_key).length > 0, "key can't be none string");
        _arcadeBackendKey = keccak256(abi.encodePacked(_key));
    }

    /** 
     * @notice set individual game backend team's key
     * @param _id game id
     * @param _key game backend key
    */
    function setGameBackendKey(uint256 _id, string memory _key) 
        external onlyOwner 
    {
        require(_id != 0, "game id can't be zero");
        require(bytes(_key).length > 0, "key can't be none string");
        _gameKeys[_id] = keccak256(abi.encodePacked(_key));
    }

    /**
     * @notice Set commission per game
     * @param _id game id
     * @param _commission1 first commission percent in 10000(100%)
     * @param _commission2 second commission percent in 10000(100%)
     * @param _treasury1 first treasury address
     * @param _treasury2 second treasury address
     */
    function setCommission(
        uint256 _id,
        uint256 _commission1,
        uint256 _commission2,
        address _treasury1,
        address _treasury2
    ) external onlyOwner {
        require(_id != 0, "game id can't be zero");
        _commissions[_id] = Commission({
            commission1: _commission1,
            commission2: _commission2,
            treasuryAddress1: _treasury1,
            treasuryAddress2: _treasury2
        });
    }

    /**
     * @notice View commission per game
     * @param _id game id
     * @return commission structure
     */
    function viewCommission(uint256 _id)
        external
        view
        returns (Commission memory)
    {
        require(_id != 0, "game id can't be zero");
        return _commissions[_id];
    }

    /** 
     * @notice deposit Arcade token to game point
     * @param _id game id
     * @param _amount Arcade token amount 
     */
    function buyGamePoint(uint256 _id, uint256 _amount) external nonReentrant {
        require(_id != 0, "game id can't be zero");
        require(_amount != 0, "amount can't be zero");
        require(_gameKeys[_id] !=  0, "Not registered game key.");
        require(gamePointPrice[_id] != 0, "Not registered game point price.");

        // distribute commission
        uint256 commission1 = _amount.mul(_commissions[_id].commission1).div(
            10000
        );
        uint256 commission2 = _amount.mul(_commissions[_id].commission2).div(
            10000
        );
        if (commission1 > 0) {
            arcadeToken.safeTransferFrom(
                msg.sender,
                _commissions[_id].treasuryAddress1,
                commission1
            );
        }
        if (commission2 > 0) {
            arcadeToken.safeTransferFrom(
                msg.sender,
                _commissions[_id].treasuryAddress2,
                commission2
            );
        }

        arcadeToken.safeTransferFrom(
            msg.sender,
            address(this),
            _amount.sub(commission1).sub(commission2)
        );

        uint256 rate = bep20Price.getTokenPrice(
            address(arcadeToken), 18
        ).div(gamePointPrice[_id]);
        uint256 internalGamePoint = _amount.mul(rate).div(10 ** 15);
        uint256 gamePoint = internalGamePoint.div(10 ** 18);

        _addDepositInfo(msg.sender, _id, _amount, internalGamePoint);

        console.log("--------BuyGamePoint--------");
        console.log(_id);
        console.log(_amount);
        console.log(gamePoint);
        console.log(rate);
        console.log("----------------------------");

        emit BuyGamePoint(_id, _amount, gamePoint, rate);
    }

    /** 
     * @notice withdraw game point to Arcade token
     * @param _id game id
     * @param _amount amount to withdraw
     * @param _verificationData data to verify the withdraw request
     */
    function sellGamePoint(
        uint256 _id,
        uint256 _amount,
        bytes32 _verificationData
    ) external nonReentrant {
        require(
            _verifyMeta(
                _verificationData,
                msg.sender,
                _id,
                _amount
            ),
            "Verification data is incorrect."
        );

        uint256 gamePointRate = getGamePointRate(msg.sender, _id);

        uint256 arcadeAmount = _amount.mul(gamePointRate);

        // distribute commission
        uint256 commission1 = arcadeAmount.mul(_commissions[_id].commission1).div(
            10000
        );
        uint256 commission2 = arcadeAmount.mul(_commissions[_id].commission2).div(
            10000
        );
        if (commission1 > 0) {
            arcadeToken.safeTransfer(
                _commissions[_id].treasuryAddress1,
                commission1
            );
        }
        if (commission2 > 0) {
            arcadeToken.safeTransfer(
                _commissions[_id].treasuryAddress2,
                commission2
            );
        }

        arcadeToken.safeTransfer(msg.sender, arcadeAmount.sub(commission1).sub(
            commission2
        ));

        console.log("--------SellGamePoint--------");
        console.log(_id);
        console.log(arcadeAmount);
        console.log(_amount);
        console.log(gamePointRate);
        console.log("----------------------------");

        emit SellGamePoint(_id, arcadeAmount, _amount, gamePointRate);
    }

    /** 
     * @notice withdraw Arcade token
     * @param _to "to" address of withdraw request
     * @param _amount amount to withdraw
     */
    function transferTo(address _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Transfer to zero address.");
        arcadeToken.safeTransfer(_to, _amount);
    }

    /** 
     * @notice set price of individual game point in usd
     * registered price = real price * 10**3
     * @param _id game id
     * @param _price game point price
     */
    function setGamePointPrice(uint256 _id, uint256 _price) external onlyOwner {
        require(_price != 0, "Price can't be zero.");
        gamePointPrice[_id] = _price;
    }

    function _verifyMeta(
        bytes32 _meta,
        address _sender,
        uint256 _id,
        uint256 _amount
    ) internal view returns (bool) {
        bytes32 gameBackendVerification =
            keccak256(abi.encodePacked(
                _id,
                _sender,
                _amount,
                _gameKeys[_id]
            ));
        bytes32 arcadeBackendVerification =
            keccak256(
                abi.encodePacked(gameBackendVerification, _arcadeBackendKey)
            );
        return _meta == arcadeBackendVerification;
    }

    /**
     * @notice add total deposited Arcade token amount and 
     * total deposited game point
     * @param _from wallet address which is going to deposit
     * @param _id game id
     * @param _tokenAmount deposited token amount
     * @param _gamePoint deposited game point
     */
    function _addDepositInfo(
        address _from,
        uint256 _id,
        uint256 _tokenAmount,
        uint256 _gamePoint
    ) internal {
        require(_from != address(0), "Address can't be zero.");

        _totalDepositedArcade[_from][_id] += _tokenAmount;
        _totalDepositedGamePoint[_from][_id] += _gamePoint;
    }

    /**
     * @notice Get game point rate to Arcade token
     * rate = real_rate * 10 ** 18
     * @param _from wallet address to withdraw game point
     * @param _id game id
     * @return uint256 returns rate of game point to arcade token
     */
    function getGamePointRate(address _from, uint256 _id) 
        public view returns (uint256) 
    {
        if (_totalDepositedGamePoint[_from][_id] == 0) {
            return gamePointPrice[_id].mul(10 ** 33).div(
                bep20Price.getTokenPrice(address(arcadeToken), 18)
            );
        }
        
        return 
            _totalDepositedArcade[_from][_id]
            .mul(10 ** 18)
            .div(_totalDepositedGamePoint[_from][_id]);
    }
}