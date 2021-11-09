pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./PancakeSwapInterface.sol";

/**
 * @dev Swap ArcadeDoge(ERC20) token to individual game point.
 * Serveral games are registered on this contract and each contract has their 
 * own keys for the verification.
 * And when the user calls the contract function to withdraw game point to 
 * ArcadeDoge token, these keys are used for the verification.
 */
contract ArcadeDogeSwap is Ownable {
    using SafeMath for uint;

    /** @dev event of deposit request
     * @param id game id
     * @param tokenAmount deposited ArcadeDoge token amount
     * @param gamePointAmount deposited game point amount
     */
    event Deposit(uint256 id, uint256 tokenAmount, uint256 gamePointAmount);

    /** @dev event of withdraw request
     * @param id game id
     * @param tokenAmount withdrawn ArcadeDoge token amount
     * @param gamePointAmount withdrawn game point amount
     */
    event Withdraw(uint256 id, uint256 tokenAmount, uint256 gamePointAmount);

    string private _arcadedogeBackendKey;
    mapping(uint256 => string) private _gameKeys;

    address public arcadedogeTokenAddress;
    address public pancakeswapFactoryAddress;
    address public wbnbAddress;
    address public busdAddress;

    mapping(address => mapping(uint256 => uint256)) public lastRates;
    mapping(uint256 => uint256) public gamePointPrice;

    constructor() {

    }

    /** @dev set ArcadeDoge backend team's key
     * @param key ArcadeDoge Backend key
     */
    function setArcadeDogeBackendKey(string memory key) external onlyOwner {
        require(keccak256(abi.encodePacked(key)) != keccak256(""), "key can't be none string");
        _arcadedogeBackendKey = key;
    }

    /** @dev set individual game backend team's key
     * @param id game id
     * @param key game backend key
    */
    function setGameBackendKey(uint256 id, string memory key) external onlyOwner {
        require(id != 0, "game id can't be zero");
        require(keccak256(abi.encodePacked(key)) != keccak256(""), "key can't be none string");
        _gameKeys[id] = key;
    }

    /** @dev set ArcadeDoge token's address
     * @param tokenAddress ArcadeDoge token's address
     */
    function setArcadeDogeTokenAddress(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "ArcadeDoge token's address can't be zero address.");
        arcadedogeTokenAddress = tokenAddress;
    }

    /** @dev deposit ArcadeDoge token to game point
     * @param id game id
     * @param amount ArcadeDoge token amount 
     */
    function deposit(uint256 id, uint256 amount) external {
        require(id != 0, "game id can't be zero");
        require(amount != 0, "amount can't be zero");
        require(keccak256(abi.encodePacked(_gameKeys[id])) != keccak256(""), "Not registered game key.");
        require(gamePointPrice[id] != 0, "Not registered game point price.");

        bool successed = IERC20(arcadedogeTokenAddress).transferFrom(msg.sender, address(this), amount);
        require(successed, "Transferring ArcadeDoge token to pool address was failed.");

        uint256 rate = getRate().div(gamePointPrice[id]);
        uint256 gamePoint = amount.mul(rate).div(10 ** 15).div(10 ** 18);

        lastRates[msg.sender][id] = rate;

        emit Deposit(id, amount, gamePoint);
    }

    /** @dev withdraw game point to ArcadeDoge token
     * @param id game id
     * @param amount amount to withdraw
     * @param verificationData data to verify the withdraw request
     */
    function withdraw(uint256 id, uint256 amount, string memory verificationData) external {
        string memory gameBackendVerification = 
            bytes32ToString(keccak256(abi.encodePacked(
                Strings.toString(id),
                toString(msg.sender),
                Strings.toString(amount),
                _gameKeys[id]
            )));
        string memory arcadedogeBackendVerification = 
            bytes32ToString(keccak256(
                abi.encodePacked(gameBackendVerification, _arcadedogeBackendKey)
            ));
        
        require(
            keccak256(abi.encodePacked(verificationData)) == keccak256(abi.encodePacked(arcadedogeBackendVerification)),
            "Verification data is incorrect."
        );

        uint256 arcadedogeAmount = amount.mul(10 ** 15).mul(10 ** 18).div(lastRates[msg.sender][id]);

        bool success = IERC20(arcadedogeTokenAddress).transfer(msg.sender, arcadedogeAmount);
        require(success, "Transferring Arcadedoge token failed.");

        emit Withdraw(id, arcadedogeAmount, amount);
    }

    /** @dev withdraw ArcadeDoge token
     * @param to "to" address of withdraw request
     * @param amount amount to withdraw
     */
    function transferTo(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to address can't be zero address.");
        IERC20(arcadedogeTokenAddress).transfer(to, amount);
    }

    /** @dev set price of individual game point in usd
     * registered price = real price * 10**3
     * @param id game id
     * @param price game point price
     */
    function setGamePointPrice(uint256 id, uint256 price) external onlyOwner {
        require(price != 0, "Price can't be zero.");
        gamePointPrice[id] = price;
    }

    /** @dev set PancakeSwap factory Address
     * @param factoryAddress PancakeSwap pool factory address
     */
    function setPancakeSwapFactoryAddress(address factoryAddress) external onlyOwner {
        require(factoryAddress != address(0), "PancakeSwap factory Address can't be zero address.");
        pancakeswapFactoryAddress= factoryAddress;
    }

    /** @dev set WBNB address
     * @param _wbnbAddress WBNB Address on BSC
     */
    function setWBNBAddress(address _wbnbAddress) external onlyOwner {
        require(_wbnbAddress != address(0), "WBNB address can't be zero address.");
        wbnbAddress = _wbnbAddress;
    }

    /** @dev set BUSD address
     * @param _busdAddress WBNB Address on BSC
     */
    function setBUSDAddress(address _busdAddress) external onlyOwner {
        require(_busdAddress != address(0), "BUSD address can't be zero address.");
        busdAddress = _busdAddress;
    }

    /**
     * @dev Get liquidity info from pancakeswap.
     * Get the balance of `token1` and `token2` from liquidity pool.
     */
    function getLiquidityInfo(
        address token1, 
        address token2
    ) private view returns (uint256, uint256){
        address pairAddress = IUniswapV2Factory(pancakeswapFactoryAddress).getPair(token1, token2);
        
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (uint Res0, uint Res1,) = pair.getReserves();
        
        address pairToken0 = pair.token0();
        if (pairToken0 == token1) {
            return (Res0, Res1);
        } else {
            return (Res1, Res0);
        }
    }

    /**
     * @dev Get BNB price in USD
     */
    function getBNBPrice() public view returns (uint256) {
        (uint256 bnbReserve, uint256 busdReserve) = getLiquidityInfo(wbnbAddress, busdAddress);
        return busdReserve.mul(10 ** 18).div(bnbReserve);
    }

    /**
     * @dev Get ArcadeDoge price in USD
     */
    function getRate() public view returns (uint256) {
        // (uint256 arcadedogeReserve, uint256 bnbReserve) = getLiquidityInfo(arcadedogeTokenAddress, wbnbAddress);
        // uint256 bnbPrice = getBNBPrice();
        // return bnbReserve.mul(bnbPrice).div(arcadedogeReserve);
        return 10 * 10 ** 18;
    }

    /** @dev convert address value to string value
     * @param account address value to convert
     * @return string converted string value
     */
    function toString(address account) private pure returns(string memory) {
        return toString(abi.encodePacked(account));
    }

    /** @dev convert bytes value to string value
     * @param data bytes value to convert
     * @return string converted string value
     */
    function toString(bytes memory data) private pure returns(string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    /** @dev convert byte32 to hex string
     * @param _bytes32 bytes32 data
     * @return string converted hex string
     */
    function bytes32ToString(bytes32 _bytes32) private pure returns (string memory) {
        uint8 i = 0;
        bytes memory bytesArray = new bytes(64);
        for (i = 0; i < bytesArray.length; i++) {

            uint8 _f = uint8(_bytes32[i/2] & 0x0f);
            uint8 _l = uint8(_bytes32[i/2] >> 4);

            bytesArray[i] = toByte(_l);
            i = i + 1;
            bytesArray[i] = toByte(_f);
        }
        return string(bytesArray);
    }

    /** @dev convert uint8 value to byte value
     * @param _uint8 uint8 value
     * @return byte converted byte value
     */
    function toByte(uint8 _uint8) private pure returns (bytes1) {
        if(_uint8 < 10) {
            return bytes1(_uint8 + 48);   
        } else {
            return bytes1(_uint8 + 87);
        }
    }
}