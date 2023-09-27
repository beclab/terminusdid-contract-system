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

    function testInValidLabel() public {
        bool isValidLabel;
        string memory label;

        // empty string is not allowed
        label = "";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);

        // Unicode in Control Categories is not allowed
        label = "\u0001";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);

        // Unicode in Format Categories is not allowed
        label = "\u0600";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);

        // Unicode in Line Separator Categories is not allowed
        label = "\u2028";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);

        // Unicode in Paragraph Separator Categories is not allowed
        label = "\u2029";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);

        // Unicode in Space Separator Categories is not allowed
        label = "\u1680";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);

        // Full Stop (U+002E) is not allowed
        label = "\u002e";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);

        // Mongolian Free Variation Selectors (U+180B..U+180D) is not allowed
        label = "\u180B";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);

        // Variation Selectors (U+FE00..U+FE0F) is not allowed
        label = "\ufe00";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);

        // Replacement Characters (U+FFFC..U+FFFD) is not allowed
        label = "\ufffc";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);

        // Variation Selectors Supplement (U+E0100..U+E01EF) is not allowed
        label = "\ue0100";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);

        // valid rsa pubkey is not allowed
        bytes memory utf8encodedLabel =
            hex"3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";
        label = string(utf8encodedLabel);
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, false);
    }
}
