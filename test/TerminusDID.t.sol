// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {TerminusDID} from "../src/TerminusDID.sol";
import {IERC721EnumerableErrors} from "../src/IERC721EnumerableErrors.sol";
import {ERC721Receiver, ERC721InvalidReceiver} from "./mocks/ERC721Receiver.sol";

contract TerminusDIDTest is Test {
    TerminusDID public terminusDID;
    string _name = "TerminusDID";
    string _symbol = "TDID";
    address _manager = address(this);

    string _domain = "test.com";
    string _did = "did:key:z6MkgUJW1QVWDKfmPpduShonrqMUXYvhw7brj8tbsSrzHquU#Hfu7JoVmWeQz3cfJrF2zhG7XP5z-smWOLFeP_OOghpM";

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ReceivedERC721Token(address indexed operator, address indexed from, uint256 indexed tokenId, bytes data);

    function setUp() public {
        terminusDID = new TerminusDID(_name, _symbol, _manager);
    }

    function testBasis() public {
        assertEq(_name, terminusDID.name());
        assertEq(_symbol, terminusDID.symbol());
        assertEq(_manager, terminusDID.manager());
    }

    /*//////////////////////////////////////////////////////////////
                             Register test
    //////////////////////////////////////////////////////////////*/

    function testFuzzRegister(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenIdCalc = uint256(keccak256(bytes(_domain)));

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), owner, tokenIdCalc);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);

        assertEq(tokenId, tokenIdCalc);

        (string memory tDomain, string memory tDID, address tOwner, TerminusDID.Kind tKind) =
            terminusDID.getMetaInfo(tokenId);

        assertEq(_domain, tDomain);
        assertEq(_did, tDID);
        assertEq(owner, tOwner);
        assertEq(uint8(kind), uint8(tKind));
    }

    function testFuzzRegisterNotByManager(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address notManager = address(1);
        address owner = address(100);

        vm.prank(notManager);
        vm.expectRevert(TerminusDID.NotManager.selector);
        terminusDID.register(_domain, _did, owner, kind);
    }

    function testRegisterRevertByUnknownKind() public {
        address owner = address(100);
        TerminusDID.Kind kind = TerminusDID.Kind.Unknown;

        vm.expectRevert(TerminusDID.InvalidKind.selector);
        terminusDID.register(_domain, _did, owner, kind);
    }

    function testFuzzRegisterDuplicateDomain(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);

        terminusDID.register(_domain, _did, owner, kind);
        vm.expectRevert(TerminusDID.TokenExists.selector);
        terminusDID.register(_domain, _did, owner, kind);
    }

    function testFuzzRegisterToZeroAddressOwner(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(0);
        uint256 tokenIdCalc = uint256(keccak256(bytes(_domain)));

        vm.expectRevert(abi.encodeWithSelector(IERC721EnumerableErrors.ERC721NonexistentToken.selector, tokenIdCalc));
        terminusDID.register(_domain, _did, owner, kind);
    }

    /*//////////////////////////////////////////////////////////////
                             Set tag test
    //////////////////////////////////////////////////////////////*/

    function testFuzzSetTag(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);

        string memory keyStr = "nickname";
        bytes8 key = bytes8(keccak256(bytes(keyStr)));

        string memory valueStr = "elephant";
        bytes memory value = bytes(valueStr);

        bool addedOrRemoved = terminusDID.setTag(tokenId, key, value);
        assertEq(addedOrRemoved, true);

        uint256 tagCount = terminusDID.getTagCount(tokenId);
        assertEq(tagCount, 1);

        bytes8[] memory tags = terminusDID.getTagKeys(tokenId);
        assertEq(tags.length, 1);
        assertEq(tags[0], key);

        (bool exists, bytes memory valueFromContract) = terminusDID.getTagValue(tokenId, key);
        assertEq(exists, true);
        assertEq(value, valueFromContract);
        assertEq(valueStr, string(valueFromContract));
    }

    function testFuzzSetNonExistEmptyTag(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);

        string memory keyStr = "nickname";
        bytes8 key = bytes8(keccak256(bytes(keyStr)));

        bool addedOrRemoved = terminusDID.setTag(tokenId, key, "");
        assertEq(addedOrRemoved, false);

        uint256 tagCount = terminusDID.getTagCount(tokenId);
        assertEq(tagCount, 0);

        (bool exists, bytes memory valueFromContract) = terminusDID.getTagValue(tokenId, key);
        assertEq(exists, false);
        assertEq(valueFromContract, "");
    }

    function testFuzzModityTag(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);

        string memory keyStr = "nickname";
        bytes8 key = bytes8(keccak256(bytes(keyStr)));

        string memory valueStr = "elephant";
        bytes memory value = bytes(valueStr);

        bool addedOrRemoved;
        addedOrRemoved = terminusDID.setTag(tokenId, key, value);
        assertEq(addedOrRemoved, true);

        string memory newValueStr = "tiger";
        bytes memory newValue = bytes(newValueStr);

        addedOrRemoved = terminusDID.setTag(tokenId, key, newValue);
        // update is not added or removed
        assertEq(addedOrRemoved, false);

        (bool exists, bytes memory valueFromContract) = terminusDID.getTagValue(tokenId, key);
        assertEq(exists, true);
        assertEq(newValue, valueFromContract);
        assertEq(newValueStr, string(valueFromContract));
    }

    function testFuzzDeleteTag(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);

        string memory keyStr = "nickname";
        bytes8 key = bytes8(keccak256(bytes(keyStr)));

        string memory valueStr = "elephant";
        bytes memory value = bytes(valueStr);

        bool addedOrRemoved;
        addedOrRemoved = terminusDID.setTag(tokenId, key, value);
        assertEq(addedOrRemoved, true);
        bytes8[] memory keys;
        keys = terminusDID.getTagKeys(tokenId);
        assertEq(keys.length, 1);

        bytes memory newValue = "";
        addedOrRemoved = terminusDID.setTag(tokenId, key, newValue);
        assertEq(addedOrRemoved, true);

        (bool exists, bytes memory valueFromContract) = terminusDID.getTagValue(tokenId, key);
        assertEq(exists, false);
        assertEq(newValue, valueFromContract);

        keys = terminusDID.getTagKeys(tokenId);
        assertEq(keys.length, 0);
    }

    function testFuzzDeleteTagMoveIndex(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);

        terminusDID.setTag(tokenId, bytes8(keccak256(bytes("country"))), bytes("CN"));
        terminusDID.setTag(tokenId, bytes8(keccak256(bytes("gender"))), bytes("M"));
        terminusDID.setTag(tokenId, bytes8(keccak256(bytes("city"))), bytes("beijing"));
        terminusDID.setTag(tokenId, bytes8(keccak256(bytes("district"))), bytes("haidian"));

        terminusDID.setTag(tokenId, bytes8(keccak256(bytes("gender"))), "");
        bytes8[] memory keys = terminusDID.getTagKeys(tokenId);
        assertEq(keys.length, 3);
        for (uint256 index; index < keys.length; index++) {
            assertNotEq(keys[index], bytes8(keccak256(bytes("gender"))));
        }

        (bool exists, bytes memory value) = terminusDID.getTagValue(tokenId, bytes8(keccak256(bytes("gender"))));
        assertEq(exists, false);
        assertEq(value, "");
    }

    /*//////////////////////////////////////////////////////////////
                             ERC721 test
    //////////////////////////////////////////////////////////////*/
    function testIsErc721() public {
        bytes4 erc721InterfaceId = bytes4(0x80ac58cd);
        assertEq(terminusDID.supportsInterface(erc721InterfaceId), true);
    }

    function testFuzzErc721Basis(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        address zeroAddr = address(0);
        uint256 tokenId1 = terminusDID.register(_domain, _did, owner, kind);
        uint256 tokenId2 = terminusDID.register("test2.com", _did, owner, kind);

        assertEq(terminusDID.balanceOf(owner), 2);
        vm.expectRevert(abi.encodeWithSelector(IERC721EnumerableErrors.ERC721InvalidOwner.selector, zeroAddr));
        terminusDID.balanceOf(zeroAddr);

        assertEq(terminusDID.ownerOf(tokenId1), owner);
        assertEq(terminusDID.ownerOf(tokenId2), owner);

        assertEq(terminusDID.tokenURI(tokenId1), _did);
        assertEq(terminusDID.tokenURI(tokenId2), _did);

        assertEq(terminusDID.totalSupply(), 2);

        assertEq(terminusDID.tokenByIndex(0), tokenId1);
        assertEq(terminusDID.tokenByIndex(1), tokenId2);
        vm.expectRevert(abi.encodeWithSelector(IERC721EnumerableErrors.ERC721OutOfBoundsIndex.selector, zeroAddr, 2));
        terminusDID.tokenByIndex(2);

        assertEq(terminusDID.tokenOfOwnerByIndex(owner, 0), tokenId1);
        assertEq(terminusDID.tokenOfOwnerByIndex(owner, 1), tokenId2);
        vm.expectRevert(abi.encodeWithSelector(IERC721EnumerableErrors.ERC721OutOfBoundsIndex.selector, owner, 2));
        terminusDID.tokenOfOwnerByIndex(owner, 2);
    }

    function testFuzzErc721TransferByOwner(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);
        assertEq(terminusDID.ownerOf(tokenId), owner);

        address receiver = address(200);

        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit Transfer(owner, receiver, tokenId);
        terminusDID.transferFrom(owner, receiver, tokenId);

        assertEq(terminusDID.ownerOf(tokenId), receiver);
    }

    function testFuzzErc721TransferByApprover(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);
        assertEq(terminusDID.ownerOf(tokenId), owner);

        address receiver = address(200);

        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit Approval(owner, receiver, tokenId);
        terminusDID.approve(receiver, tokenId);
        assertEq(terminusDID.getApproved(tokenId), receiver);

        vm.prank(receiver);
        vm.expectEmit(true, true, true, false);
        emit Transfer(owner, receiver, tokenId);
        terminusDID.transferFrom(owner, receiver, tokenId);

        assertEq(terminusDID.ownerOf(tokenId), receiver);
    }

    function testFuzzErc721TransferByOperator(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);
        assertEq(terminusDID.ownerOf(tokenId), owner);

        address operator = address(200);
        address receiver = address(300);

        vm.prank(owner);
        terminusDID.setApprovalForAll(operator, true);
        assertEq(terminusDID.isApprovedForAll(owner, operator), true);

        vm.prank(operator);
        terminusDID.transferFrom(owner, receiver, tokenId);

        assertEq(terminusDID.ownerOf(tokenId), receiver);
    }

    function testFuzzErc721ApproveByOwner(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);
        assertEq(terminusDID.ownerOf(tokenId), owner);

        address receiver = address(200);

        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit Approval(owner, receiver, tokenId);
        terminusDID.approve(receiver, tokenId);
        assertEq(terminusDID.getApproved(tokenId), receiver);
    }

    function testFuzzErc721ApproveByOperator(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);
        assertEq(terminusDID.ownerOf(tokenId), owner);

        address operator = address(200);
        address receiver = address(300);

        vm.prank(owner);
        terminusDID.setApprovalForAll(operator, true);
        assertEq(terminusDID.isApprovedForAll(owner, operator), true);

        vm.prank(operator);
        terminusDID.approve(receiver, tokenId);
        assertEq(terminusDID.getApproved(tokenId), receiver);
    }

    function testFuzzErc721InvalidApprover(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);
        assertEq(terminusDID.ownerOf(tokenId), owner);

        address receiver = address(200);

        vm.expectRevert(abi.encodeWithSelector(IERC721EnumerableErrors.ERC721InvalidApprover.selector, address(this)));
        terminusDID.approve(receiver, tokenId);
    }

    function testFuzzErc721OperatorCannotBeZeroAddress(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);
        assertEq(terminusDID.ownerOf(tokenId), owner);

        address operator = address(0);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC721EnumerableErrors.ERC721InvalidOperator.selector, operator));
        terminusDID.setApprovalForAll(operator, true);
    }

    function testFuzzErc721TransferInvalidParams(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);

        address zeroAddress = address(0);
        address receiver = address(200);
        address notOwner = address(300);

        vm.prank(owner);
        terminusDID.approve(receiver, tokenId);

        vm.prank(receiver);
        vm.expectRevert(abi.encodeWithSelector(IERC721EnumerableErrors.ERC721InvalidSender.selector, zeroAddress));
        terminusDID.transferFrom(zeroAddress, receiver, tokenId);

        vm.prank(receiver);
        vm.expectRevert(abi.encodeWithSelector(IERC721EnumerableErrors.ERC721InvalidReceiver.selector, zeroAddress));
        terminusDID.transferFrom(owner, zeroAddress, tokenId);

        vm.prank(receiver);
        vm.expectRevert(
            abi.encodeWithSelector(IERC721EnumerableErrors.ERC721IncorrectOwner.selector, notOwner, tokenId, owner)
        );
        terminusDID.transferFrom(notOwner, receiver, tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(IERC721EnumerableErrors.ERC721InsufficientApproval.selector, address(this), tokenId)
        );
        terminusDID.transferFrom(owner, receiver, tokenId);
    }

    function testFuzzErc721TransferOwnerFromMultipleNodes(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        address owner = address(100);
        address receiver = address(200);

        uint256 tokenId1 = terminusDID.register(_domain, _did, owner, kind);
        uint256 tokenId2 = terminusDID.register("test2.com", _did, owner, kind);
        uint256 tokenId3 = terminusDID.register("test3.com", _did, owner, kind);
        uint256 tokenId4 = terminusDID.register("test4.com", _did, owner, kind);
        assertEq(terminusDID.balanceOf(owner), 4);
        assertEq(terminusDID.ownerOf(tokenId1), owner);
        assertEq(terminusDID.ownerOf(tokenId2), owner);
        assertEq(terminusDID.ownerOf(tokenId3), owner);
        assertEq(terminusDID.ownerOf(tokenId4), owner);

        vm.prank(owner);
        terminusDID.transferFrom(owner, receiver, tokenId2);
        assertEq(terminusDID.tokenOfOwnerByIndex(owner, 1), tokenId4);

        assertEq(terminusDID.ownerOf(tokenId2), receiver);
    }

    function testFuzzErc721SafeTransferFrom(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        ERC721Receiver receiver = new ERC721Receiver();

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ReceivedERC721Token(owner, owner, tokenId, "");
        terminusDID.safeTransferFrom(owner, address(receiver), tokenId);
    }

    function testFuzzErc721SafeTransferFromWithInvalidReceiver(uint256 kindNum) public {
        kindNum = bound(kindNum, 1, 3);
        TerminusDID.Kind kind = TerminusDID.Kind(kindNum);

        ERC721InvalidReceiver receiver = new ERC721InvalidReceiver();

        address owner = address(100);
        uint256 tokenId = terminusDID.register(_domain, _did, owner, kind);

        vm.prank(owner);
        vm.expectRevert("this is a invalid erc721 receiver");
        terminusDID.safeTransferFrom(owner, address(receiver), tokenId);
    }
}
