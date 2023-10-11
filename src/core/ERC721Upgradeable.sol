// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

abstract contract ERC721Upgradeable is
    Initializable,
    ContextUpgradeable,
    ERC165Upgradeable,
    IERC721,
    IERC721Enumerable,
    IERC721Metadata,
    IERC721Errors
{
    struct __ERC721_TokenData {
        address owner;
        uint40 index;
        uint40 indexByOwner;
        address approved;
    }

    /// @custom:storage-location erc7201:terminus.ERC721
    struct __ERC721_Storage {
        string _name;
        string _symbol;
        uint256[] _tokenIds;
        mapping(uint256 tokenId => __ERC721_TokenData) _tokens;
        mapping(address owner => uint256[] tokenIds) _tokenIdsByOwner;
        mapping(address owner => mapping(address operator => bool)) _operatorApprovals;
    }

    // keccak256(abi.encode(uint256(keccak256("terminus.ERC721")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant __ERC721_STORAGE = 0x04cc3b1160dff1f611a48ab325b162d9ef138626f346e30f670e6c29c03db600;

    error ERC721OutOfBoundsIndex(address owner, uint256 index);

    error ERC721ExistentToken(uint256 tokenId);

    function __ERC721_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC721_init_unchained(name_, symbol_);
    }

    function __ERC721_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC721_Storage storage $ = __ERC721_getStorage();
        $._name = name_;
        $._symbol = symbol_;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Upgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Enumerable).interfaceId
            || interfaceId == type(IERC721Metadata).interfaceId || super.supportsInterface(interfaceId);
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return __ERC721_getStorage()._tokenIdsByOwner[owner].length;
    }

    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return __ERC721_requireOwned(tokenId);
    }

    function name() public view virtual returns (string memory) {
        return __ERC721_getStorage()._name;
    }

    function symbol() public view virtual returns (string memory) {
        return __ERC721_getStorage()._symbol;
    }

    // function tokenURI(uint256 tokenId) should be implemented by derived contracts

    function totalSupply() public view virtual returns (uint256) {
        return __ERC721_getStorage()._tokenIds.length;
    }

    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        if (index >= totalSupply()) {
            revert ERC721OutOfBoundsIndex(address(0), index);
        }
        return __ERC721_getStorage()._tokenIds[index];
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual returns (uint256) {
        if (index >= balanceOf(owner)) {
            revert ERC721OutOfBoundsIndex(owner, index);
        }
        return __ERC721_getStorage()._tokenIdsByOwner[owner][index];
    }

    function approve(address to, uint256 tokenId) public virtual {
        address approver = _msgSender();
        address owner = __ERC721_requireOwned(tokenId);
        if (owner != approver && !isApprovedForAll(owner, approver)) {
            revert ERC721InvalidApprover(approver);
        }
        __ERC721_getStorage()._tokens[tokenId].approved = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual returns (address) {
        __ERC721_requireOwned(tokenId);
        return __ERC721_approved(tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        address owner = _msgSender();
        __ERC721_getStorage()._operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return __ERC721_getStorage()._operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (from == address(0)) {
            revert ERC721InvalidSender(address(0));
        }
        address previousOwner = __ERC721_transfer(to, tokenId);
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
        address caller = _msgSender();
        if (from != caller && !isApprovedForAll(from, caller) && __ERC721_approved(tokenId) != caller) {
            revert ERC721InsufficientApproval(caller, tokenId);
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        __ERC721_checkReceiver(from, to, tokenId, data);
    }

    function __ERC721_owner(uint256 tokenId) internal view returns (address) {
        return __ERC721_getStorage()._tokens[tokenId].owner;
    }

    function __ERC721_approved(uint256 tokenId) internal view returns (address) {
        return __ERC721_getStorage()._tokens[tokenId].approved;
    }

    function __ERC721_requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = __ERC721_owner(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }

    function __ERC721_transfer(address to, uint256 tokenId) internal returns (address previousOwner) {
        previousOwner = __ERC721_requireOwned(tokenId);
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        __ERC721_update(to, tokenId);
    }

    function __ERC721_mint(address to, uint256 tokenId) internal {
        if (__ERC721_owner(tokenId) != address(0)) {
            revert ERC721ExistentToken(tokenId);
        }
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        __ERC721_update(to, tokenId);
    }

    function __ERC721_burn(uint256 tokenId) internal returns (address previousOwner) {
        previousOwner = __ERC721_requireOwned(tokenId);
        __ERC721_update(address(0), tokenId);
    }

    function __ERC721_checkReceiver(address from, address to, uint256 tokenId, bytes memory data) internal {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function __ERC721_update(address to, uint256 tokenId) private returns (address) {
        __ERC721_Storage storage $ = __ERC721_getStorage();

        __ERC721_TokenData memory token = $._tokens[tokenId];
        address from = token.owner;

        if (from == address(0)) {
            assert(to != address(0));
            uint256 nextIndex = $._tokenIds.length;
            assert(nextIndex <= type(uint40).max);
            token.index = uint40(nextIndex);
            $._tokenIds.push(tokenId);
        } else {
            uint256[] storage tokenIdsByOwner = $._tokenIdsByOwner[from];
            uint256 srcIndex = tokenIdsByOwner.length - 1;
            uint40 dstIndex = token.indexByOwner;
            if (srcIndex != dstIndex) {
                uint256 srcToken = tokenIdsByOwner[srcIndex];
                tokenIdsByOwner[dstIndex] = srcToken;
                $._tokens[srcToken].indexByOwner = dstIndex;
            }
            tokenIdsByOwner.pop();
            delete token.owner;
            // ERC721 standard seems to suggest not emitting Approval event on transfer
            delete token.approved;
        }

        if (to == address(0)) {
            uint256 srcIndex = $._tokenIds.length - 1;
            uint40 dstIndex = token.index;
            if (srcIndex != dstIndex) {
                uint256 srcToken = $._tokenIds[srcIndex];
                $._tokenIds[dstIndex] = srcToken;
                $._tokens[srcToken].index = dstIndex;
            }
            $._tokenIds.pop();
            delete token.index;
            delete token.indexByOwner;
        } else {
            uint256[] storage tokenIdsByOwner = $._tokenIdsByOwner[to];
            token.indexByOwner = uint40(tokenIdsByOwner.length);
            tokenIdsByOwner.push(tokenId);
            token.owner = to;
        }

        $._tokens[tokenId] = token;

        emit Transfer(from, to, tokenId);

        return from;
    }

    function __ERC721_getStorage() private pure returns (__ERC721_Storage storage $) {
        assembly {
            $.slot := __ERC721_STORAGE
        }
    }
}
