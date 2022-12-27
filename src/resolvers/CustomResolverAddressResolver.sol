// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IResolver} from "./IResolver.sol";

/*
custom resolver is a contract address that exists parse and validate methods that work on keys beyond 0xffff
*/

contract CustomResolverAddressResolver {
    function customResolverAddressResolverValidate(bytes calldata data) public view returns (uint256) {
        if (data.length != 20) return 6;
        address customResolverAddress = address(uint160(bytes20(data)));
        uint256 testKey = 0xffff;

        (bool success, bytes memory returnData) =
            customResolverAddress.staticcall(abi.encodeWithSelector(IResolver.validate.selector, testKey, ""));
        if (!success) {
            return 7;
        }
        if (returnData.length < 32 || uint256(bytes32(returnData)) != 1) {
            return 8;
        }
        return 0;
    }

    function customResolverAddressResolverParse(bytes calldata data) public view returns (uint256, bytes memory) {
        uint256 status = customResolverAddressResolverValidate(data);
        if (status == 0) {
            address addr = address(uint160(bytes20(data)));
            bytes memory retData = abi.encode(addr);
            return (status, retData);
        } else {
            return (status, "");
        }
    }
}
