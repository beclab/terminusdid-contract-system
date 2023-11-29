// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {DomainUtils} from "../../src/utils/DomainUtils.sol";

contract DomainUtilsTest is Test {
    using DomainUtils for DomainUtils.Slice;
    using DomainUtils for string;

    string domain = "test.com";

    function testTokenId() public {
        uint256 tokenId = uint256(keccak256(bytes(domain)));
        assertEq(tokenId, domain.tokenId());
    }

    function testTokenIdFromSlice() public {
        DomainUtils.Slice slice = domain.asSlice();
        uint256 tokenId = uint256(keccak256(bytes(domain)));
        assertEq(tokenId, slice.tokenId());
    }

    function testIsEmpty() public {
        DomainUtils.Slice slice = domain.asSlice();
        assertEq(slice.isEmpty(), false);

        string memory emptyStr;
        DomainUtils.Slice slice2 = emptyStr.asSlice();
        assertEq(slice2.isEmpty(), true);
    }

    function testToString() public {
        DomainUtils.Slice slice = domain.asSlice();
        assertEq(domain, slice.toString());

        string memory domain2 = unicode"汤唯.中国";
        DomainUtils.Slice slice2 = domain2.asSlice();
        assertEq(domain2, slice2.toString());
    }

    function testParent() public {
        string memory subDomain = "a.test.com";
        DomainUtils.Slice parentSlice = subDomain.parent();
        DomainUtils.Slice slice = domain.asSlice();

        assertEq(slice.toString(), parentSlice.toString());

        string memory topDomain = "com";
        DomainUtils.Slice topDomainParent = topDomain.parent();
        assertEq(topDomainParent.toString(), "");
    }

    function testSplit() public {
        DomainUtils.Slice label;
        DomainUtils.Slice parentDomain;
        bool hasParent;
        (label, parentDomain, hasParent) = domain.cut();
        assertEq(true, hasParent);
        assertEq("test", label.toString());
        assertEq("com", parentDomain.toString());

        string memory subDomain;
        subDomain = "a.b.c.d.e.test.com";
        (label, parentDomain, hasParent) = subDomain.cut();
        assertEq(true, hasParent);
        assertEq("a", label.toString());
        assertEq("b.c.d.e.test.com", parentDomain.toString());

        subDomain = "a..test.com";
        (label, parentDomain, hasParent) = subDomain.cut();
        assertEq(true, hasParent);
        assertEq("a", label.toString());
        assertEq(".test.com", parentDomain.toString());

        subDomain = "a...test.com";
        (label, parentDomain, hasParent) = subDomain.cut();
        assertEq(true, hasParent);
        assertEq("a", label.toString());
        assertEq("..test.com", parentDomain.toString());

        subDomain = "com..";
        (label, parentDomain, hasParent) = subDomain.cut();
        assertEq(true, hasParent);
        assertEq("com", label.toString());
        assertEq(".", parentDomain.toString());

        subDomain = "com..";
        (label, parentDomain, hasParent) = subDomain.cut();
        assertEq(true, hasParent);
        assertEq("com", label.toString());
        assertEq(".", parentDomain.toString());

        subDomain = "com.";
        (label, parentDomain, hasParent) = subDomain.cut();
        assertEq(true, hasParent);
        assertEq("com", label.toString());
        assertEq("", parentDomain.toString());
    }

    function testTraceAllLevel() public {
        string memory subDomain;
        subDomain = "a.b.c.d.e.test.com";
        DomainUtils.Slice[] memory allLevels;
        allLevels = subDomain.allLevels();
        assertEq(allLevels.length, 7);
        assertEq(allLevels[0].toString(), "a.b.c.d.e.test.com");
        assertEq(allLevels[1].toString(), "b.c.d.e.test.com");
        assertEq(allLevels[2].toString(), "c.d.e.test.com");
        assertEq(allLevels[3].toString(), "d.e.test.com");
        assertEq(allLevels[4].toString(), "e.test.com");
        assertEq(allLevels[5].toString(), "test.com");
        assertEq(allLevels[6].toString(), "com");

        subDomain = unicode"汤唯.中国.test.com";
        allLevels = subDomain.allLevels();
        assertEq(allLevels.length, 4);
        assertEq(allLevels[0].toString(), unicode"汤唯.中国.test.com");
        assertEq(allLevels[1].toString(), unicode"中国.test.com");
        assertEq(allLevels[2].toString(), unicode"test.com");
        assertEq(allLevels[3].toString(), unicode"com");
    }

    function testValidLabel() public {
        bool isValidLabel;
        string memory label;

        label = "com";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, true);

        label = "baidu";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, true);

        label = "google";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, true);

        label = "jd";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, true);

        label = "test";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, true);

        label = "org";
        isValidLabel = label.isValidLabel();
        assertEq(isValidLabel, true);
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
