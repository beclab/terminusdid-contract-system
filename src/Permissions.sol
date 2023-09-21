// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TerminusDID} from "./TerminusDID.sol";
import {DomainUtils} from "./utils/DomainUtils.sol";

library Permissions {
    using DomainUtils for string;
    using DomainUtils for DomainUtils.Slice;

    using {_isController} for TerminusDID;

    uint64 internal constant RESERVED_KEY_MAX = 0xffff;

    bytes4 private constant _sigERC721NonexistentToken = bytes4(keccak256("ERC721NonexistentToken(uint256)"));

    error NonexistentDomain();

    function allowSetTag(TerminusDID registry, address addr, string memory domain, bytes8 key)
        internal
        view
        returns (bool)
    {
        (bool isController, uint256 depth) = registry._isController(addr, domain);
        if (!isController) {
            return false;
        }
        if (depth == 0) {
            return true;
        }
        return uint64(key) <= RESERVED_KEY_MAX;
    }

    function allowRegister(TerminusDID registry, address addr, string memory domain) internal view returns (bool) {
        (bool isController,) = registry._isController(addr, domain);
        return isController;
    }

    function _isController(TerminusDID registry, address addr, string memory fullDomain)
        private
        view
        returns (bool ok, uint256 depth)
    {
        for (DomainUtils.Slice memory domain = fullDomain.asSlice(); !domain.isEmpty(); ++depth) {
            try registry.ownerOf(domain.tokenId()) returns (address owner) {
                if (owner == addr) {
                    return (true, depth);
                }
            } catch (bytes memory reason) {
                if (reason.length == 36 && bytes4(reason) == _sigERC721NonexistentToken) {
                    revert NonexistentDomain();
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
            domain.detachSub();
        }
    }
}
