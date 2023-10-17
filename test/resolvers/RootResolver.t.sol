// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RootResolver} from "../../src/resolvers/RootResolver.sol";
import {CustomResolver} from "../../src/resolvers/examples/CustomResolver.sol";
import {EmptyContract} from "../mocks/EmptyContract.sol";
import {InvalidCustomResolver} from "../mocks/InvalidCustomResolver.sol";
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

    function testSetRsaPubKey() public {
        bytes memory value =
            hex"3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

        string memory domain = "a";
        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata(domain, "did", "", true));

        vm.prank(operator);
        rootResolver.setRsaPubKey(domain, value);
        bytes memory valueRet = rootResolver.rsaPubKey(domain.tokenId());

        assertEq(value, valueRet);
    }

    function testSetInvalidRsaPubKey() public {
        bytes memory value =
            hex"3182010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata("a", "did", "", true));

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(RootResolver.Asn1DecodeError.selector, 4));
        rootResolver.setRsaPubKey("a", value);
    }

    function testSetDnsARecord() public {
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
    }
}
