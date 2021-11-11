// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AccountUtils {
    /** 
     * @notice convert address value to string value
     * @param account address value to convert
     * @return string converted string value
     */
    function toString(address account) internal pure returns(string memory) {
        return _toString(abi.encodePacked(account));
    }

    /** 
     * @notice convert bytes value to string value
     * @param data bytes value to convert
     * @return string converted string value
     */
    function _toString(bytes memory data) private pure returns(string memory) {
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
}