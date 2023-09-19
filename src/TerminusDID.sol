// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC165, ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {IERC721EnumerableErrors} from "./IERC721EnumerableErrors.sol";

contract TerminusDID is Context, ERC165, IERC721, IERC721Enumerable, IERC721Metadata, IERC721EnumerableErrors {
    enum Kind {
        Unknown,
        Person,
        Organization,
        Entity
    }

    struct Node {
        string domain;
        string did;
        address owner;
        uint40 index;
        uint40 indexByOwner;
        Kind kind;
        address approved;
    }

    struct TagGroup {
        bytes8[] keys;
        mapping(bytes8 key => bytes value) values;
    }

    string private _name;
    string private _symbol;

    uint256[] private _tokens;
    mapping(uint256 token => Node) private _nodes;
    mapping(uint256 token => TagGroup) private _tags;

    mapping(address owner => uint256[] tokens) private _ownedTokens;
    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;

    address private _manager;

    error NotManager();

    error InvalidKind();

    error TokenExists();

    error TooManyTokens();

    error TooManyTags();

    modifier onlyManager() {
        if (_msgSender() != _manager) {
            revert NotManager();
        }
        _;
    }

    constructor(string memory name_, string memory symbol_, address manager_) {
        _name = name_;
        _symbol = symbol_;
        _manager = manager_;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Enumerable).interfaceId
            || interfaceId == type(IERC721Metadata).interfaceId || super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                              DID Services
    //////////////////////////////////////////////////////////////*/

    function manager() public view returns (address) {
        return _manager;
    }

    function getNodeInfo(uint256 tokenId) public view returns (Node memory) {
        return _nodes[tokenId];
    }

    function getTagValue(uint256 tokenId, bytes8 key) public view returns (bool exists, bytes memory value) {
        (exists,, value) = _getTag(_tags[tokenId], key);
    }

    function getTagKeys(uint256 tokenId) public view returns (bytes8[] memory) {
        return _tags[tokenId].keys;
    }

    function getTagCount(uint256 tokenId) public view returns (uint256) {
        return _tags[tokenId].keys.length;
    }

    function setTag(uint256 tokenId, bytes8 key, bytes calldata value)
        public
        onlyManager
        returns (bool addedOrRemoved)
    {
        return _setTag(_tags[tokenId], key, value);
    }

    function register(string calldata domain, string calldata did, address owner, Kind kind)
        public
        onlyManager
        returns (uint256 tokenId)
    {
        // TODO: add extra validations?
        if (kind == Kind.Unknown) {
            revert InvalidKind();
        }
        tokenId = uint256(keccak256(bytes(domain)));
        if (_ownerOf(tokenId) != address(0)) {
            revert TokenExists();
        }
        _updateOwner(owner, tokenId);
        Node storage node = _nodes[tokenId];
        node.domain = domain;
        node.did = did;
        node.kind = kind;
    }

    /*//////////////////////////////////////////////////////////////
                             ERC721 Features
    //////////////////////////////////////////////////////////////*/

    function balanceOf(address owner) public view returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return _ownedTokens[owner].length;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        // TODO: get URI from tags?
        return _nodes[tokenId].did;
    }

    function totalSupply() public view returns (uint256) {
        return _tokens.length;
    }

    function tokenByIndex(uint256 index) public view returns (uint256) {
        if (index >= totalSupply()) {
            revert ERC721OutOfBoundsIndex(address(0), index);
        }
        return _tokens[index];
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        if (index >= balanceOf(owner)) {
            revert ERC721OutOfBoundsIndex(owner, index);
        }
        return _ownedTokens[owner][index];
    }

    function approve(address to, uint256 tokenId) public {
        address approver = _msgSender();
        address owner = ownerOf(tokenId);
        if (owner != approver && !isApprovedForAll(owner, approver)) {
            revert ERC721InvalidApprover(approver);
        }
        _nodes[tokenId].approved = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        if (_ownerOf(tokenId) == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return _getApproved(tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public {
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        address owner = _msgSender();
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (from == address(0)) {
            revert ERC721InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address owner = ownerOf(tokenId);
        if (owner != from) {
            revert ERC721IncorrectOwner(from, tokenId, owner);
        }
        address caller = _msgSender();
        if (owner != caller && !isApprovedForAll(owner, caller) && _getApproved(tokenId) != caller) {
            revert ERC721InsufficientApproval(caller, tokenId);
        }
        _updateOwner(to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    function _ownerOf(uint256 tokenId) internal view returns (address) {
        return _nodes[tokenId].owner;
    }

    function _getApproved(uint256 tokenId) internal view returns (address) {
        return _nodes[tokenId].approved;
    }

    function _updateOwner(address to, uint256 tokenId) internal returns (address) {
        Node memory node = _nodes[tokenId];
        address from = node.owner;

        if (from == address(0)) {
            if (to == address(0)) {
                revert ERC721NonexistentToken(tokenId);
            }
            uint256 nextIndex = _tokens.length;
            if (nextIndex > type(uint40).max) {
                revert TooManyTokens();
            }
            node.index = uint40(nextIndex);
            _tokens.push(tokenId);
        } else {
            uint256[] storage ownedTokens = _ownedTokens[from];
            uint256 srcIndex = ownedTokens.length - 1;
            uint40 dstIndex = node.indexByOwner;
            if (srcIndex != dstIndex) {
                uint256 srcToken = ownedTokens[srcIndex];
                ownedTokens[dstIndex] = srcToken;
                _nodes[srcToken].indexByOwner = dstIndex;
            }
            ownedTokens.pop();
            delete node.owner;
            // ERC721 standard seems to suggest not emitting Approval event on transfer
            delete node.approved;
        }

        if (to == address(0)) {
            uint256 srcIndex = _tokens.length - 1;
            uint40 dstIndex = node.index;
            if (srcIndex != dstIndex) {
                uint256 srcToken = _tokens[srcIndex];
                _tokens[dstIndex] = srcToken;
                _nodes[srcToken].index = dstIndex;
            }
            _tokens.pop();
            delete node.index;
            delete node.indexByOwner;
            node.kind = Kind.Unknown;
            _clearTags(tokenId);
        } else {
            uint256[] storage ownedTokens = _ownedTokens[to];
            node.indexByOwner = uint40(ownedTokens.length);
            ownedTokens.push(tokenId);
            node.owner = to;
        }

        _nodes[tokenId] = node;

        emit Transfer(from, to, tokenId);

        return from;
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    assembly ("memory-safe") {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function _clearTags(uint256 tokenId) internal {
        TagGroup storage tags = _tags[tokenId];
        uint256 length = tags.keys.length;
        for (uint256 i = 0; i < length; ++i) {
            delete tags.values[tags.keys[i]];
        }
        delete tags.keys;
    }

    function _getTag(TagGroup storage tags, bytes8 key)
        internal
        view
        returns (bool exists, uint16 index, bytes memory value)
    {
        value = tags.values[key];
        if (value.length == 0) {
            return (false, 0, "");
        }
        exists = true;
        assembly ("memory-safe") {
            index := and(0xffff, mload(add(value, mload(value))))
            mstore(value, sub(mload(value), 2))
        }
    }

    function _setTag(TagGroup storage tags, bytes8 key, bytes memory value) internal returns (bool addedOrRemoved) {
        (bool exists, uint16 index,) = _getTag(tags, key);
        if (value.length == 0) {
            if (exists) {
                uint256 moveIndex = tags.keys.length - 1;
                if (moveIndex != index) {
                    bytes8 moveKey = tags.keys[moveIndex];
                    tags.keys[index] = moveKey;
                    bytes storage moveValue = tags.values[moveKey];
                    uint256 lastByteIndex = moveValue.length - 1;
                    moveValue[lastByteIndex - 1] = bytes1(bytes2(index));
                    moveValue[lastByteIndex] = bytes1(uint8(index));
                }
                tags.keys.pop();
                delete tags.values[key];
                addedOrRemoved = true;
            }
            return;
        }
        if (!exists) {
            uint256 nextIndex = tags.keys.length;
            if (nextIndex > type(uint16).max) {
                revert TooManyTags();
            }
            index = uint16(nextIndex);
            tags.keys.push(key);
            addedOrRemoved = true;
        }
        tags.values[key] = bytes.concat(value, bytes2(index));
    }
}
