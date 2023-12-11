// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TerminusDID} from "../../src/core/TerminusDID.sol";
import {DomainUtils} from "../../src/utils/DomainUtils.sol";
import {ABI} from "../../src/utils/ABI.sol";
import {ERC721Receiver, ERC721InvalidReceiver} from "../mocks/ERC721Receiver.sol";
import {MockTerminusDID} from "../mocks/MockTerminusDID.sol";

contract TerminusDIDTest is Test {
    using DomainUtils for string;

    TerminusDID public terminusDID;
    TerminusDID public terminusDIDProxy;
    string _name = "TestTerminusDID";
    string _symbol = "TDID";
    address _deployer = address(this);
    address _operator = address(0xabcd);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ReceivedERC721Token(address indexed operator, address indexed from, uint256 indexed tokenId, bytes data);

    function setUp() public {
        terminusDID = new TerminusDID();
        bytes memory initData = abi.encodeWithSelector(TerminusDID.initialize.selector, _name, _symbol);
        ERC1967Proxy proxy = new ERC1967Proxy(address(terminusDID), initData);
        terminusDIDProxy = TerminusDID(address(proxy));

        terminusDIDProxy.setOperator(_operator);
    }

    function testBasis() public {
        assertEq(terminusDIDProxy.name(), _name);
        assertEq(terminusDIDProxy.symbol(), _symbol);
        assertEq(terminusDIDProxy.owner(), _deployer);
        assertEq(terminusDIDProxy.operator(), _operator);
    }

    function testSetOperator() public {
        // only owner can set operator
        address notOwner = address(100);
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        terminusDIDProxy.setOperator(_operator);

        address newOperator = address(200);
        terminusDIDProxy.setOperator(newOperator);
        assertEq(terminusDIDProxy.operator(), newOperator);
    }

    /*//////////////////////////////////////////////////////////////
                             Ownership test
    //////////////////////////////////////////////////////////////*/
    function testOwnership() public {
        assertEq(terminusDIDProxy.owner(), _deployer);

        address newOwner = address(100);
        // only current owner can transfer ownership
        vm.prank(newOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, newOwner));
        terminusDIDProxy.transferOwnership(newOwner);
        vm.prank(_deployer);
        terminusDIDProxy.transferOwnership(newOwner);

        // in pending status
        assertEq(terminusDIDProxy.pendingOwner(), newOwner);
        assertEq(terminusDIDProxy.owner(), _deployer);

        // only new owner can accept the ownership transfer
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _deployer));
        terminusDIDProxy.acceptOwnership();
        vm.prank(newOwner);
        terminusDIDProxy.acceptOwnership();

        assertEq(terminusDIDProxy.owner(), newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                             Upgrade test
    //////////////////////////////////////////////////////////////*/
    function testUpgradeImpl() public {
        MockTerminusDID newImpl = new MockTerminusDID();

        // only owner can upgrade
        address notOwner = address(200);
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        terminusDIDProxy.upgradeToAndCall(address(newImpl), "");

        // upgrade by owner
        vm.prank(_deployer);
        terminusDIDProxy.upgradeToAndCall(address(newImpl), "");

        MockTerminusDID proxy = MockTerminusDID(address(terminusDIDProxy));
        assertEq(proxy.getVersion(), "mock version");
    }

    /*//////////////////////////////////////////////////////////////
                             Register test
    //////////////////////////////////////////////////////////////*/

    function testRegister() public {
        string memory domain = "a";
        string memory did = "did";
        bool allowSubdomain = true;

        // register by operator
        address domainOwner = address(100);
        uint256 tokenIdCalc = uint256(keccak256(bytes(domain)));

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), domainOwner, tokenIdCalc);
        vm.prank(_operator);
        uint256 tokenId = terminusDIDProxy.register(domainOwner, TerminusDID.Metadata(domain, did, "", allowSubdomain));

        assertEq(tokenId, tokenIdCalc);

        TerminusDID.Metadata memory metadataRet = terminusDIDProxy.getMetadata(tokenId);

        assertEq(metadataRet.domain, domain);
        assertEq(metadataRet.did, did);
        assertEq(metadataRet.notes, "");
        assertEq(metadataRet.allowSubdomain, allowSubdomain);

        // register by parent domain owner
        string memory subdomain = "b.a";
        address subdomainOwner = address(200);
        uint256 tokenIdCalc1 = uint256(keccak256(bytes(subdomain)));
        vm.prank(domainOwner);
        uint256 tokenId1 =
            terminusDIDProxy.register(subdomainOwner, TerminusDID.Metadata(subdomain, did, "", allowSubdomain));

        assertEq(tokenId1, tokenIdCalc1);
        TerminusDID.Metadata memory metadataRet1 = terminusDIDProxy.getMetadata(tokenId1);
        assertEq(metadataRet1.domain, subdomain);
        assertEq(metadataRet1.did, did);
        assertEq(metadataRet1.notes, "");
        assertEq(metadataRet1.allowSubdomain, allowSubdomain);
    }

    function testRegisterTopLevelDomain() public {
        address comOwner = address(100);

        // only operator can register top level domain
        string memory tld = "com";
        vm.prank(_operator);
        terminusDIDProxy.register(comOwner, TerminusDID.Metadata(tld, "did", "", true));

        uint256 comTokenId = tld.tokenId();

        TerminusDID.Metadata memory metadataRet = terminusDIDProxy.getMetadata(comTokenId);

        assertEq(metadataRet.domain, tld);
        assertEq(metadataRet.did, "did");
        assertEq(metadataRet.notes, "");
        assertEq(metadataRet.allowSubdomain, true);

        address comOwnerRet = terminusDIDProxy.ownerOf(comTokenId);
        assertEq(comOwnerRet, comOwner);

        // non-operator cannot register TLD
        address noOperator = address(200);
        vm.prank(noOperator);
        vm.expectRevert(TerminusDID.Unauthorized.selector);
        terminusDIDProxy.register(comOwner, TerminusDID.Metadata(tld, "did", "", true));
    }

    function testRegisterSecondLevelDirectly() public {
        address owner = address(100);
        string memory secondLevelDomain = "max.io";
        string memory topLevelDomain = "io";

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(TerminusDID.register.selector, owner, TerminusDID.Metadata(topLevelDomain, "did", "", true));
        data[1] = abi.encodeWithSelector(TerminusDID.register.selector, owner, TerminusDID.Metadata(secondLevelDomain, "did", "", true));
        
        vm.prank(_operator);
        bytes[] memory ret = terminusDIDProxy.multicall(data);
        assertEq(ret.length, 2);
        assertEq(abi.decode(ret[0], (uint256)), topLevelDomain.tokenId());
        assertEq(abi.decode(ret[1], (uint256)), secondLevelDomain.tokenId());


        TerminusDID.Metadata memory metadataRet;
        address ownerRet;

        metadataRet = terminusDIDProxy.getMetadata(secondLevelDomain.tokenId());

        assertEq(metadataRet.domain, secondLevelDomain);
        assertEq(metadataRet.did, "did");
        assertEq(metadataRet.notes, "");
        assertEq(metadataRet.allowSubdomain, true);

        ownerRet = terminusDIDProxy.ownerOf(secondLevelDomain.tokenId());
        assertEq(ownerRet, owner);

        metadataRet = terminusDIDProxy.getMetadata(topLevelDomain.tokenId());

        assertEq(metadataRet.domain, topLevelDomain);
        assertEq(metadataRet.did, "did");
        assertEq(metadataRet.notes, "");
        assertEq(metadataRet.allowSubdomain, true);

        ownerRet = terminusDIDProxy.ownerOf(topLevelDomain.tokenId());
        assertEq(ownerRet, owner);
    }

    function testRegisterVeryLongDomainName() public {
        address comOwner = address(100);
        string memory tld = "com";
        vm.prank(_operator);
        terminusDIDProxy.register(comOwner, TerminusDID.Metadata(tld, "did", "", true));

        string memory domain;

        string memory subdomain1 =
            "BfvuSqXzxYOugu4ItmHF420hxvMh7ZUpCTu5nXxBPsylY0aob716jIeMO8qAlDmsFIEXdgfxsoyDr1zwtl8YQ6JS2AMZN1ByjCa6";
        domain = string.concat(subdomain1, ".", tld);
        vm.prank(comOwner);
        terminusDIDProxy.register(comOwner, TerminusDID.Metadata(domain, "did", "", true));

        string memory subdomain2 =
            "ArOpJeAQhTcj8CORVbPWiGIAHfNNF0jVxLWncUIybZkBcXycLcWyNEHHxgH1Vuq9r1aOanZbUyg7EbWvUY9mCob99nAZNQMK7eCoXkwJXZffvzS68Cpw3CbALSjkqY8zBx6uAhZpsBQISnFUMoVLpadGmhutOPfHB8z9V7xyXIrR0tjTmSF2SGUqCqgJZAhF1a3pcd8X";
        domain = string.concat(subdomain2, ".", domain);
        vm.prank(comOwner);
        terminusDIDProxy.register(comOwner, TerminusDID.Metadata(domain, "did", "", true));

        string memory subdomain3 =
            "aGg8fVMdCq5Crcobxw1pCF6Msn90yOuF00ZCzAeNLQ8NlNDHqp3jTJ2gxsGfJFbJQagB1jHuwpZDQAzXmRdEaATgEAUCjzdrXwIxBFC58QuOHo8F6qR5dwF0HwQTmiVi30Yvqx9B2LbXEiiSEhAIzCLrZBaApBY3u9YlxRQfGH0hMgcKfX4RnkbIAECPgbmd4rUiKd1uec0TrKL585lAIfE40uzMoDoFvt1RTPiV9FBv8djg1cUI9Zt9OoXgjQwGkVaPwsGnfcYFzbzjFstpj5cFc4gqkNTw3JSyltFR7LEn";
        domain = string.concat(subdomain3, ".", domain);
        vm.prank(comOwner);
        terminusDIDProxy.register(comOwner, TerminusDID.Metadata(domain, "did", "", true));

        string memory subdomain4 =
            "dNEfHKqaXMp4MTovSt4D8osxq4oA2dv9C77AkHVoU2id2EuJp5AyQK5ghk2JMbWPdfP6O1r6KzyqQq8CqqLZk7GctJDhFz2dnBkQ8T9rQSTxlKhnyHucU3rIdgR9hgwQ8ucgz1bW0tBNFRm1Flnmw17KAyxtsmLALeuVltV4cuRL17pRfrgUO1FoAphRQiYYMKr50TZkqLSZiRfL9f8UXkCKUsy6yFcTJglOJyBJ63S1ib9dasBBPSbgn0108TN7SUJWhxVO71Hu0FFAeANTWNVPb0SVnormPxuQ9miTsX3pZdKxRaz5sEnQXncSJzEzryIpbcmdSfnnDzTpHfHwJlDI6YNDwYK17mmUtSqFibKhIwV9NXNRJDNI3h8bxYdAnwXhCdBDPPLTl4LI";
        domain = string.concat(subdomain4, ".", domain);
        vm.prank(comOwner);
        terminusDIDProxy.register(comOwner, TerminusDID.Metadata(domain, "did", "", true));

        string memory subdomain5 =
            "7dIeu4gqYMz7JerElyQ2KaUqRe0NNfncGQsE6uYu9snVYaVRvDLobZpfdYpKP1Zy5kgwtQ2HwzgguNh7GoOc2KiThbWuOkyUaP2Vt9lBesfLNy4VB5hK8W0wK8NbTkD6FDxdpEAr9KlBpiBWSxnZB3VWyTSeillM94NmIo4MZ3a7GldgAqXM33cOFeMOq7BmDNHJRRoBlCkgjSEiN8fIK0KyhZYMND8GS1gwrdSwZCCLubPCqwidPh7UBCToRYhkLDctoUiYaEoNLUkbK487RqDVRPc1cqSCuVTA4dERnbdvNjy6dhk5ylvdYG9PgP2dNYYdpg6A8ro2V4g7jN0IP69zQn7qhI2exTGUZwCaaA5iwchMf0BbV9MOlzhwz1VWubbkrToP0F1AAXoYCLVo5XsUcWcN5SQutMXAipE6fejNR3niNFgsCmnZojat0BWYCbZ8zDjPV7wHVTo64lTJ3u3Lobk012tG9IDcLvrdzTKzLJ2Phxv9";
        domain = string.concat(subdomain5, ".", domain);
        vm.prank(comOwner);
        terminusDIDProxy.register(comOwner, TerminusDID.Metadata(domain, "did", "", true));
    }

    function testRegisterChainDomains() public {
        string memory did = "did";

        address aOwner = address(100);
        vm.prank(_operator);
        terminusDIDProxy.register(aOwner, TerminusDID.Metadata("a", did, "", true));

        address bOwner = address(200);
        vm.prank(aOwner);
        terminusDIDProxy.register(bOwner, TerminusDID.Metadata("b.a", did, "", true));

        address cOwner = address(300);
        vm.prank(bOwner);
        terminusDIDProxy.register(cOwner, TerminusDID.Metadata("c.b.a", did, "", true));

        address dOwner = address(400);
        vm.prank(cOwner);
        terminusDIDProxy.register(dOwner, TerminusDID.Metadata("d.c.b.a", did, "", true));

        address eOwner = address(500);
        vm.prank(dOwner);
        terminusDIDProxy.register(eOwner, TerminusDID.Metadata("e.d.c.b.a", did, "", true));

        // ancestor domain owner can register child subdomains
        address fOwner = address(600);
        vm.prank(aOwner);
        terminusDIDProxy.register(fOwner, TerminusDID.Metadata("f.e.d.c.b.a", did, "", true));

        // contract operator can register child sudbodmians
        address gOwner = address(700);
        vm.prank(_operator);
        terminusDIDProxy.register(gOwner, TerminusDID.Metadata("g.f.e.d.c.b.a", did, "", true));
    }

    function testFuzzRegisterNotByOperator(bool allowSubdomain) public {
        string memory domain = "a";
        string memory did = "did";
        address notOperator = address(1);
        address owner = address(100);

        vm.prank(notOperator);
        vm.expectRevert(abi.encodeWithSelector(TerminusDID.Unauthorized.selector));
        terminusDIDProxy.register(owner, TerminusDID.Metadata(domain, did, "", allowSubdomain));
    }

    function testFuzzRegisterDuplicateDomain(bool allowSubdomain) public {
        string memory domain = "a";
        string memory did = "did";
        address owner = address(100);
        TerminusDID.Metadata memory metadata = TerminusDID.Metadata(domain, did, "", allowSubdomain);

        vm.prank(_operator);
        terminusDIDProxy.register(owner, metadata);

        vm.expectRevert(TerminusDID.ExistentDomain.selector);
        vm.prank(_operator);
        terminusDIDProxy.register(owner, metadata);
    }

    function testFuzzRegisterToZeroAddressOwner(bool allowSubdomain) public {
        string memory domain = "a";
        string memory did = "did";
        address owner = address(0);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, owner));
        vm.prank(_operator);
        terminusDIDProxy.register(owner, TerminusDID.Metadata(domain, did, "", allowSubdomain));
    }

    function testFuzzRegisterWithoutParentDomain(bool allowSubdomain) public {
        string memory domain = "abc.xyz";
        string memory did = "did";
        address owner = address(100);

        vm.expectRevert(TerminusDID.UnregisteredParentDomain.selector);
        vm.prank(_operator);
        terminusDIDProxy.register(owner, TerminusDID.Metadata(domain, did, "", allowSubdomain));
    }

    function testRegisterToParentNotAllowSubdomain() public {
        string memory domain = "com";
        string memory did = "did";

        // register parent domain "com" with not allow subdomain
        address owner = address(100);
        bool allowSubdomain = false;
        vm.prank(_operator);
        terminusDIDProxy.register(owner, TerminusDID.Metadata(domain, did, "", allowSubdomain));

        // register subdomain fails
        string memory subDomain = "abc.com";

        vm.expectRevert(TerminusDID.DisallowedSubdomain.selector);
        vm.prank(_operator);
        terminusDIDProxy.register(owner, TerminusDID.Metadata(subDomain, did, "", allowSubdomain));
    }

    function testFuzzRegisterSpecialDomainLabel(bool allowSubdomain) public {
        address owner = address(100);
        string memory domain = "com.";
        string memory did = "did";

        vm.expectRevert(TerminusDID.UnregisteredParentDomain.selector);
        vm.prank(_operator);
        terminusDIDProxy.register(owner, TerminusDID.Metadata(domain, did, "", allowSubdomain));
    }

    function testFuzzRegisterInvalidDomainLabel(bool allowSubdomain) public {
        string memory domain = "\u0600";
        string memory did = "did";

        address owner = address(100);

        vm.expectRevert(TerminusDID.InvalidDomainLabel.selector);
        vm.prank(_operator);
        terminusDIDProxy.register(owner, TerminusDID.Metadata(domain, did, "", allowSubdomain));
    }

    function testFuzzRegisterEmptyDomain(bool allowSubdomain) public {
        address owner = address(100);
        string memory domain = "";
        string memory did = "did";

        vm.expectRevert(TerminusDID.InvalidDomainLabel.selector);
        vm.prank(_operator);
        terminusDIDProxy.register(owner, TerminusDID.Metadata(domain, did, "", allowSubdomain));
    }

    function testRegisterNotInOrder() public {
        address aOwner = address(100);
        string memory did = "did";
        vm.prank(_operator);
        string memory domain;
        domain = "a";
        terminusDIDProxy.register(aOwner, TerminusDID.Metadata(domain, did, "", true));

        // cannot register subdomains without direct parent domain
        domain = "c.b.a";
        string memory notExistParentDomain = "b.a";
        vm.prank(aOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, notExistParentDomain.tokenId())
        );
        terminusDIDProxy.register(aOwner, TerminusDID.Metadata(domain, did, "", true));

        // even contract operator cannot register subdomains without direct parent domain
        vm.prank(_operator);
        vm.expectRevert(TerminusDID.UnregisteredParentDomain.selector);
        terminusDIDProxy.register(aOwner, TerminusDID.Metadata(domain, did, "", true));
    }

    /*//////////////////////////////////////////////////////////////
                             Set tag test
    //////////////////////////////////////////////////////////////*/

    function testDefineTag() public {
        string memory domain = "domain";
        string memory tagName = "auth_addresses";
        // address[]
        bytes memory addressArrayType = ABI.arrayT(bytes.concat(ABI.addressT()));
        string[] memory fieldNames = new string[](0);

        // msg.sender is not operator nor domain owner
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, domain.tokenId()));
        terminusDID.defineTag(domain, tagName, addressArrayType, fieldNames);

        // if domain no exist, use operator
        vm.prank(_operator);
        terminusDID.defineTag(domain, tagName, addressArrayType, fieldNames);


        // if domain exist, use domain owner

    }

    // function testFuzzSetTag(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     uint256 key = 0x100;

    //     bytes memory value = bytes("elephant");

    //     bool addedOrRemoved = terminusDIDProxy.setTag(tokenId, key, value);
    //     assertEq(addedOrRemoved, true);

    //     uint256 tagCount = terminusDIDProxy.getTagCount(tokenId);
    //     assertEq(tagCount, 1);

    //     uint256[] memory tags = terminusDIDProxy.getTagKeys(tokenId);
    //     assertEq(tags.length, 1);
    //     assertEq(tags[0], key);

    //     (bool exists, bytes memory valueFromContract) = terminusDIDProxy.getTagValue(tokenId, key);
    //     assertEq(exists, true);
    //     assertEq(value, valueFromContract);
    // }

    // function testFuzzSetTagNotByRegistrar(bool allowSubdomain) public {
    //     address notRegistrar = address(1);
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     uint256 key = 0x100;

    //     bytes memory value = bytes("elephant");

    //     vm.prank(notRegistrar);
    //     vm.expectRevert(abi.encodeWithSelector(TerminusDID.UnauthorizedRegistrar.selector, notRegistrar));
    //     terminusDIDProxy.setTag(tokenId, key, value);
    // }

    // function testFuzzSetTagToNotExistedDomain(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     terminusDIDProxy.register(owner, metadata);

    //     uint256 key = 0x100;
    //     bytes memory value = bytes("elephant");

    //     string memory nonExistDomain = "hello.com";
    //     vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, nonExistDomain.tokenId()));
    //     terminusDIDProxy.setTag(nonExistDomain.tokenId(), key, value);
    // }

    // function testFuzzSetInvalidKey(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     // maximum allowed key 0xffffffff
    //     uint256 key = 0x100000000;
    //     vm.expectRevert(TagRegistryUpgradeable.InvalidTagKey.selector);
    //     terminusDIDProxy.setTag(tokenId, key, "value");
    // }

    // function testFuzzSetNonExistEmptyTag(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     uint256 key = 0x100;

    //     bool addedOrRemoved = terminusDIDProxy.setTag(tokenId, key, "");
    //     assertEq(addedOrRemoved, false);

    //     uint256 tagCount = terminusDIDProxy.getTagCount(tokenId);
    //     assertEq(tagCount, 0);

    //     (bool exists, bytes memory valueFromContract) = terminusDIDProxy.getTagValue(tokenId, key);
    //     assertEq(exists, false);
    //     assertEq(valueFromContract, "");
    // }

    // function testFuzzModityTag(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     uint256 key = 0x100;

    //     bytes memory value = bytes("elephant");

    //     bool addedOrRemoved;
    //     addedOrRemoved = terminusDIDProxy.setTag(tokenId, key, value);
    //     assertEq(addedOrRemoved, true);

    //     bytes memory newValue = bytes("tiger");

    //     addedOrRemoved = terminusDIDProxy.setTag(tokenId, key, newValue);
    //     // update is not added or removed
    //     assertEq(addedOrRemoved, false);

    //     (bool exists, bytes memory valueFromContract) = terminusDIDProxy.getTagValue(tokenId, key);
    //     assertEq(exists, true);
    //     assertEq(newValue, valueFromContract);
    // }

    // function testFuzzDeleteTag(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     uint256 key = 0x100;

    //     bytes memory value = bytes("elephant");

    //     bool addedOrRemoved;
    //     addedOrRemoved = terminusDIDProxy.setTag(tokenId, key, value);
    //     assertEq(addedOrRemoved, true);
    //     uint256[] memory keys;
    //     keys = terminusDIDProxy.getTagKeys(tokenId);
    //     assertEq(keys.length, 1);

    //     bytes memory newValue = "";
    //     addedOrRemoved = terminusDIDProxy.setTag(tokenId, key, newValue);
    //     assertEq(addedOrRemoved, true);

    //     (bool exists, bytes memory valueFromContract) = terminusDIDProxy.getTagValue(tokenId, key);
    //     assertEq(exists, false);
    //     assertEq(newValue, valueFromContract);

    //     keys = terminusDIDProxy.getTagKeys(tokenId);
    //     assertEq(keys.length, 0);
    // }

    // function testFuzzDeleteTagMoveIndex(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     terminusDIDProxy.setTag(tokenId, 0x100, bytes("CN"));
    //     terminusDIDProxy.setTag(tokenId, 0x101, bytes("M"));
    //     terminusDIDProxy.setTag(tokenId, 0x102, bytes("beijing"));
    //     terminusDIDProxy.setTag(tokenId, 0x103, bytes("haidian"));

    //     terminusDIDProxy.setTag(tokenId, 0x101, "");
    //     uint256[] memory keys = terminusDIDProxy.getTagKeys(tokenId);
    //     assertEq(keys.length, 3);
    //     for (uint256 index; index < keys.length; index++) {
    //         assertNotEq(keys[index], 0x101);
    //     }

    //     (bool exists, bytes memory value) = terminusDIDProxy.getTagValue(tokenId, 0x101);
    //     assertEq(exists, false);
    //     assertEq(value, "");
    // }
      // /*//////////////////////////////////////////////////////////////
    //                          Set tag test
    // //////////////////////////////////////////////////////////////*/
    // function testSetTag() public {
    //     address aOwner = address(100);
    //     string memory did = "did";
    //     string memory domain = "a";
    //     vm.prank(operator);
    //     registrar.register(aOwner, Metadata(domain, did, "", true));

    //     uint256 key = 0x12;
    //     bytes memory value =
    //         hex"3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

    //     vm.prank(operator);
    //     registrar.setTag(domain, key, value);

    //     uint256 tokenId = domain.tokenId();
    //     bool exists;
    //     bytes memory valueRet;
    //     (exists, valueRet) = registryProxy.getTagValue(tokenId, key);

    //     assertEq(exists, true);
    //     assertEq(valueRet, value);

    //     // operator can set any tag, even not defined by resolver
    //     vm.prank(operator);
    //     registrar.setTag(domain, 0x100, bytes("little baby"));
    //     (exists, valueRet) = registryProxy.getTagValue(tokenId, 0x100);
    //     assertEq(exists, true);
    //     assertEq(valueRet, bytes("little baby"));

    //     // operator can delete tag
    //     vm.prank(operator);
    //     registrar.setTag(domain, 0x100, "");
    //     (exists, valueRet) = registryProxy.getTagValue(tokenId, 0x100);
    //     assertEq(exists, false);
    //     assertEq(valueRet, "");
    // }

    // function testSetTagForMultiLevels() public {
    //     // set domian DNS A Record
    //     uint256 key = 0x13;
    //     bytes memory value = hex"c0a80101";
    //     string memory did = "did";

    //     address aOwner = address(100);
    //     vm.prank(operator);
    //     registrar.register(aOwner, Metadata("a", did, "", true));
    //     vm.prank(operator);
    //     registrar.setTag("a", key, value);

    //     address bOwner = address(200);
    //     vm.prank(operator);
    //     registrar.register(bOwner, Metadata("b.a", did, "", true));
    //     vm.prank(operator);
    //     registrar.setTag("b.a", key, value);

    //     address cOwner = address(300);
    //     vm.prank(operator);
    //     registrar.register(cOwner, Metadata("c.b.a", did, "", true));
    //     vm.prank(operator);
    //     registrar.setTag("c.b.a", key, value);

    //     address dOwner = address(400);
    //     vm.prank(operator);
    //     registrar.register(dOwner, Metadata("d.c.b.a", did, "", true));
    //     vm.prank(operator);
    //     registrar.setTag("d.c.b.a", key, value);

    //     address eOwner = address(500);
    //     vm.prank(operator);
    //     registrar.register(eOwner, Metadata("e.d.c.b.a", did, "", true));
    //     vm.prank(operator);
    //     registrar.setTag("e.d.c.b.a", key, value);
    // }

    // function testSetTagUnauthorized() public {
    //     uint256 key = 0x13;
    //     bytes memory value = hex"c0a80101";
    //     string memory did = "did";

    //     address aOwner = address(100);
    //     vm.prank(operator);
    //     registrar.register(aOwner, Metadata("a", did, "", true));

    //     address notOperator = address(200);
    //     vm.prank(notOperator);
    //     vm.expectRevert(Registrar.Unauthorized.selector);
    //     registrar.setTag("a", key, value);
    // }

    // function testSetTagToDomainNotExists() public {
    //     uint256 key = 0x13;
    //     bytes memory value = hex"c0a80101";
    //     string memory did = "did";

    //     address aOwner = address(100);
    //     vm.prank(operator);
    //     registrar.register(aOwner, Metadata("a", did, "", true));

    //     string memory notExistParentDomain = "b.a";
    //     vm.prank(operator);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, notExistParentDomain.tokenId())
    //     );
    //     registrar.setTag(notExistParentDomain, key, value);
    // }

    // function testSetTagByResolver() public {
    //     address aOwner = address(100);
    //     string memory did = "did";
    //     string memory domain = "a";
    //     vm.prank(operator);
    //     registrar.register(aOwner, Metadata(domain, did, "", true));

    //     uint256 key = 0x12;
    //     bytes memory value =
    //         hex"3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

    //     vm.prank(address(rootResolver));
    //     registrar.setTag(domain, key, value);

    //     uint256 tokenId = domain.tokenId();
    //     (bool exists, bytes memory valueRet) = registryProxy.getTagValue(tokenId, key);

    //     assertEq(exists, true);
    //     assertEq(valueRet, value);
    // }

    /*//////////////////////////////////////////////////////////////
                             ERC721 test
    //////////////////////////////////////////////////////////////*/
    function testIsErc721() public {
        bytes4 erc721InterfaceId = bytes4(0x80ac58cd);
        assertEq(terminusDIDProxy.supportsInterface(erc721InterfaceId), true);
    }

    function testFuzzErc721Basis() public {
        string memory domain = "com";
        string memory did = "did";

        address owner = address(100);
        address zeroAddr = address(0);

        bool allowSubdomain = true;
        TerminusDID.Metadata memory metadata = TerminusDID.Metadata(domain, did, "", allowSubdomain);
        vm.prank(_operator);
        uint256 tokenId1 = terminusDIDProxy.register(owner, metadata);

        TerminusDID.Metadata memory metadata2 = TerminusDID.Metadata("test.com", did, "", allowSubdomain);
        vm.prank(_operator);
        uint256 tokenId2 = terminusDIDProxy.register(owner, metadata2);

        assertEq(terminusDIDProxy.balanceOf(owner), 2);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOwner.selector, zeroAddr));
        terminusDIDProxy.balanceOf(zeroAddr);

        assertEq(terminusDIDProxy.ownerOf(tokenId1), owner);
        assertEq(terminusDIDProxy.ownerOf(tokenId2), owner);

        assertEq(terminusDIDProxy.tokenURI(tokenId1), "");
        assertEq(terminusDIDProxy.tokenURI(tokenId2), "");

        assertEq(terminusDIDProxy.totalSupply(), 2);

        assertEq(terminusDIDProxy.tokenByIndex(0), tokenId1);
        assertEq(terminusDIDProxy.tokenByIndex(1), tokenId2);
        vm.expectRevert(abi.encodeWithSelector(ERC721Enumerable.ERC721OutOfBoundsIndex.selector, zeroAddr, 2));
        terminusDIDProxy.tokenByIndex(2);

        assertEq(terminusDIDProxy.tokenOfOwnerByIndex(owner, 0), tokenId1);
        assertEq(terminusDIDProxy.tokenOfOwnerByIndex(owner, 1), tokenId2);
        vm.expectRevert(abi.encodeWithSelector(ERC721Enumerable.ERC721OutOfBoundsIndex.selector, owner, 2));
        terminusDIDProxy.tokenOfOwnerByIndex(owner, 2);
    }

    function testFuzzErc721TransferByOwner(bool allowSubdomain) public {
        string memory domain = "com";
        string memory did = "did";

        address owner = address(100);
        TerminusDID.Metadata memory metadata = TerminusDID.Metadata(domain, did, "", allowSubdomain);
        vm.prank(_operator);
        uint256 tokenId = terminusDIDProxy.register(owner, metadata);

        assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

        address receiver = address(200);

        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit Transfer(owner, receiver, tokenId);
        terminusDIDProxy.transferFrom(owner, receiver, tokenId);

        assertEq(terminusDIDProxy.ownerOf(tokenId), receiver);
    }

    function testFuzzErc721TransferByApprover(bool allowSubdomain) public {
        string memory domain = "com";
        string memory did = "did";

        address owner = address(100);
        TerminusDID.Metadata memory metadata = TerminusDID.Metadata(domain, did, "", allowSubdomain);
        vm.prank(_operator);
        uint256 tokenId = terminusDIDProxy.register(owner, metadata);

        assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

        address receiver = address(200);

        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit Approval(owner, receiver, tokenId);
        terminusDIDProxy.approve(receiver, tokenId);
        assertEq(terminusDIDProxy.getApproved(tokenId), receiver);

        vm.prank(receiver);
        vm.expectEmit(true, true, true, false);
        emit Transfer(owner, receiver, tokenId);
        terminusDIDProxy.transferFrom(owner, receiver, tokenId);

        assertEq(terminusDIDProxy.ownerOf(tokenId), receiver);
    }

    function testFuzzErc721TransferByOperator(bool allowSubdomain) public {
        string memory domain = "com";
        string memory did = "did";

        address owner = address(100);
        TerminusDID.Metadata memory metadata = TerminusDID.Metadata(domain, did, "", allowSubdomain);
        vm.prank(_operator);
        uint256 tokenId = terminusDIDProxy.register(owner, metadata);

        assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

        address operator = address(200);
        address receiver = address(300);

        vm.prank(owner);
        terminusDIDProxy.setApprovalForAll(operator, true);
        assertEq(terminusDIDProxy.isApprovedForAll(owner, operator), true);

        vm.prank(operator);
        terminusDIDProxy.transferFrom(owner, receiver, tokenId);

        assertEq(terminusDIDProxy.ownerOf(tokenId), receiver);
    }

    function testFuzzErc721ApproveByOwner(bool allowSubdomain) public {
        string memory domain = "com";
        string memory did = "did";

        address owner = address(100);
        TerminusDID.Metadata memory metadata = TerminusDID.Metadata(domain, did, "", allowSubdomain);
        vm.prank(_operator);
        uint256 tokenId = terminusDIDProxy.register(owner, metadata);

        assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

        address receiver = address(200);

        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit Approval(owner, receiver, tokenId);
        terminusDIDProxy.approve(receiver, tokenId);
        assertEq(terminusDIDProxy.getApproved(tokenId), receiver);
    }

    function testFuzzErc721ApproveByOperator(bool allowSubdomain) public {
        string memory domain = "com";
        string memory did = "did";

        address owner = address(100);
        TerminusDID.Metadata memory metadata = TerminusDID.Metadata(domain, did, "", allowSubdomain);
        vm.prank(_operator);
        uint256 tokenId = terminusDIDProxy.register(owner, metadata);

        assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

        address operator = address(200);
        address receiver = address(300);

        vm.prank(owner);
        terminusDIDProxy.setApprovalForAll(operator, true);
        assertEq(terminusDIDProxy.isApprovedForAll(owner, operator), true);

        vm.prank(operator);
        terminusDIDProxy.approve(receiver, tokenId);
        assertEq(terminusDIDProxy.getApproved(tokenId), receiver);
    }

    function testFuzzErc721InvalidApprover(bool allowSubdomain) public {
        string memory domain = "com";
        string memory did = "did";

        address owner = address(100);
        TerminusDID.Metadata memory metadata = TerminusDID.Metadata(domain, did, "", allowSubdomain);
        vm.prank(_operator);
        uint256 tokenId = terminusDIDProxy.register(owner, metadata);

        assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

        address receiver = address(200);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidApprover.selector, address(this)));
        terminusDIDProxy.approve(receiver, tokenId);
    }

    function testErc721ApproveNotExistToken() public {
        address receiver = address(200);

        string memory notExistDomain = "test.com";

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, notExistDomain.tokenId()));
        terminusDIDProxy.approve(receiver, notExistDomain.tokenId());
    }

    function testFuzzErc721OperatorCannotBeZeroAddress(bool allowSubdomain) public {
        string memory domain = "com";
        string memory did = "did";

        address owner = address(100);
        TerminusDID.Metadata memory metadata = TerminusDID.Metadata(domain, did, "", allowSubdomain);
        vm.prank(_operator);
        uint256 tokenId = terminusDIDProxy.register(owner, metadata);

        assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

        address operator = address(0);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOperator.selector, operator));
        terminusDIDProxy.setApprovalForAll(operator, true);
    }

    function testFuzzErc721TransferInvalidParams(bool allowSubdomain) public {
        string memory domain = "com";
        string memory did = "did";

        address owner = address(100);
        TerminusDID.Metadata memory metadata = TerminusDID.Metadata(domain, did, "", allowSubdomain);
        vm.prank(_operator);
        uint256 tokenId = terminusDIDProxy.register(owner, metadata);

        address zeroAddress = address(0);
        address receiver = address(200);
        address notOwner = address(300);

        vm.prank(owner);
        terminusDIDProxy.approve(receiver, tokenId);

        vm.prank(receiver);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidSender.selector, zeroAddress));
        terminusDIDProxy.transferFrom(zeroAddress, receiver, tokenId);

        vm.prank(receiver);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, zeroAddress));
        terminusDIDProxy.transferFrom(owner, zeroAddress, tokenId);

        vm.prank(receiver);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721IncorrectOwner.selector, notOwner, tokenId, owner));
        terminusDIDProxy.transferFrom(notOwner, receiver, tokenId);

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, notOwner, tokenId));
        terminusDIDProxy.transferFrom(owner, receiver, tokenId);
    }

    function testErc721TransferOwnerFromMultipleNodes() public {
        string memory domain = "com";
        string memory did = "did";

        bool allowSubdomain = true;
        address owner = address(100);
        address receiver = address(200);

        vm.prank(_operator);
        uint256 tokenId1 = terminusDIDProxy.register(owner, TerminusDID.Metadata(domain, did, "", allowSubdomain));
        vm.prank(_operator);
        uint256 tokenId2 = terminusDIDProxy.register(owner, TerminusDID.Metadata("test1.com", did, "", allowSubdomain));
        vm.prank(_operator);
        uint256 tokenId3 = terminusDIDProxy.register(owner, TerminusDID.Metadata("test2.com", did, "", allowSubdomain));
        vm.prank(_operator);
        uint256 tokenId4 = terminusDIDProxy.register(owner, TerminusDID.Metadata("test3.com", did, "", allowSubdomain));
        assertEq(terminusDIDProxy.balanceOf(owner), 4);
        assertEq(terminusDIDProxy.ownerOf(tokenId1), owner);
        assertEq(terminusDIDProxy.ownerOf(tokenId2), owner);
        assertEq(terminusDIDProxy.ownerOf(tokenId3), owner);
        assertEq(terminusDIDProxy.ownerOf(tokenId4), owner);

        vm.prank(owner);
        terminusDIDProxy.transferFrom(owner, receiver, tokenId2);

        assertEq(terminusDIDProxy.balanceOf(owner), 3);
        for (uint256 index = 0; index < 3; index++) {
            uint256 tokenId = terminusDIDProxy.tokenOfOwnerByIndex(owner, index);
            assertNotEq(tokenId, tokenId2);
        }

        assertEq(terminusDIDProxy.balanceOf(receiver), 1);
        assertEq(terminusDIDProxy.tokenOfOwnerByIndex(receiver, 0), tokenId2);
    }

    function testFuzzErc721SafeTransferFrom(bool allowSubdomain) public {
        string memory domain = "com";
        string memory did = "did";

        ERC721Receiver receiver = new ERC721Receiver();

        address owner = address(100);
        vm.prank(_operator);
        uint256 tokenId = terminusDIDProxy.register(owner, TerminusDID.Metadata(domain, did, "", allowSubdomain));

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ReceivedERC721Token(owner, owner, tokenId, "");
        terminusDIDProxy.safeTransferFrom(owner, address(receiver), tokenId);
    }

    function testFuzzErc721SafeTransferFromWithInvalidReceiver(bool allowSubdomain) public {
        string memory domain = "com";
        string memory did = "did";

        ERC721InvalidReceiver receiver = new ERC721InvalidReceiver();

        address owner = address(100);
        vm.prank(_operator);
        uint256 tokenId = terminusDIDProxy.register(owner, TerminusDID.Metadata(domain, did, "", allowSubdomain));

        vm.prank(owner);
        vm.expectRevert("this is a invalid erc721 receiver");
        terminusDIDProxy.safeTransferFrom(owner, address(receiver), tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                             Other tools
    //////////////////////////////////////////////////////////////*/
    function testTraceOwner() public {
        string memory did = "did";

        address aOwner = address(100);
        vm.prank(_operator);
        terminusDIDProxy.register(aOwner, TerminusDID.Metadata("a", did, "", true));

        address bOwner = address(200);
        vm.prank(aOwner);
        terminusDIDProxy.register(bOwner, TerminusDID.Metadata("b.a", did, "", true));

        address cOwner = address(300);
        vm.prank(bOwner);
        terminusDIDProxy.register(cOwner, TerminusDID.Metadata("c.b.a", did, "", true));

        address dOwner = address(400);
        vm.prank(cOwner);
        terminusDIDProxy.register(dOwner, TerminusDID.Metadata("d.c.b.a", did, "", true));

        address testAddr;
        testAddr = address(500);
        uint256 domainLevel;
        uint256 ownedLevel;
        string memory ownedDomain;

        (domainLevel, ownedLevel, ownedDomain) = terminusDIDProxy.traceOwner("d.c.b.a", testAddr);
        assertEq(domainLevel, 4);
        assertEq(ownedLevel, 0);
        assertEq(ownedDomain, "");

        (domainLevel, ownedLevel, ownedDomain) = terminusDIDProxy.traceOwner("d.c.b.a", bOwner);
        assertEq(domainLevel, 4);
        assertEq(ownedLevel, 2);
        assertEq(ownedDomain, "b.a");
    }

    function testIsRegistered() public {
        string memory did = "did";

        address aOwner = address(100);
        vm.prank(_operator);
        terminusDIDProxy.register(aOwner, TerminusDID.Metadata("a", did, "", true));

        address bOwner = address(200);
        vm.prank(aOwner);
        terminusDIDProxy.register(bOwner, TerminusDID.Metadata("b.a", did, "", true));

        assertEq(terminusDIDProxy.isRegistered("a"), true);
        assertEq(terminusDIDProxy.isRegistered("b.a"), true);
        assertEq(terminusDIDProxy.isRegistered("c.b.a"), false);
    }
}
