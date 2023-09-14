// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {PublicResolver} from "../../src/Resolver/PublicResolver.sol";
import {Oracle} from "../../src/Oracle.sol";
import {OracleType} from "../../src/OracleType.sol";
import {Test} from "forge-std/Test.sol";

contract MetaResolverTest is Test {
    Oracle public oracle;
    PublicResolver public publicResolver;

    function setUp() public {
        oracle = new Oracle();
        publicResolver = new PublicResolver(address(oracle));
        oracle.addResolver(address(publicResolver));
    }

    function testSetMetaAndGetMeta() public {
        string memory domain = "test.com";
        bytes32 node = keccak256(bytes(domain));
        string memory did =
            "did:key:z6Mknz6BQ4wo9YrBU7QAF5YZWyAyHABoLgmwugVJMaGp3QEr#fsNYfQ4yw5l1kFLCz3FqFD05MGAt9GDpseHWyUWxlT8";
        OracleType.InfoType nodeType = OracleType.InfoType.Person;
        publicResolver.setMeta(node, domain, did, msg.sender, nodeType);

        (string memory domain2, string memory did2, address owner2, OracleType.InfoType nodeType2) =
            publicResolver.getMeta(node);
        assertEq(domain, domain2);
        assertEq(did, did2);
        assertEq(msg.sender, owner2);
        assertEq(uint8(nodeType), uint8(nodeType2));
    }

    function testCannotSetMismatchedDomain() public {
        string memory domain = "test.com";
        bytes32 node = keccak256(bytes(domain));
        string memory mismatchedDomain = "task.com";
        string memory did =
            "did:key:z6Mknz6BQ4wo9YrBU7QAF5YZWyAyHABoLgmwugVJMaGp3QEr#fsNYfQ4yw5l1kFLCz3FqFD05MGAt9GDpseHWyUWxlT8";
        OracleType.InfoType nodeType = OracleType.InfoType.Person;
        vm.expectRevert(bytes("MetaResolver: domain name and hash mismatch"));
        publicResolver.setMeta(node, mismatchedDomain, did, msg.sender, nodeType);
    }
}
