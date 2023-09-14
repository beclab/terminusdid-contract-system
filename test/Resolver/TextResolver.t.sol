// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {PublicResolver} from "../../src/Resolver/PublicResolver.sol";
import {Oracle} from "../../src/Oracle.sol";
import {Test} from "forge-std/Test.sol";

contract PublicResolverTest is Test {
    Oracle public oracle;
    PublicResolver public publicResolver;

    function setUp() public {
        oracle = new Oracle();
        publicResolver = new PublicResolver(address(oracle));
        oracle.addResolver(address(publicResolver));
    }

    function testSetTextAndGetText() public {
        string memory domain = "test.com";
        bytes32 node = keccak256(bytes(domain));
        string memory key = "custom:symbol";
        string memory value = "Tigers";
        publicResolver.setText(node, key, value);

        (string memory value2) = publicResolver.getText(node, key);
        assertEq(value, value2);
    }

    function testCannotSetInvalidKey() public {
        string memory domain = "test.com";
        bytes32 node = keccak256(bytes(domain));
        string memory key = "symbol";
        string memory value = "Tigers";
        vm.expectRevert(bytes("TextResolver: not a valid key, valid key should starts with 'custom:'"));
        publicResolver.setText(node, key, value);
    }
}
