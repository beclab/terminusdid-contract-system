// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PublicResolver} from "../../src/Resolver/PublicResolver.sol";
import {Oracle} from "../../src/Oracle.sol";
import {OracleType} from "../../src/OracleType.sol";
import {Test, console2} from "forge-std/Test.sol";

contract MetaResolverTest is Test {
    Oracle public oracle;
    PublicResolver public publicResolver;

    function setUp() public {
        oracle = new Oracle();
        publicResolver = new PublicResolver(address(oracle));
        oracle.addResolver(address(publicResolver));
    }

    function testSetTextAndGetText() public view {
        publicResolver.setText("test");
    }
}
