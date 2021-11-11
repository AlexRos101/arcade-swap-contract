// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ByteUtils {
    /** 
     * @notice convert byte32 to hex string
     * @param _bytes32 bytes32 data
     * @return string converted hex string
     */
    function bytes32ToString(bytes32 _bytes32) 
        internal pure returns (string memory) {
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

    /** 
     * @notice convert uint8 value to byte value
     * @param _uint8 uint8 value
     * @return byte converted byte value
     */
    function toByte(uint8 _uint8) internal pure returns (bytes1) {
        if(_uint8 < 10) {
            return bytes1(_uint8 + 48);   
        } else {
            return bytes1(_uint8 + 87);
        }
    }
}