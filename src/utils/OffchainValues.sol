// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

library OffchainValues {
    struct Register {
        mapping(bytes32 hash => uint256 blockNumber) $;
    }

    event OffchainStringArray(bytes32 indexed hash, string[] value);

    function contains(Register storage self, bytes32 hash) internal view returns (bool) {
        return self.$[hash] > 0;
    }

    function eventBlockNumber(Register storage self, bytes32 hash) internal view returns (uint256) {
        return self.$[hash];
    }

    function add(Register storage self, string[] memory value) internal returns (bytes32 hash, bool added) {
        hash = keccak256(abi.encode(value));
        if (contains(self, hash)) {
            return (hash, false);
        }
        self.$[hash] = block.number;
        emit OffchainStringArray(hash, value);
        return (hash, true);
    }
}
