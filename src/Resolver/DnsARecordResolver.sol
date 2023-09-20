// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/console.sol";
/*
DNS A record is represent by a bytes4, in which each byte represents a number range from 0 to 255.
The raw bytes data length must be 4
*/

contract DnsARecordResolver {
    function validate(bytes calldata data) public pure returns (bool) {
        if (data.length != 4) return false;
        return true;
    }

    function parse(bytes calldata data) public view returns (string memory) {
        require(data.length == 4, "bytes data length must be 4");
        console.logBytes(data);        
    }
}
