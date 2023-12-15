// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {ABI} from "./external/ABI.sol";

library Tag {
    struct Group {
        EntryRef[] list;
        mapping(string name => Entry entry) map;
    }

    struct Entry {
        string name;
        ABI.Var value;
        uint16 index;
    }

    type EntryRef is bytes32;

    error TagInvalidOp();

    error TagTooManyEntries();

    function count(Group storage self) internal view returns (uint256) {
        return self.list.length;
    }

    function add(Group storage self, string memory name) internal returns (ABI.Var storage) {
        Entry storage entry = self.map[name];
        if (bytes(entry.name).length != 0) {
            revert TagInvalidOp();
        }
        entry.name = name;
        uint256 len = self.list.length;
        if (len > type(uint16).max) {
            revert TagTooManyEntries();
        }
        entry.index = uint16(len);
        self.list.push(_ref(entry));
        return entry.value;
    }

    function has(Group storage self, string memory name) internal view returns (bool) {
        Entry storage entry = self.map[name];
        return bytes(entry.name).length > 0;
    }

    function get(Group storage self, string memory name) internal view returns (ABI.Var storage) {
        Entry storage entry = self.map[name];
        if (bytes(entry.name).length == 0) {
            revert TagInvalidOp();
        }
        return entry.value;
    }

    function getAt(Group storage self, uint256 index) internal view returns (string memory name, ABI.Var storage) {
        Entry storage entry = _deref(self.list[index]);
        return (entry.name, entry.value);
    }

    function remove(Group storage self, string memory name) internal {
        Entry storage entry = self.map[name];
        if (bytes(entry.name).length == 0) {
            revert TagInvalidOp();
        }
        uint16 index = entry.index;
        uint16 moveIndex = uint16(self.list.length - 1);
        _deref(self.list[moveIndex]).index = index;
        self.list[index] = self.list[moveIndex];
        self.list.pop();
        delete self.map[name];
    }

    function _ref(Entry storage self) private pure returns (EntryRef $) {
        assembly {
            $ := self.slot
        }
    }

    function _deref(EntryRef self) private pure returns (Entry storage $) {
        assembly {
            $.slot := self
        }
    }
}
