// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/*
DNS A record can be represent by 4 bytes, in which each byte represents a number range from 0 to 255.
The raw bytes data length must be 4
*/

contract DnsARecordResolver {
    function validate(bytes calldata data) public pure returns (bool) {
        if (data.length != 4) return false;
        return true;
    }

    function parse(bytes calldata data) public pure returns (uint8[] memory) {
        require(data.length == 4, "bytes data length must be 4");
        uint8[] memory ip = new uint8[](4);
        for (uint index; index<4; index++) {
            ip[index] = uint8(data[index]);
        }
        return ip;
    }
}
