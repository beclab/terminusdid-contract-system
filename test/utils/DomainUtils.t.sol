// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {DomainUtils} from "../../src/utils/DomainUtils.sol";

contract DomainUtilsTest is Test {
    using DomainUtils for uint256;
    using DomainUtils for string;

    string domain = "test.com";

    function testTokenId() public {
        uint256 tokenId = uint256(keccak256(bytes(domain)));
        assertEq(tokenId, domain.tokenId());
    }

    function testTokenIdFromSlice() public {
        uint256 slice = domain.asSlice();
        uint256 tokenId = uint256(keccak256(bytes(domain)));
        assertEq(tokenId, slice.tokenId());
    }

    function testIsEmpty() public {
        uint256 slice = domain.asSlice();
        assertEq(slice.isEmpty(), false);

        string memory emptyStr;
        uint256 slice2 = emptyStr.asSlice();
        assertEq(slice2.isEmpty(), true);
    }

    function testToString() public {
        uint256 slice = domain.asSlice();
        assertEq0(bytes(domain), bytes(slice.toString()));

        string memory domain2 = unicode"汤唯.中国";
        uint256 slice2 = domain2.asSlice();
        assertEq0(bytes(domain2), bytes(slice2.toString()));
    }

    function testParent() public {
        string memory subDomain = "a.test.com";
        uint256 parentSlice = subDomain.parent();
        uint256 slice = domain.asSlice();

        assertEq0(bytes(slice.toString()), bytes(parentSlice.toString()));

        string memory topDomain = "com";
        uint256 topDomainParent = topDomain.parent();
        assertEq0(bytes(topDomainParent.toString()), "");
    }

    function testTraceAllLevel() public {
        string memory subDomain;
        subDomain = "a.b.c.d.e";
        uint256[] memory parentSlices;
        parentSlices = subDomain.allLevels();
        assertEq(parentSlices.length, 5);
        assertEq(parentSlices[0].toString(), "a.b.c.d.e");
        assertEq(parentSlices[1].toString(), "b.c.d.e");
        assertEq(parentSlices[2].toString(), "c.d.e");
        assertEq(parentSlices[3].toString(), "d.e");
        assertEq(parentSlices[4].toString(), "e");

        subDomain = unicode"汤唯.中国";
        parentSlices = subDomain.allLevels();
        assertEq(parentSlices.length, 2);
        assertEq(parentSlices[0].toString(), unicode"汤唯.中国");
        assertEq(parentSlices[1].toString(), unicode"中国");
    }
}
