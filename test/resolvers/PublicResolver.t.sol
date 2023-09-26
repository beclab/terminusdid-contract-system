// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {PublicResolver} from "../../src/resolvers/PublicResolver.sol";
import {CustomResolver} from "../../src/resolvers/examples/CustomResolver.sol";
import {EmptyContract} from "../mocks/EmptyContract.sol";
import {InvalidCustomResolver} from "../mocks/InvalidCustomResolver.sol";

contract TerminusDIDTest is Test {
    PublicResolver public publicResolver;
    CustomResolver public customResolver;

    function setUp() public {
        publicResolver = new PublicResolver();
        customResolver = new CustomResolver();
    }

    function testKeyGTPublicResolverLimit() public {
        uint64 _PUBLIC_KEY_LIMIT = uint64(type(uint16).max);
        uint64 keyNum = uint64(0x1234567);
        assertGt(keyNum, _PUBLIC_KEY_LIMIT);

        uint256 status = publicResolver.validate(bytes8(keyNum), "");
        assertEq(status, 1);
    }

    function testKeyNotImplYet() public {
        uint64 keyNum = uint64(0x7342);

        uint256 status = publicResolver.validate(bytes8(keyNum), "");
        assertEq(status, 2);
    }

    function testValidateRsaPubKey() public {
        bytes8 key = bytes8(uint64(0x12));
        bytes memory value =
            hex"3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

        uint256 status = publicResolver.validate(key, value);
        assertEq(status, 0);
    }

    function testParseRsaPubKey() public {
        bytes8 key = bytes8(uint64(0x12));
        bytes memory value =
            hex"3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

        (uint256 status, bytes memory parsed) = publicResolver.parse(key, value);
        assertEq(status, 0);

        (bytes memory modulus, uint256 publicExponent) = abi.decode(parsed, (bytes, uint256));
        assertEq(
            modulus,
            hex"cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f"
        );
        assertEq(publicExponent, 65537);
    }

    function testInvalidRsaPubKey() public {
        bytes8 key = bytes8(uint64(0x12));
        bytes memory value =
            hex"3182010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

        uint256 status = publicResolver.validate(key, value);
        assertEq(status, 5);
    }

    function testValidateAndParseIpARecord() public {
        bytes8 key = bytes8(uint64(0x13));
        bytes memory value;
        value = hex"ffffffff";

        uint256 status;
        status = publicResolver.validate(key, value);
        assertEq(status, 0);

        bytes memory parsed;
        (status, parsed) = publicResolver.parse(key, value);
        assertEq(status, 0);

        uint8[] memory ip = abi.decode(parsed, (uint8[]));
        assertEq(ip.length, 4);
        assertEq(ip[0], 255);
        assertEq(ip[1], 255);
        assertEq(ip[2], 255);
        assertEq(ip[3], 255);

        value = hex"0011223344";
        status = publicResolver.validate(key, value);
        assertEq(status, 4);
    }

    function testValiateCustomResolverAddress() public {
        bytes8 key = bytes8(uint64(0x97));
        bytes memory value = abi.encodePacked(address(customResolver));

        uint256 status;
        status = publicResolver.validate(key, value);
        assertEq(status, 0);
    }

    function testValiateWrongCustomResolver() public {
        bytes8 key = bytes8(uint64(0x97));
        bytes memory value;
        uint256 status;

        // wrong address length
        value = hex"123456";
        status = publicResolver.validate(key, value);
        assertEq(status, 6);

        // custom address is a empty contract
        EmptyContract emptyContract = new EmptyContract();
        value = abi.encodePacked(address(emptyContract));
        status = publicResolver.validate(key, value);
        assertEq(status, 7);

        // custom address is a invalid customer resolver
        InvalidCustomResolver invalidCustomResolver = new InvalidCustomResolver();
        value = abi.encodePacked(address(invalidCustomResolver));
        status = publicResolver.validate(key, value);
        assertEq(status, 8);
    }

    function testParseCustomResolverAddress() public {
        bytes8 key = bytes8(uint64(0x97));
        bytes memory value = abi.encodePacked(address(customResolver));

        (uint256 status, bytes memory value_) = publicResolver.parse(key, value);
        address valueParsed = abi.decode(value_, (address));
        assertEq(status, 0);
        assertEq(address(customResolver), valueParsed);
    }
}
