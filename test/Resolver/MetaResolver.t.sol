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

    function testSetMetaAndGetMeta() public {
        string memory domainName = "test.com";
        bytes32 node = keccak256(bytes(domainName));
        string memory did =
            "did:key:z6Mknz6BQ4wo9YrBU7QAF5YZWyAyHABoLgmwugVJMaGp3QEr#fsNYfQ4yw5l1kFLCz3FqFD05MGAt9GDpseHWyUWxlT8";
        address owner = address(0x7364646167756f747468726565000000);
        OracleType.InfoType nodeType = OracleType.InfoType.Person;
        publicResolver.setMeta(node, did, owner, nodeType);

        (string memory did2, address owner2, OracleType.InfoType nodeType2) = publicResolver.getMeta(node);
        assertEq(did, did2);
        assertEq(owner, owner2);
        assertEq(uint8(nodeType), uint8(nodeType2));
    }
}
