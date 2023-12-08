// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TerminusDID} from "../../src/core/TerminusDID.sol";
import {DomainUtils} from "../../src/utils/DomainUtils.sol";
// import {Metadata, MetadataRegistryUpgradeable} from "../../src/core/MetadataRegistryUpgradeable.sol";
// import {TagRegistryUpgradeable} from "../../src/core/TagRegistryUpgradeable.sol";
import {ERC721Receiver, ERC721InvalidReceiver} from "../mocks/ERC721Receiver.sol";
import {MockTerminusDID} from "../mocks/MockTerminusDID.sol";

contract TerminusDIDTest is Test {
    // using DomainUtils for string;

    // TerminusDID public terminusDID;
    // TerminusDID public terminusDIDProxy;
    // string _name = "TerminusDID";
    // string _symbol = "TDID";
    // address _registrar = address(this);
    // address _deployer = address(this);

    // string _domain = "com";
    // string _did = "did:key:z6MkgUJW1QVWDKfmPpduShonrqMUXYvhw7brj8tbsSrzHquU#Hfu7JoVmWeQz3cfJrF2zhG7XP5z-smWOLFeP_OOghpM";

    // event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    // event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    // event ReceivedERC721Token(address indexed operator, address indexed from, uint256 indexed tokenId, bytes data);

    // function setUp() public {
    //     terminusDID = new TerminusDID();
    //     bytes memory initData = abi.encodeWithSelector(TerminusDID.initialize.selector, _name, _symbol);
    //     ERC1967Proxy proxy = new ERC1967Proxy(address(terminusDID), initData);
    //     terminusDIDProxy = TerminusDID(address(proxy));

    //     terminusDIDProxy.setRegistrar(_registrar);
    // }

    // function testBasis() public {
    //     assertEq(_name, terminusDIDProxy.name());
    //     assertEq(_symbol, terminusDIDProxy.symbol());
    //     assertEq(_deployer, terminusDIDProxy.owner());
    //     assertEq(_registrar, terminusDIDProxy.registrar());
    // }

    // /*//////////////////////////////////////////////////////////////
    //                          Ownership test
    // //////////////////////////////////////////////////////////////*/
    // function testOwnership() public {
    //     assertEq(terminusDIDProxy.owner(), _deployer);

    //     address newOwner = address(100);
    //     // only cur owner can transfer ownership
    //     vm.prank(newOwner);
    //     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, newOwner));
    //     terminusDIDProxy.transferOwnership(newOwner);
    //     vm.prank(_deployer);
    //     terminusDIDProxy.transferOwnership(newOwner);

    //     assertEq(terminusDIDProxy.pendingOwner(), newOwner);

    //     // only new owner can accept the ownership transfer
    //     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _deployer));
    //     terminusDIDProxy.acceptOwnership();
    //     vm.prank(newOwner);
    //     terminusDIDProxy.acceptOwnership();

    //     assertEq(terminusDIDProxy.owner(), newOwner);
    // }

    // /*//////////////////////////////////////////////////////////////
    //                          Upgrade test
    // //////////////////////////////////////////////////////////////*/
    // function testUpgradeImpl() public {
    //     MockTerminusDID newImpl = new MockTerminusDID();

    //     // only owner can upgrade
    //     address notOwner = address(200);
    //     vm.prank(notOwner);
    //     vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
    //     terminusDIDProxy.upgradeToAndCall(address(newImpl), "");

    //     // upgrade by owner
    //     vm.prank(_deployer);
    //     terminusDIDProxy.upgradeToAndCall(address(newImpl), "");

    //     MockTerminusDID proxy = MockTerminusDID(address(terminusDIDProxy));
    //     assertEq(proxy.getVersion(), "mock version");
    // }

    // /*//////////////////////////////////////////////////////////////
    //                          Register test
    // //////////////////////////////////////////////////////////////*/

    // function testFuzzRegister(bool allowSubdomain) public {
    //     address owner = address(100);
    //     uint256 tokenIdCalc = uint256(keccak256(bytes(_domain)));
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);

    //     vm.expectEmit(true, true, true, false);
    //     emit Transfer(address(0), owner, tokenIdCalc);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     assertEq(tokenId, tokenIdCalc);

    //     Metadata memory metadataRet = terminusDIDProxy.getMetadata(tokenId);

    //     assertEq(_domain, metadataRet.domain);
    //     assertEq(_did, metadataRet.did);
    //     assertEq("", metadataRet.notes);
    //     assertEq(allowSubdomain, metadataRet.allowSubdomain);
    // }

    // function testFuzzRegisterNotByRegistrar(bool allowSubdomain) public {
    //     address notRegistrar = address(1);
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);

    //     vm.prank(notRegistrar);
    //     vm.expectRevert(abi.encodeWithSelector(TerminusDID.UnauthorizedRegistrar.selector, notRegistrar));
    //     terminusDIDProxy.register(owner, metadata);
    // }

    // function testFuzzRegisterDuplicateDomain(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);

    //     terminusDIDProxy.register(owner, metadata);

    //     vm.expectRevert(MetadataRegistryUpgradeable.ExistentDomain.selector);
    //     terminusDIDProxy.register(owner, metadata);
    // }

    // function testFuzzRegisterToZeroAddressOwner(bool allowSubdomain) public {
    //     address owner = address(0);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);

    //     vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, owner));
    //     terminusDIDProxy.register(owner, metadata);
    // }

    // function testFuzzRegisterWithoutParentDomain(bool allowSubdomain) public {
    //     address owner = address(100);
    //     string memory domain = "abc.xyz";
    //     Metadata memory metadata = Metadata(domain, _did, "", allowSubdomain);

    //     vm.expectRevert(MetadataRegistryUpgradeable.UnregisteredParentDomain.selector);
    //     terminusDIDProxy.register(owner, metadata);
    // }

    // function testRegisterToParentNotAllowSubdomain() public {
    //     // register parent domain "com" with not allow subdomain
    //     address owner = address(100);
    //     bool allowSubdomain = false;
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     terminusDIDProxy.register(owner, metadata);

    //     // register subdomain fails
    //     string memory subDomain = "abc.com";
    //     Metadata memory newMetadata = Metadata(subDomain, _did, "", allowSubdomain);

    //     vm.expectRevert(MetadataRegistryUpgradeable.DisallowedSubdomain.selector);
    //     terminusDIDProxy.register(owner, newMetadata);
    // }

    // function testFuzzRegisterSpecialDomainLabel(bool allowSubdomain) public {
    //     address owner = address(100);
    //     string memory domain = "com.";
    //     Metadata memory metadata = Metadata(domain, _did, "", allowSubdomain);

    //     vm.expectRevert(MetadataRegistryUpgradeable.UnregisteredParentDomain.selector);
    //     terminusDIDProxy.register(owner, metadata);
    // }

    // function testFuzzRegisterInvalidDomainLabel(bool allowSubdomain) public {
    //     address owner = address(100);
    //     string memory domain = "\u0600";
    //     Metadata memory metadata = Metadata(domain, _did, "", allowSubdomain);

    //     vm.expectRevert(MetadataRegistryUpgradeable.InvalidDomainLabel.selector);
    //     terminusDIDProxy.register(owner, metadata);
    // }

    // function testFuzzRegisterEmptyDomain(bool allowSubdomain) public {
    //     address owner = address(100);
    //     string memory domain = "";
    //     Metadata memory metadata = Metadata(domain, _did, "", allowSubdomain);

    //     vm.expectRevert(MetadataRegistryUpgradeable.InvalidDomainLabel.selector);
    //     terminusDIDProxy.register(owner, metadata);
    // }

    // /*//////////////////////////////////////////////////////////////
    //                          Set tag test
    // //////////////////////////////////////////////////////////////*/

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
    //                          ERC721 test
    // //////////////////////////////////////////////////////////////*/
    // function testIsErc721() public {
    //     bytes4 erc721InterfaceId = bytes4(0x80ac58cd);
    //     assertEq(terminusDIDProxy.supportsInterface(erc721InterfaceId), true);
    // }

    // function testFuzzErc721Basis() public {
    //     address owner = address(100);
    //     address zeroAddr = address(0);

    //     bool allowSubdomain = true;
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId1 = terminusDIDProxy.register(owner, metadata);

    //     Metadata memory metadata2 = Metadata("test2.com", _did, "", allowSubdomain);
    //     uint256 tokenId2 = terminusDIDProxy.register(owner, metadata2);

    //     assertEq(terminusDIDProxy.balanceOf(owner), 2);

    //     vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOwner.selector, zeroAddr));
    //     terminusDIDProxy.balanceOf(zeroAddr);

    //     assertEq(terminusDIDProxy.ownerOf(tokenId1), owner);
    //     assertEq(terminusDIDProxy.ownerOf(tokenId2), owner);

    //     assertEq(terminusDIDProxy.tokenURI(tokenId1), _did);
    //     assertEq(terminusDIDProxy.tokenURI(tokenId2), _did);

    //     assertEq(terminusDIDProxy.totalSupply(), 2);

    //     assertEq(terminusDIDProxy.tokenByIndex(0), tokenId1);
    //     assertEq(terminusDIDProxy.tokenByIndex(1), tokenId2);
    //     vm.expectRevert(abi.encodeWithSelector(ERC721Enumerable.ERC721OutOfBoundsIndex.selector, zeroAddr, 2));
    //     terminusDIDProxy.tokenByIndex(2);

    //     assertEq(terminusDIDProxy.tokenOfOwnerByIndex(owner, 0), tokenId1);
    //     assertEq(terminusDIDProxy.tokenOfOwnerByIndex(owner, 1), tokenId2);
    //     vm.expectRevert(abi.encodeWithSelector(ERC721Enumerable.ERC721OutOfBoundsIndex.selector, owner, 2));
    //     terminusDIDProxy.tokenOfOwnerByIndex(owner, 2);
    // }

    // function testFuzzErc721TransferByOwner(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

    //     address receiver = address(200);

    //     vm.prank(owner);
    //     vm.expectEmit(true, true, true, false);
    //     emit Transfer(owner, receiver, tokenId);
    //     terminusDIDProxy.transferFrom(owner, receiver, tokenId);

    //     assertEq(terminusDIDProxy.ownerOf(tokenId), receiver);
    // }

    // function testFuzzErc721TransferByApprover(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

    //     address receiver = address(200);

    //     vm.prank(owner);
    //     vm.expectEmit(true, true, true, false);
    //     emit Approval(owner, receiver, tokenId);
    //     terminusDIDProxy.approve(receiver, tokenId);
    //     assertEq(terminusDIDProxy.getApproved(tokenId), receiver);

    //     vm.prank(receiver);
    //     vm.expectEmit(true, true, true, false);
    //     emit Transfer(owner, receiver, tokenId);
    //     terminusDIDProxy.transferFrom(owner, receiver, tokenId);

    //     assertEq(terminusDIDProxy.ownerOf(tokenId), receiver);
    // }

    // function testFuzzErc721TransferByOperator(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

    //     address operator = address(200);
    //     address receiver = address(300);

    //     vm.prank(owner);
    //     terminusDIDProxy.setApprovalForAll(operator, true);
    //     assertEq(terminusDIDProxy.isApprovedForAll(owner, operator), true);

    //     vm.prank(operator);
    //     terminusDIDProxy.transferFrom(owner, receiver, tokenId);

    //     assertEq(terminusDIDProxy.ownerOf(tokenId), receiver);
    // }

    // function testFuzzErc721ApproveByOwner(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

    //     address receiver = address(200);

    //     vm.prank(owner);
    //     vm.expectEmit(true, true, true, false);
    //     emit Approval(owner, receiver, tokenId);
    //     terminusDIDProxy.approve(receiver, tokenId);
    //     assertEq(terminusDIDProxy.getApproved(tokenId), receiver);
    // }

    // function testFuzzErc721ApproveByOperator(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

    //     address operator = address(200);
    //     address receiver = address(300);

    //     vm.prank(owner);
    //     terminusDIDProxy.setApprovalForAll(operator, true);
    //     assertEq(terminusDIDProxy.isApprovedForAll(owner, operator), true);

    //     vm.prank(operator);
    //     terminusDIDProxy.approve(receiver, tokenId);
    //     assertEq(terminusDIDProxy.getApproved(tokenId), receiver);
    // }

    // function testFuzzErc721InvalidApprover(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

    //     address receiver = address(200);

    //     vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidApprover.selector, address(this)));
    //     terminusDIDProxy.approve(receiver, tokenId);
    // }

    // function testErc721ApproveNotExistToken() public {
    //     address receiver = address(200);

    //     string memory notExistDomain = "test.com";

    //     vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, notExistDomain.tokenId()));
    //     terminusDIDProxy.approve(receiver, notExistDomain.tokenId());
    // }

    // function testFuzzErc721OperatorCannotBeZeroAddress(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     assertEq(terminusDIDProxy.ownerOf(tokenId), owner);

    //     address operator = address(0);

    //     vm.prank(owner);
    //     vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOperator.selector, operator));
    //     terminusDIDProxy.setApprovalForAll(operator, true);
    // }

    // function testFuzzErc721TransferInvalidParams(bool allowSubdomain) public {
    //     address owner = address(100);
    //     Metadata memory metadata = Metadata(_domain, _did, "", allowSubdomain);
    //     uint256 tokenId = terminusDIDProxy.register(owner, metadata);

    //     address zeroAddress = address(0);
    //     address receiver = address(200);
    //     address notOwner = address(300);

    //     vm.prank(owner);
    //     terminusDIDProxy.approve(receiver, tokenId);

    //     vm.prank(receiver);
    //     vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidSender.selector, zeroAddress));
    //     terminusDIDProxy.transferFrom(zeroAddress, receiver, tokenId);

    //     vm.prank(receiver);
    //     vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, zeroAddress));
    //     terminusDIDProxy.transferFrom(owner, zeroAddress, tokenId);

    //     vm.prank(receiver);
    //     vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721IncorrectOwner.selector, notOwner, tokenId, owner));
    //     terminusDIDProxy.transferFrom(notOwner, receiver, tokenId);

    //     vm.expectRevert(
    //         abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, address(this), tokenId)
    //     );
    //     terminusDIDProxy.transferFrom(owner, receiver, tokenId);
    // }

    // function testErc721TransferOwnerFromMultipleNodes() public {
    //     bool allowSubdomain = true;
    //     address owner = address(100);
    //     address receiver = address(200);

    //     uint256 tokenId1 = terminusDIDProxy.register(owner, Metadata(_domain, _did, "", allowSubdomain));
    //     uint256 tokenId2 = terminusDIDProxy.register(owner, Metadata("test1.com", _did, "", allowSubdomain));
    //     uint256 tokenId3 = terminusDIDProxy.register(owner, Metadata("test2.com", _did, "", allowSubdomain));
    //     uint256 tokenId4 = terminusDIDProxy.register(owner, Metadata("test3.com", _did, "", allowSubdomain));
    //     assertEq(terminusDIDProxy.balanceOf(owner), 4);
    //     assertEq(terminusDIDProxy.ownerOf(tokenId1), owner);
    //     assertEq(terminusDIDProxy.ownerOf(tokenId2), owner);
    //     assertEq(terminusDIDProxy.ownerOf(tokenId3), owner);
    //     assertEq(terminusDIDProxy.ownerOf(tokenId4), owner);

    //     vm.prank(owner);
    //     terminusDIDProxy.transferFrom(owner, receiver, tokenId2);

    //     assertEq(terminusDIDProxy.balanceOf(owner), 3);
    //     for (uint256 index = 0; index < 3; index++) {
    //         uint256 tokenId = terminusDIDProxy.tokenOfOwnerByIndex(owner, index);
    //         assertNotEq(tokenId, tokenId2);
    //     }

    //     assertEq(terminusDIDProxy.balanceOf(receiver), 1);
    //     assertEq(terminusDIDProxy.tokenOfOwnerByIndex(receiver, 0), tokenId2);
    // }

    // function testFuzzErc721SafeTransferFrom(bool allowSubdomain) public {
    //     ERC721Receiver receiver = new ERC721Receiver();

    //     address owner = address(100);
    //     uint256 tokenId = terminusDIDProxy.register(owner, Metadata(_domain, _did, "", allowSubdomain));

    //     vm.prank(owner);
    //     vm.expectEmit(true, true, true, true);
    //     emit ReceivedERC721Token(owner, owner, tokenId, "");
    //     terminusDIDProxy.safeTransferFrom(owner, address(receiver), tokenId);
    // }

    // function testFuzzErc721SafeTransferFromWithInvalidReceiver(bool allowSubdomain) public {
    //     ERC721InvalidReceiver receiver = new ERC721InvalidReceiver();

    //     address owner = address(100);
    //     uint256 tokenId = terminusDIDProxy.register(owner, Metadata(_domain, _did, "", allowSubdomain));

    //     vm.prank(owner);
    //     vm.expectRevert("this is a invalid erc721 receiver");
    //     terminusDIDProxy.safeTransferFrom(owner, address(receiver), tokenId);
    // }
}
