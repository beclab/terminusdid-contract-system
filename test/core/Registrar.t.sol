// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TerminusDID} from "../../src/core/TerminusDID.sol";
import {Registrar} from "../../src/core/Registrar.sol";
import {RootResolver} from "../../src/resolvers/RootResolver.sol";
import {CustomResolver} from "../../src/resolvers/examples/CustomResolver.sol";
import {DomainUtils} from "../../src/utils/DomainUtils.sol";
import {EmptyContract} from "../mocks/EmptyContract.sol";
import {InvalidCustomResolver} from "../mocks/InvalidCustomResolver.sol";
import {Metadata, MetadataRegistryUpgradeable} from "../../src/core/MetadataRegistryUpgradeable.sol";

contract RegistrarTest is Test {
    using DomainUtils for string;

    RootResolver public rootResolver;
    Registrar public registrar;
    TerminusDID public registryProxy;

    address operator = address(0xabc);
    address registrarOwner = address(this);

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

        registrar.setRegistry(address(registryProxy));
        registrar.setRootResolver(address(rootResolver));
    }

    function testBasis() public {
        assertEq(registrar.registry(), address(registryProxy));
        assertEq(registrar.rootResolver(), address(rootResolver));
        // only owner can set
        address notOwner = address(100);
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        registrar.setRootResolver(address(200));
        vm.prank(registrarOwner);
        registrar.setRootResolver(address(200));
        assertEq(registrar.rootResolver(), address(200));
    }

    /*//////////////////////////////////////////////////////////////
                             Ownership test
    //////////////////////////////////////////////////////////////*/
    function testOwnership() public {
        assertEq(registrar.owner(), registrarOwner);

        address newOwner = address(100);
        // only cur owner can transfer ownership
        vm.prank(newOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, newOwner));
        registrar.transferOwnership(newOwner);
        vm.prank(address(this));
        registrar.transferOwnership(newOwner);

        assertEq(registrar.pendingOwner(), newOwner);

        // only new owner can accept the ownership transfer
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        registrar.acceptOwnership();
        vm.prank(newOwner);
        registrar.acceptOwnership();

        assertEq(registrar.owner(), newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                             Register test
    //////////////////////////////////////////////////////////////*/
    function testRegisterTopLevelDomain() public {
        address comOwner = address(100);

        // only operator can register top level domain
        string memory tld = "com";
        vm.prank(operator);
        registrar.register(comOwner, Metadata(tld, "did", "", true));

        uint256 comTokenId = tld.tokenId();

        Metadata memory metadataRet = registryProxy.getMetadata(comTokenId);

        assertEq(metadataRet.domain, tld);
        assertEq(metadataRet.did, "did");
        assertEq(metadataRet.notes, "");
        assertEq(metadataRet.allowSubdomain, true);

        address comOwnerRet = registryProxy.ownerOf(comTokenId);
        assertEq(comOwnerRet, comOwner);

        // non-operator cannot register TLD
        address noOperator = address(200);
        vm.prank(noOperator);
        vm.expectRevert(Registrar.Unauthorized.selector);
        registrar.register(comOwner, Metadata(tld, "did", "", true));
    }

    function testRegisterDomain() public {
        address comOwner = address(100);
        string memory tld = "com";
        vm.prank(operator);
        registrar.register(comOwner, Metadata(tld, "did", "", true));

        address testOwner = address(200);
        string memory subDomain = "test.com";
        vm.prank(comOwner);
        uint256 tokenId = registrar.register(testOwner, Metadata(subDomain, "did", "", true));

        Metadata memory metadataRet = registryProxy.getMetadata(tokenId);

        assertEq(subDomain, metadataRet.domain);
        assertEq("did", metadataRet.did);
        assertEq("", metadataRet.notes);
        assertEq(true, metadataRet.allowSubdomain);

        address testOwnerRet = registryProxy.ownerOf(tokenId);
        assertEq(testOwner, testOwnerRet);
    }

    function testRegisterVeryLongDomainName() public {
        address comOwner = address(100);
        string memory tld = "com";
        vm.prank(operator);
        registrar.register(comOwner, Metadata(tld, "did", "", true));

        string memory domain;

        string memory subdomain1 =
            "BfvuSqXzxYOugu4ItmHF420hxvMh7ZUpCTu5nXxBPsylY0aob716jIeMO8qAlDmsFIEXdgfxsoyDr1zwtl8YQ6JS2AMZN1ByjCa6";
        domain = string.concat(subdomain1, ".", tld);
        vm.prank(comOwner);
        registrar.register(comOwner, Metadata(domain, "did", "", true));

        string memory subdomain2 =
            "ArOpJeAQhTcj8CORVbPWiGIAHfNNF0jVxLWncUIybZkBcXycLcWyNEHHxgH1Vuq9r1aOanZbUyg7EbWvUY9mCob99nAZNQMK7eCoXkwJXZffvzS68Cpw3CbALSjkqY8zBx6uAhZpsBQISnFUMoVLpadGmhutOPfHB8z9V7xyXIrR0tjTmSF2SGUqCqgJZAhF1a3pcd8X";
        domain = string.concat(subdomain2, ".", domain);
        vm.prank(comOwner);
        registrar.register(comOwner, Metadata(domain, "did", "", true));

        string memory subdomain3 =
            "aGg8fVMdCq5Crcobxw1pCF6Msn90yOuF00ZCzAeNLQ8NlNDHqp3jTJ2gxsGfJFbJQagB1jHuwpZDQAzXmRdEaATgEAUCjzdrXwIxBFC58QuOHo8F6qR5dwF0HwQTmiVi30Yvqx9B2LbXEiiSEhAIzCLrZBaApBY3u9YlxRQfGH0hMgcKfX4RnkbIAECPgbmd4rUiKd1uec0TrKL585lAIfE40uzMoDoFvt1RTPiV9FBv8djg1cUI9Zt9OoXgjQwGkVaPwsGnfcYFzbzjFstpj5cFc4gqkNTw3JSyltFR7LEn";
        domain = string.concat(subdomain3, ".", domain);
        vm.prank(comOwner);
        registrar.register(comOwner, Metadata(domain, "did", "", true));

        string memory subdomain4 =
            "dNEfHKqaXMp4MTovSt4D8osxq4oA2dv9C77AkHVoU2id2EuJp5AyQK5ghk2JMbWPdfP6O1r6KzyqQq8CqqLZk7GctJDhFz2dnBkQ8T9rQSTxlKhnyHucU3rIdgR9hgwQ8ucgz1bW0tBNFRm1Flnmw17KAyxtsmLALeuVltV4cuRL17pRfrgUO1FoAphRQiYYMKr50TZkqLSZiRfL9f8UXkCKUsy6yFcTJglOJyBJ63S1ib9dasBBPSbgn0108TN7SUJWhxVO71Hu0FFAeANTWNVPb0SVnormPxuQ9miTsX3pZdKxRaz5sEnQXncSJzEzryIpbcmdSfnnDzTpHfHwJlDI6YNDwYK17mmUtSqFibKhIwV9NXNRJDNI3h8bxYdAnwXhCdBDPPLTl4LI";
        domain = string.concat(subdomain4, ".", domain);
        vm.prank(comOwner);
        registrar.register(comOwner, Metadata(domain, "did", "", true));

        string memory subdomain5 =
            "7dIeu4gqYMz7JerElyQ2KaUqRe0NNfncGQsE6uYu9snVYaVRvDLobZpfdYpKP1Zy5kgwtQ2HwzgguNh7GoOc2KiThbWuOkyUaP2Vt9lBesfLNy4VB5hK8W0wK8NbTkD6FDxdpEAr9KlBpiBWSxnZB3VWyTSeillM94NmIo4MZ3a7GldgAqXM33cOFeMOq7BmDNHJRRoBlCkgjSEiN8fIK0KyhZYMND8GS1gwrdSwZCCLubPCqwidPh7UBCToRYhkLDctoUiYaEoNLUkbK487RqDVRPc1cqSCuVTA4dERnbdvNjy6dhk5ylvdYG9PgP2dNYYdpg6A8ro2V4g7jN0IP69zQn7qhI2exTGUZwCaaA5iwchMf0BbV9MOlzhwz1VWubbkrToP0F1AAXoYCLVo5XsUcWcN5SQutMXAipE6fejNR3niNFgsCmnZojat0BWYCbZ8zDjPV7wHVTo64lTJ3u3Lobk012tG9IDcLvrdzTKzLJ2Phxv9";
        domain = string.concat(subdomain5, ".", domain);
        vm.prank(comOwner);
        registrar.register(comOwner, Metadata(domain, "did", "", true));
    }

    function testRegisterChainDomains() public {
        string memory did = "did";

        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata("a", did, "", true));

        address bOwner = address(200);
        vm.prank(aOwner);
        registrar.register(bOwner, Metadata("b.a", did, "", true));

        address cOwner = address(300);
        vm.prank(bOwner);
        registrar.register(cOwner, Metadata("c.b.a", did, "", true));

        address dOwner = address(400);
        vm.prank(cOwner);
        registrar.register(dOwner, Metadata("d.c.b.a", did, "", true));

        address eOwner = address(500);
        vm.prank(dOwner);
        registrar.register(eOwner, Metadata("e.d.c.b.a", did, "", true));

        // ancestor domain owner can register child subdomains
        address fOwner = address(600);
        vm.prank(aOwner);
        registrar.register(fOwner, Metadata("f.e.d.c.b.a", did, "", true));

        // contract operator can register child sudbodmians
        address gOwner = address(700);
        vm.prank(operator);
        registrar.register(gOwner, Metadata("g.f.e.d.c.b.a", did, "", true));
    }

    function testRegisterUnauthorized() public {
        address aOwner = address(100);
        string memory did = "did";
        vm.prank(operator);
        registrar.register(aOwner, Metadata("a", did, "", true));

        // only aOwner or contract operator can register subdomain of "a"
        address notOwner = address(200);
        vm.prank(notOwner);
        vm.expectRevert(Registrar.Unauthorized.selector);
        registrar.register(notOwner, Metadata("b.a", did, "", true));
    }

    function testRegisterNotInOrder() public {
        address aOwner = address(100);
        string memory did = "did";
        vm.prank(operator);
        string memory domain;
        domain = "a";
        registrar.register(aOwner, Metadata(domain, did, "", true));

        // cannot register subdomains without direct parent domain
        domain = "c.b.a";
        string memory notExistParentDomain = "b.a";
        vm.prank(aOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, notExistParentDomain.tokenId())
        );
        registrar.register(aOwner, Metadata(domain, did, "", true));

        // even contract operator cannot register subdomains without direct parent domain
        vm.prank(operator);
        vm.expectRevert(MetadataRegistryUpgradeable.UnregisteredParentDomain.selector);
        registrar.register(aOwner, Metadata(domain, did, "", true));
    }

    function testRegisterNotAllowSubdomain() public {
        address aOwner = address(100);
        string memory did = "did";
        vm.prank(operator);
        registrar.register(aOwner, Metadata("a", did, "", true));

        // only allowSubdomain can have subdomains
        address bOwner = address(200);
        vm.prank(aOwner);
        registrar.register(bOwner, Metadata("b.a", did, "", false));

        address cOwner = address(300);
        vm.prank(bOwner);
        vm.expectRevert(MetadataRegistryUpgradeable.DisallowedSubdomain.selector);
        registrar.register(cOwner, Metadata("c.b.a", did, "", false));
    }

    /*//////////////////////////////////////////////////////////////
                             Set tag test
    //////////////////////////////////////////////////////////////*/
    function testSetTag() public {
        address aOwner = address(100);
        string memory did = "did";
        string memory domain = "a";
        vm.prank(operator);
        registrar.register(aOwner, Metadata(domain, did, "", true));

        uint256 key = 0x12;
        bytes memory value =
            hex"3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

        vm.prank(operator);
        registrar.setTag(domain, key, value);

        uint256 tokenId = domain.tokenId();
        (bool exists, bytes memory valueRet) = registryProxy.getTagValue(tokenId, key);

        assertEq(exists, true);
        assertEq(valueRet, value);
    }

    function testSetTagForMultiLevels() public {
        // set domian DNS A Record
        uint256 key = 0x13;
        bytes memory value = hex"c0a80101";
        string memory did = "did";

        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata("a", did, "", true));
        vm.prank(operator);
        registrar.setTag("a", key, value);

        address bOwner = address(200);
        vm.prank(operator);
        registrar.register(bOwner, Metadata("b.a", did, "", true));
        vm.prank(operator);
        registrar.setTag("b.a", key, value);

        address cOwner = address(300);
        vm.prank(operator);
        registrar.register(cOwner, Metadata("c.b.a", did, "", true));
        vm.prank(operator);
        registrar.setTag("c.b.a", key, value);

        address dOwner = address(400);
        vm.prank(operator);
        registrar.register(dOwner, Metadata("d.c.b.a", did, "", true));
        vm.prank(operator);
        registrar.setTag("d.c.b.a", key, value);

        address eOwner = address(500);
        vm.prank(operator);
        registrar.register(eOwner, Metadata("e.d.c.b.a", did, "", true));
        vm.prank(operator);
        registrar.setTag("e.d.c.b.a", key, value);
    }

    function testSetTagUnauthorized() public {
        uint256 key = 0x13;
        bytes memory value = hex"c0a80101";
        string memory did = "did";

        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata("a", did, "", true));

        address notOperator = address(200);
        vm.prank(notOperator);
        vm.expectRevert(Registrar.Unauthorized.selector);
        registrar.setTag("a", key, value);
    }

    function testSetTagToDomainNotExists() public {
        uint256 key = 0x13;
        bytes memory value = hex"c0a80101";
        string memory did = "did";

        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata("a", did, "", true));

        string memory notExistParentDomain = "b.a";
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, notExistParentDomain.tokenId())
        );
        registrar.setTag(notExistParentDomain, key, value);
    }

    /*//////////////////////////////////////////////////////////////
                             Other tools
    //////////////////////////////////////////////////////////////*/
    function testResolverOf() public {
        uint256 key = 0x13;
        bytes memory value = hex"c0a80101";
        string memory did = "did";

        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata("a", did, "", true));
        vm.prank(operator);
        registrar.setTag("a", key, value);

        address bOwner = address(200);
        vm.prank(operator);
        registrar.register(bOwner, Metadata("b.a", did, "", true));
        vm.prank(operator);
        registrar.setTag("b.a", key, value);

        address _resolver;
        _resolver = registrar.resolverOf("b.a", key);
        assertEq(_resolver, address(rootResolver));

        key = 0x14;
        _resolver = registrar.resolverOf("b.a", key);
        assertEq(_resolver, address(rootResolver));
    }

    function testSetCustomResolver() public {
        address aOwner = address(100);
        string memory did = "did";
        string memory domain = "a";
        vm.prank(operator);
        registrar.register(aOwner, Metadata(domain, did, "", true));

        CustomResolver customResolver = new CustomResolver(address(registrar), address(registryProxy));

        vm.prank(operator);
        vm.expectRevert(Registrar.Unauthorized.selector);
        registrar.setCustomResolver(domain, address(customResolver));

        vm.prank(aOwner);
        registrar.setCustomResolver(domain, address(customResolver));

        assertEq(registrar.customResolver(domain.tokenId()), address(customResolver));
    }

    function testSetInvalidCustomResolver() public {
        address aOwner = address(100);
        string memory did = "did";
        string memory domain = "a";
        vm.prank(operator);
        registrar.register(aOwner, Metadata(domain, did, "", true));

        EmptyContract emptyContract = new EmptyContract();
        vm.prank(aOwner);
        vm.expectRevert(abi.encodeWithSelector(Registrar.BadResolver.selector, address(emptyContract)));
        registrar.setCustomResolver(domain, address(emptyContract));

        InvalidCustomResolver invalidCustomResolver = new InvalidCustomResolver();
        vm.prank(aOwner);
        vm.expectRevert(abi.encodeWithSelector(Registrar.BadResolver.selector, address(invalidCustomResolver)));
        registrar.setCustomResolver(domain, address(invalidCustomResolver));
    }

    function testTraceOwner() public {
        string memory did = "did";

        address aOwner = address(100);
        vm.prank(operator);
        registrar.register(aOwner, Metadata("a", did, "", true));

        address bOwner = address(200);
        vm.prank(aOwner);
        registrar.register(bOwner, Metadata("b.a", did, "", true));

        address cOwner = address(300);
        vm.prank(bOwner);
        registrar.register(cOwner, Metadata("c.b.a", did, "", true));

        address dOwner = address(400);
        vm.prank(cOwner);
        registrar.register(dOwner, Metadata("d.c.b.a", did, "", true));

        address testAddr;
        testAddr = address(500);
        uint256 domainLevel;
        uint256 ownedLevel;
        string memory ownedDomain;

        (domainLevel, ownedLevel, ownedDomain) = registrar.traceOwner("d.c.b.a", testAddr);
        assertEq(domainLevel, 4);
        assertEq(ownedLevel, 0);
        assertEq(ownedDomain, "");

        (domainLevel, ownedLevel, ownedDomain) = registrar.traceOwner("d.c.b.a", bOwner);
        assertEq(domainLevel, 4);
        assertEq(ownedLevel, 2);
        assertEq(ownedDomain, "b.a");
    }
}
