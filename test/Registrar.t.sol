// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {TerminusDID} from "../src/TerminusDID.sol";
import {PublicResolver} from "../src/resolvers/PublicResolver.sol";
import {CustomResolver} from "../src/resolvers/examples/CustomResolver.sol";
import {Registrar} from "../src/Registrar.sol";
import {DomainUtils} from "../src/utils/DomainUtils.sol";
import {Permissions} from "../src/Permissions.sol";
import {EmptyContract} from "./mocks/EmptyContract.sol";
import {InvalidCustomResolver} from "./mocks/InvalidCustomResolver.sol";

contract RegistrarTest is Test {
    using DomainUtils for string;

    PublicResolver public resolver;
    Registrar public registrar;
    TerminusDID public registry;

    string _name = "TerminusDID";
    string _symbol = "TDID";

    function setUp() public {
        resolver = new PublicResolver();
        registrar = new Registrar(address(0), address(resolver));

        registry = new TerminusDID(_name, _symbol, address(registrar));
        registrar.setRegistry(address(registry));
    }

    function testBasis() public {
        assertEq(registrar.registry(), address(registry));
        assertEq(registrar.resolver(), address(resolver));
        // only owner can set
        address notOwner = address(100);
        vm.prank(notOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        registrar.setResolver(address(200));
        vm.prank(address(this));
        registrar.setResolver(address(200));
        assertEq(registrar.resolver(), address(200));
    }

    function testOwnership() public {
        assertEq(registrar.owner(), address(this));

        address newOwner = address(100);
        // only cur owner can transfer ownership
        vm.prank(newOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        registrar.transferOwnership(newOwner);
        vm.prank(address(this));
        registrar.transferOwnership(newOwner);

        assertEq(registrar.pendingOwner(), newOwner);

        // only new owner can accept the ownership transfer
        vm.expectRevert("Ownable2Step: caller is not the new owner");
        registrar.acceptOwnership();
        vm.prank(newOwner);
        registrar.acceptOwnership();

        assertEq(registrar.owner(), newOwner);
    }

    function testRegisterTld() public {
        // only owner can register TLD (top level domain)
        string memory tld = "com";
        address comOwner = address(100);
        string memory did = "did";

        registrar.registerTLD(tld, did, comOwner);

        uint256 comTokenId = tld.tokenId();

        (string memory domain_, string memory did_, address owner_, TerminusDID.Kind kind_) =
            registry.getMetaInfo(comTokenId);

        assertEq(domain_, tld);
        assertEq(did_, did);
        assertEq(owner_, comOwner);
        assertEq(uint8(kind_), uint8(TerminusDID.Kind.Organization));

        // non-owner cannot register TLD
        address noOwner = address(200);
        vm.prank(noOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        registrar.registerTLD("cn", did, address(400));
    }

    function testRegisterDomain() public {
        string memory tld = "com";
        address comOwner = address(100);
        string memory did = "did";
        registrar.registerTLD(tld, did, comOwner);

        string memory subdomain = "test";
        TerminusDID.Kind kind = TerminusDID.Kind.Organization;
        address testOwner = address(200);
        vm.prank(comOwner);
        registrar.register(subdomain, tld, did, testOwner, kind);

        string memory fullDomain = string.concat(subdomain, ".", tld);
        uint256 tokenId = fullDomain.tokenId();
        (string memory domain_, string memory did_, address owner_, TerminusDID.Kind kind_) =
            registry.getMetaInfo(tokenId);

        assertEq(domain_, fullDomain);
        assertEq(did_, did);
        assertEq(owner_, testOwner);
        assertEq(uint8(kind_), uint8(kind));
    }

    function testRegisterVeryLongDomainName() public {
        string memory tld = "com";
        address comOwner = address(100);
        string memory did = "did";
        registrar.registerTLD(tld, did, comOwner);

        address testOwner = address(200);
        TerminusDID.Kind kind = TerminusDID.Kind.Organization;

        string memory parentDomain = tld;
        string memory subdomain1 =
            "BfvuSqXzxYOugu4ItmHF420hxvMh7ZUpCTu5nXxBPsylY0aob716jIeMO8qAlDmsFIEXdgfxsoyDr1zwtl8YQ6JS2AMZN1ByjCa6";
        vm.prank(comOwner);
        registrar.register(subdomain1, parentDomain, did, testOwner, kind);

        parentDomain = string.concat(subdomain1, ".", parentDomain);
        string memory subdomain2 =
            "ArOpJeAQhTcj8CORVbPWiGIAHfNNF0jVxLWncUIybZkBcXycLcWyNEHHxgH1Vuq9r1aOanZbUyg7EbWvUY9mCob99nAZNQMK7eCoXkwJXZffvzS68Cpw3CbALSjkqY8zBx6uAhZpsBQISnFUMoVLpadGmhutOPfHB8z9V7xyXIrR0tjTmSF2SGUqCqgJZAhF1a3pcd8X";
        vm.prank(comOwner);
        registrar.register(subdomain2, parentDomain, did, testOwner, kind);

        parentDomain = string.concat(subdomain2, ".", parentDomain);
        string memory subdomain3 =
            "aGg8fVMdCq5Crcobxw1pCF6Msn90yOuF00ZCzAeNLQ8NlNDHqp3jTJ2gxsGfJFbJQagB1jHuwpZDQAzXmRdEaATgEAUCjzdrXwIxBFC58QuOHo8F6qR5dwF0HwQTmiVi30Yvqx9B2LbXEiiSEhAIzCLrZBaApBY3u9YlxRQfGH0hMgcKfX4RnkbIAECPgbmd4rUiKd1uec0TrKL585lAIfE40uzMoDoFvt1RTPiV9FBv8djg1cUI9Zt9OoXgjQwGkVaPwsGnfcYFzbzjFstpj5cFc4gqkNTw3JSyltFR7LEn";
        vm.prank(comOwner);
        registrar.register(subdomain3, parentDomain, did, testOwner, kind);

        parentDomain = string.concat(subdomain3, ".", parentDomain);
        string memory subdomain4 =
            "dNEfHKqaXMp4MTovSt4D8osxq4oA2dv9C77AkHVoU2id2EuJp5AyQK5ghk2JMbWPdfP6O1r6KzyqQq8CqqLZk7GctJDhFz2dnBkQ8T9rQSTxlKhnyHucU3rIdgR9hgwQ8ucgz1bW0tBNFRm1Flnmw17KAyxtsmLALeuVltV4cuRL17pRfrgUO1FoAphRQiYYMKr50TZkqLSZiRfL9f8UXkCKUsy6yFcTJglOJyBJ63S1ib9dasBBPSbgn0108TN7SUJWhxVO71Hu0FFAeANTWNVPb0SVnormPxuQ9miTsX3pZdKxRaz5sEnQXncSJzEzryIpbcmdSfnnDzTpHfHwJlDI6YNDwYK17mmUtSqFibKhIwV9NXNRJDNI3h8bxYdAnwXhCdBDPPLTl4LI";
        vm.prank(comOwner);
        registrar.register(subdomain4, parentDomain, did, testOwner, kind);

        parentDomain = string.concat(subdomain4, ".", parentDomain);
        string memory subdomain5 =
            "7dIeu4gqYMz7JerElyQ2KaUqRe0NNfncGQsE6uYu9snVYaVRvDLobZpfdYpKP1Zy5kgwtQ2HwzgguNh7GoOc2KiThbWuOkyUaP2Vt9lBesfLNy4VB5hK8W0wK8NbTkD6FDxdpEAr9KlBpiBWSxnZB3VWyTSeillM94NmIo4MZ3a7GldgAqXM33cOFeMOq7BmDNHJRRoBlCkgjSEiN8fIK0KyhZYMND8GS1gwrdSwZCCLubPCqwidPh7UBCToRYhkLDctoUiYaEoNLUkbK487RqDVRPc1cqSCuVTA4dERnbdvNjy6dhk5ylvdYG9PgP2dNYYdpg6A8ro2V4g7jN0IP69zQn7qhI2exTGUZwCaaA5iwchMf0BbV9MOlzhwz1VWubbkrToP0F1AAXoYCLVo5XsUcWcN5SQutMXAipE6fejNR3niNFgsCmnZojat0BWYCbZ8zDjPV7wHVTo64lTJ3u3Lobk012tG9IDcLvrdzTKzLJ2Phxv9";
        vm.prank(comOwner);
        registrar.register(subdomain5, parentDomain, did, testOwner, kind);
    }

    function testRegisterChainDomains() public {
        address aOwner = address(100);
        string memory did = "did";

        registrar.registerTLD("a", did, aOwner);

        address bOwner = address(200);
        vm.prank(aOwner);
        registrar.register("b", "a", did, bOwner, TerminusDID.Kind.Organization);

        address cOwner = address(300);
        vm.prank(bOwner);
        registrar.register("c", "b.a", did, cOwner, TerminusDID.Kind.Organization);

        address dOwner = address(400);
        vm.prank(cOwner);
        registrar.register("d", "c.b.a", did, dOwner, TerminusDID.Kind.Organization);

        address eOwner = address(500);
        vm.prank(dOwner);
        registrar.register("e", "d.c.b.a", did, eOwner, TerminusDID.Kind.Organization);

        // ancestor domain owner can register child subdomains
        address fOwner = address(600);
        vm.prank(aOwner);
        registrar.register("f", "e.d.c.b.a", did, fOwner, TerminusDID.Kind.Organization);

        // contract owner can register child sudbodmians
        address gOwner = address(700);
        vm.prank(address(this));
        registrar.register("g", "f.e.d.c.b.a", did, gOwner, TerminusDID.Kind.Organization);
    }

    function testRegisterUnauthorized() public {
        address aOwner = address(100);
        string memory did = "did";
        registrar.registerTLD("a", did, aOwner);

        // only aOwner or contract owner can register subdomain of "a"
        address notOwner = address(200);
        vm.prank(notOwner);
        vm.expectRevert(Registrar.Unauthorized.selector);
        registrar.register("b", "a", did, notOwner, TerminusDID.Kind.Organization);
    }

    function testRegisterNotInOrder() public {
        address aOwner = address(100);
        string memory did = "did";
        registrar.registerTLD("a", did, aOwner);

        // cannot register subdomains without direct parent domain
        vm.prank(aOwner);
        vm.expectRevert(Permissions.NonexistentDomain.selector);
        registrar.register("c", "b.a", did, aOwner, TerminusDID.Kind.Organization);

        // even contract owner cannot register subdomains without direct parent domain
        vm.prank(address(this));
        vm.expectRevert(Permissions.NonexistentDomain.selector);
        registrar.register("c", "b.a", did, aOwner, TerminusDID.Kind.Organization);
    }

    function testRegisterWithDiffrentKind() public {
        address aOwner = address(100);
        string memory did = "did";
        registrar.registerTLD("a", did, aOwner);

        // only kind = Organization can have subdomains
        address bOwner = address(200);
        vm.prank(aOwner);
        registrar.register("b", "a", did, bOwner, TerminusDID.Kind.Person);

        address cOwner = address(300);
        vm.prank(bOwner);
        vm.expectRevert(Registrar.InvalidParentKind.selector);
        registrar.register("c", "b.a", did, cOwner, TerminusDID.Kind.Person);

        address dOwner = address(400);
        vm.prank(aOwner);
        registrar.register("d", "a", did, dOwner, TerminusDID.Kind.Entity);

        address eOwner = address(500);
        vm.prank(dOwner);
        vm.expectRevert(Registrar.InvalidParentKind.selector);
        registrar.register("e", "d.a", did, eOwner, TerminusDID.Kind.Entity);
    }

    function testSetTag() public {
        address aOwner = address(100);
        string memory domain = "a";
        string memory did = "did";
        registrar.registerTLD(domain, did, aOwner);

        bytes8 key = bytes8(uint64(0x12));
        bytes memory value =
            hex"3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

        vm.prank(aOwner);
        registrar.setTag(domain, key, value);

        uint256 tokenId = domain.tokenId();
        (bool exists, bytes memory valueRet) = registry.getTagValue(tokenId, key);

        assertEq(exists, true);
        assertEq0(valueRet, value);
    }

    function testSetTagForMultiLevels() public {
        // set domian DNS A Record
        bytes8 key = bytes8(uint64(0x13));
        bytes memory value = hex"c0a80101";
        string memory did = "did";

        address aOwner = address(100);
        registrar.registerTLD("a", did, aOwner);

        registrar.setTag("a", key, value);

        address bOwner = address(200);
        vm.prank(aOwner);
        registrar.register("b", "a", did, bOwner, TerminusDID.Kind.Organization);
        vm.prank(bOwner);
        registrar.setTag("b.a", key, value);

        address cOwner = address(300);
        vm.prank(bOwner);
        registrar.register("c", "b.a", did, cOwner, TerminusDID.Kind.Organization);
        vm.prank(cOwner);
        registrar.setTag("c.b.a", key, value);

        address dOwner = address(400);
        vm.prank(cOwner);
        registrar.register("d", "c.b.a", did, dOwner, TerminusDID.Kind.Organization);
        vm.prank(dOwner);
        registrar.setTag("d.c.b.a", key, value);

        address eOwner = address(500);
        vm.prank(dOwner);
        registrar.register("e", "d.c.b.a", did, eOwner, TerminusDID.Kind.Person);
        vm.prank(eOwner);
        registrar.setTag("e.d.c.b.a", key, value);

        // ancestor domain owner can set tags for child subdomains
        vm.prank(aOwner);
        bytes8 key2 = bytes8(uint64(0x12));
        bytes memory value2 =
            hex"3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

        registrar.setTag("e.d.c.b.a", key2, value2);

        // contract owner owner can set/modify tags for child subdomains
        vm.prank(address(this));
        bytes memory value3 = hex"ffffffff";

        registrar.setTag("e.d.c.b.a", key, value3);
    }

    function testSetTagUnauthorized() public {
        bytes8 key = bytes8(uint64(0x13));
        bytes memory value = hex"c0a80101";
        string memory did = "did";

        address aOwner = address(100);
        registrar.registerTLD("a", did, aOwner);

        address notOwner = address(200);
        vm.prank(notOwner);
        vm.expectRevert(Registrar.Unauthorized.selector);
        registrar.setTag("a", key, value);
    }

    function testSetTagNotInOrder() public {
        bytes8 key = bytes8(uint64(0x13));
        bytes memory value = hex"c0a80101";
        string memory did = "did";

        address aOwner = address(100);
        registrar.registerTLD("a", did, aOwner);

        vm.prank(aOwner);
        vm.expectRevert(Permissions.NonexistentDomain.selector);
        registrar.setTag("b.a", key, value);
    }

    function testSetTagNotValidValue() public {
        bytes8 key = bytes8(uint64(0x13));
        bytes memory value = hex"c0a8010101";
        string memory did = "did";

        address aOwner = address(100);
        registrar.registerTLD("a", did, aOwner);

        vm.prank(aOwner);
        vm.expectRevert(abi.encodeWithSelector(Registrar.InvalidTagValue.selector, 4, address(resolver)));
        registrar.setTag("a", key, value);
    }

    function testSetTagNotValidKey() public {
        bytes8 key = bytes8(uint64(0x1300000000));
        bytes memory value = hex"c0a80101";
        string memory did = "did";

        address aOwner = address(100);
        registrar.registerTLD("a", did, aOwner);

        vm.prank(aOwner);
        vm.expectRevert(abi.encodeWithSelector(Registrar.UnsupportedTagKey.selector, key));
        registrar.setTag("a", key, value);
    }

    function testSetTagCustomResolver() public {
        address aOwner = address(100);
        string memory did = "did";
        string memory domain = "a";
        registrar.registerTLD(domain, did, aOwner);

        bytes8 key;
        bytes memory value;

        CustomResolver customResolver = new CustomResolver();
        key = bytes8(uint64(0x97));
        value = abi.encodePacked(address(customResolver));
        vm.prank(aOwner);
        registrar.setTag(domain, key, value);

        bool success;
        bytes memory dataRet;
        (success, dataRet) = registry.getTagValue(domain.tokenId(), key);
        assertEq(success, true);
        assertEq(address(customResolver), address(bytes20(dataRet)));

        // use custom resolver to store string and the key in custom resolver should bigger than 0xffff
        key = bytes8(uint64(0xffff01));
        value = bytes(unicode"君不见黄河之水天上来，奔流到海不复回。君不见高堂明镜悲白发，朝如青丝暮成雪");
        vm.prank(aOwner);
        registrar.setTag(domain, key, value);

        (success, dataRet) = registry.getTagValue(domain.tokenId(), key);
        assertEq(success, true);
        assertEq0(value, dataRet);
    }

    function testSetTagFromInvalidCustomResolver() public {
        address aOwner = address(100);
        string memory did = "did";
        string memory domain = "a";
        registrar.registerTLD(domain, did, aOwner);

        bytes8 key;
        bytes memory value;

        EmptyContract emptyContract = new EmptyContract();
        key = bytes8(uint64(0x97));
        value = abi.encodePacked(address(emptyContract));
        vm.prank(aOwner);
        vm.expectRevert(abi.encodeWithSelector(Registrar.InvalidTagValue.selector, 7, address(resolver)));
        registrar.setTag(domain, key, value);

        InvalidCustomResolver invalidCustomResolver = new InvalidCustomResolver();
        key = bytes8(uint64(0x97));
        value = abi.encodePacked(address(invalidCustomResolver));
        vm.prank(aOwner);
        vm.expectRevert(abi.encodeWithSelector(Registrar.InvalidTagValue.selector, 8, address(resolver)));
        registrar.setTag(domain, key, value);
    }
}
