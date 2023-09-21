// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

library DomainUtils {
    using {asSlice} for string;
    using DomainUtils for uint256;

    function asSlice(string memory self) internal pure returns (uint256 slice) {
        assembly {
            let l := mload(self)
            if shr(128, l) { revert(0, 0) }
            let p := add(32, self)
            if shr(128, add(p, l)) { revert(0, 0) }
            slice := or(l, shl(128, p))
        }
    }

    function isEmpty(uint256 slice) internal pure returns (bool answer) {
        assembly {
            answer := iszero(shl(128, slice))
        }
    }

    function toString(uint256 slice) internal pure returns (string memory s) {
        assembly ("memory-safe") {
            s := mload(0x40)
            let l := and(slice, shr(128, not(0)))
            for {
                let ps := shr(128, slice)
                let e := add(ps, l)
                let pd := add(32, s)
            } lt(ps, e) {
                ps := add(32, ps)
                pd := add(32, pd)
            } { mstore(pd, mload(ps)) }
            mstore(s, l)
            mstore(0x40, add(add(32, s), l))
        }
    }

    function tokenId(string memory domain) internal pure returns (uint256) {
        return uint256(keccak256(bytes(domain)));
    }

    function tokenId(uint256 slice) internal pure returns (uint256 result) {
        assembly {
            result := keccak256(shr(128, slice), and(slice, shr(128, not(0))))
        }
    }

    function parent(string memory domain) internal pure returns (uint256) {
        return domain.asSlice().parent();
    }

    function parent(uint256 slice) internal pure returns (uint256) {
        assembly {
            let p := shr(128, slice)
            let e := add(p, and(slice, shr(128, not(0))))
            for {} lt(p, e) { p := add(1, p) } {
                if eq(shr(248, mload(p)), 0x2e) {
                    p := add(1, p)
                    slice := or(sub(e, p), shl(128, p))
                    break
                }
            }
            if eq(p, e) { slice := shl(128, p) }
        }
        return slice;
    }

    function allLevels(string memory domain) internal pure returns (uint256[] memory) {
        return domain.asSlice().allLevels();
    }

    function allLevels(uint256 slice) internal pure returns (uint256[] memory levels) {
        assembly ("memory-safe") {
            levels := mload(0x40)
            mstore(add(32, levels), slice)
            let m := add(64, levels)
            for {
                let p := shr(128, slice)
                let e := sub(add(p, and(slice, shr(128, not(0)))), 1)
            } lt(p, e) { p := add(1, p) } {
                if eq(shr(248, mload(p)), 0x2e) {
                    mstore(m, or(sub(e, p), shl(128, add(1, p))))
                    m := add(32, m)
                }
            }
            mstore(levels, shr(5, sub(m, add(32, levels))))
            mstore(0x40, m)
        }
    }

    function isValidSubdomain(string memory subdomain) internal pure returns (bool) {
        // under construction
        return bytes(subdomain).length > 0;
    }
}
