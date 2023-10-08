// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RootResolver} from "../../src/resolvers/RootResolver.sol";
import {CustomResolver} from "../../src/resolvers/examples/CustomResolver.sol";
import {BadCustomResolver} from "../mocks/BadCustomResolver.sol";
import {EmptyContract} from "../mocks/EmptyContract.sol";
import {TerminusDID} from "../../src/core/TerminusDID.sol";
import {Registrar} from "../../src/core/Registrar.sol";
import {Metadata} from "../../src/core/MetadataRegistryUpgradeable.sol";
import {DomainUtils} from "../../src/utils/DomainUtils.sol";

contract TerminusDIDTest is Test {
    using DomainUtils for string;

    RootResolver public rootResolver;
    CustomResolver public customResolver;

    Registrar public registrar;
    TerminusDID public registryProxy;
    address operator = address(0xabc);

    string _name = "TerminusDID";
    string _symbol = "TDID";

    function setUp() public {
        registrar = new Registrar(address(0), address(0), operator);

        TerminusDID registry = new TerminusDID();
        bytes memory initData = abi.encodeWithSelector(TerminusDID.initialize.selector, _name, _symbol);
        ERC1967Proxy proxy = new ERC1967Proxy(address(registry), initData);
        registryProxy = TerminusDID(address(proxy));
        registryProxy.setRegistrar(address(registrar));

        rootResolver = new RootResolver(address(registrar), address(registryProxy), operator);
        customResolver = new CustomResolver(address(registrar), address(registryProxy));

        registrar.setRegistry(address(registryProxy));
        registrar.setRootResolver(address(rootResolver));
    }

    function testBasis() public {
        assertEq(rootResolver.registrar(), address(registrar));
        assertEq(rootResolver.registry(), address(registryProxy));
        assertEq(rootResolver.operator(), operator);
    }

    function testKeyGTPublicResolverLimit() public {
        uint256 _ROOT_KEY_LIMIT = uint256(type(uint16).max);
        uint256 keyNum = 0x1234567;
        assertGt(keyNum, _ROOT_KEY_LIMIT);

        bytes4 selector = rootResolver.tagGetter(keyNum);
        assertEq(selector, bytes4(0));
    }

    function testKeyNotImplYet() public {
        uint256 keyNum = 0x7342;

        bytes4 selector = rootResolver.tagGetter(keyNum);
        assertEq(selector, bytes4(0xffffffff));
    }

    function testTagGetter() public {
        assertEq(rootResolver.tagGetter(0x12), rootResolver.rsaPubKey.selector);
        assertEq(rootResolver.tagGetter(0x13), rootResolver.dnsARecord.selector);
    }

    function testSetAndRemoveRsaPubKey() public {
        bytes memory value =
            hex"30819f300d06092a864886f70d010101050003818d0030818902818100ab42da3ee0bf48a1ddbf532f00878edec1407108f5ccea34cd90786729fff2df7122839b9c02ee1dcbbd580521a394b87c789e56a80785ab3aca088df45981bc7036f602f74d790df3c902f1ee97b8cd66cd69f2dd881048b8589703309ac679d1c6f2a17d00f2b9d4a27c5d2d5407a0e11829e0623d2a2deb03e2874d8286af0203010001";

        string memory domain = "a";
        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata(domain, "did", "", true));

        vm.prank(operator);
        rootResolver.setRsaPubKey(domain, value);
        bytes memory valueRet;
        valueRet = rootResolver.rsaPubKey(domain.tokenId());
        assertEq(value, valueRet);

        vm.prank(operator);
        rootResolver.setRsaPubKey(domain, "");
        assertEq(rootResolver.rsaPubKey(domain.tokenId()), "");

        (bool exists, bytes memory originData) = registryProxy.getTagValue(domain.tokenId(), 0x12);
        assertEq(exists, false);
        assertEq(originData, "");
    }

    function testSetInvalidRsaPubKey() public {
        bytes memory value =
            hex"3182010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata("a", "did", "", true));

        vm.prank(operator);
        vm.expectRevert(bytes("Asn1Decode: not type SEQUENCE STRING"));
        rootResolver.setRsaPubKey("a", value);
    }

    function testRemoveDnsARecord() public {
        bytes4 value;
        value = hex"ffffffff";

        string memory domain = "a";
        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata(domain, "did", "", true));

        vm.prank(operator);
        rootResolver.setDnsARecord(domain, value);

        bytes4 valueRet = rootResolver.dnsARecord(domain.tokenId());
        assertEq(value, valueRet);

        vm.prank(operator);
        rootResolver.setDnsARecord(domain, bytes4(0));
        assertEq(rootResolver.dnsARecord(domain.tokenId()), bytes4(0));

        (bool exists, bytes memory originData) = registryProxy.getTagValue(domain.tokenId(), 0x13);
        assertEq(exists, false);
        assertEq(originData, "");
    }

    function testAuthorizationCheck() public {
        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata("a", "did", "", true));

        address bOwner = address(200);
        vm.prank(operator);
        registrar.register(bOwner, Metadata("b.a", "did", "", true));

        string memory domain;

        domain = "b.a";
        vm.prank(operator);
        rootResolver.setDnsARecord(domain, hex"ffffffff");
        assertEq(rootResolver.dnsARecord(domain.tokenId()), hex"ffffffff");

        vm.prank(aOwner);
        rootResolver.setDnsARecord(domain, hex"ffffffaa");
        assertEq(rootResolver.dnsARecord(domain.tokenId()), hex"ffffffaa");

        vm.prank(bOwner);
        rootResolver.setDnsARecord(domain, hex"ffffffbb");
        assertEq(rootResolver.dnsARecord(domain.tokenId()), hex"ffffffbb");

        address notOwner = address(300);
        vm.prank(notOwner);
        vm.expectRevert(RootResolver.Unauthorized.selector);
        rootResolver.setDnsARecord(domain, hex"ffffffcc");
    }

    function testSetStaffId() public {
        string memory domain = "a";

        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata(domain, "did", "", true));

        vm.prank(aOwner);
        registrar.setCustomResolver(domain, address(customResolver));

        assertEq(registrar.customResolver(domain.tokenId()), address(customResolver));

        vm.prank(aOwner);
        customResolver.setStaffId(domain, 0x0001);
        assertEq(customResolver.staffId(domain.tokenId()), 0x0001);

        BadCustomResolver badCustomResolver = new BadCustomResolver(address(registrar), address(registryProxy));
        vm.prank(aOwner);
        registrar.setCustomResolver(domain, address(badCustomResolver));

        assertEq(registrar.customResolver(domain.tokenId()), address(badCustomResolver));

        vm.prank(aOwner);
        vm.expectRevert(Registrar.Unauthorized.selector);
        badCustomResolver.setStaffId(domain, 0x0001);

        vm.prank(aOwner);
        vm.expectRevert(abi.encodeWithSelector(Registrar.UnsupportedTag.selector, domain.tokenId(), 0xffff01));
        customResolver.setStaffId(domain, 0x0001);
    }
}
