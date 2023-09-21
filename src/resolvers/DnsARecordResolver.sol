// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/*
DNS A record can be represent by 4 bytes, in which each byte represents a number range from 0 to 255.
The raw bytes data length must be 4
*/

contract DnsARecordResolver {
    function dnsARecordResolverValidate(bytes calldata data) public pure returns (uint256) {
        if (data.length != 4) return 4;
        return 0;
    }

    function dnsARecordResolverParse(bytes calldata data) public pure returns (uint256, bytes memory) {
        if (data.length != 4) return (4, "");
        uint8[] memory ip = new uint8[](4);
        for (uint256 index; index < 4; index++) {
            ip[index] = uint8(data[index]);
        }
        return (0, abi.encode(ip));
    }
}
