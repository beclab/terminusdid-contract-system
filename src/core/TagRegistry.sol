// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.21;

import {ABI} from "../utils/external/ABI.sol";
import {Tag} from "../utils/Tag.sol";
import {DomainUtils} from "../utils/DomainUtils.sol";
import {OffchainValues} from "../utils/OffchainValues.sol";

abstract contract TagRegistry {
    using ABI for ABI.Var;
    using ABI for ABI.ReflectVar;
    using Tag for Tag.Group;
    using DomainUtils for string;
    using DomainUtils for DomainUtils.Slice;
    using OffchainValues for OffchainValues.Register;

    struct TagType {
        bytes abiType;
        bytes32[] fieldNamesHash;
    }

    /// @custom:storage-location erc7201:terminus.TagRegistry
    struct __TagRegistry_Storage {
        mapping(string domain => mapping(string name => TagType)) types;
        mapping(string from => mapping(string to => Tag.Group)) tags;
        OffchainValues.Register fieldNames;
        mapping(string domain => string[] names) tagNames;
    }

    // keccak256(abi.encode(uint256(keccak256("terminus.TagRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant __TagRegistry_STORAGE = 0xc8ba1573a83064b637069eac29a25dd52440bc4f98f399766e0040c151cb1f00;

    event NewTagType(string domain, string name, bytes abiType, bytes32[] fieldNamesHash);

    event TagAdded(string from, string to, string name, bytes value);

    event TagRemoved(string from, string to, string name);

    event TagElemUpdated(string from, string to, string name, uint256[] elemPath, bytes value);

    event TagElemPushed(string from, string to, string name, uint256[] elemPath, bytes value);

    event TagElemPopped(string from, string to, string name, uint256[] elemPath);

    error UndefinedTag(string domain, string name);

    error RedefinedTag(string domain, string name);

    error InvalidTagDefinition();

    function hasTag(string calldata from, string calldata to, string calldata name) public view returns (bool) {
        return __TagRegistry_getStorage().tags[from][to].has(name);
    }

    function addTag(string calldata from, string calldata to, string calldata name, bytes calldata value) public {
        _authorizeSetTag(from, to, name);
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        bytes memory abiType = $.types[from][name].abiType;
        if (abiType.length == 0) {
            revert UndefinedTag(from, name);
        }
        $.tags[from][to].add(name).bind(abiType).set(value);
        emit TagAdded(from, to, name, value);
    }

    function removeTag(string calldata from, string calldata to, string calldata name) public {
        _authorizeSetTag(from, to, name);
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        $.tags[from][to].remove(name);
        emit TagRemoved(from, to, name);
    }

    function getTagElem(string calldata from, string calldata to, string calldata name, uint256[] calldata elemPath)
        public
        view
        returns (bytes memory)
    {
        return __TagRegistry_getReflectVar(from, to, name, elemPath).get();
    }

    function updateTagElem(
        string calldata from,
        string calldata to,
        string calldata name,
        uint256[] calldata elemPath,
        bytes calldata value
    ) public {
        _authorizeSetTag(from, to, name);
        __TagRegistry_getReflectVar(from, to, name, elemPath).set(value);
        uint256[] memory elemPath_ = elemPath;
        emit TagElemUpdated(from, to, name, elemPath_, value);
    }

    function getTagElemLength(
        string calldata from,
        string calldata to,
        string calldata name,
        uint256[] calldata elemPath
    ) public view returns (uint256) {
        return __TagRegistry_getReflectVar(from, to, name, elemPath).length();
    }

    function pushTagElem(
        string calldata from,
        string calldata to,
        string calldata name,
        uint256[] calldata elemPath,
        bytes calldata value
    ) public {
        _authorizeSetTag(from, to, name);
        __TagRegistry_getReflectVar(from, to, name, elemPath).push(value);
        emit TagElemPushed(from, to, name, elemPath, value);
    }

    function popTagElem(string calldata from, string calldata to, string calldata name, uint256[] calldata elemPath)
        public
    {
        _authorizeSetTag(from, to, name);
        __TagRegistry_getReflectVar(from, to, name, elemPath).pop();
        emit TagElemPopped(from, to, name, elemPath);
    }

    function getTagCount(string calldata from, string calldata to) public view returns (uint256) {
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        return $.tags[from][to].count();
    }

    function getTagNameByIndex(string calldata from, string calldata to, uint256 index)
        public
        view
        returns (string memory)
    {
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        (string memory name,) = $.tags[from][to].getAt(index);
        return name;
    }

    function getTagType(string calldata domain, string calldata name)
        public
        view
        returns (bytes memory abiType, bytes32[] memory fieldNamesHash)
    {
        TagType storage $ = __TagRegistry_getStorage().types[domain][name];
        if ($.abiType.length == 0) {
            revert UndefinedTag(domain, name);
        }
        return ($.abiType, $.fieldNamesHash);
    }

    function getTagABIType(string calldata domain, string calldata name) public view returns (bytes memory) {
        TagType storage $ = __TagRegistry_getStorage().types[domain][name];
        if ($.abiType.length == 0) {
            revert UndefinedTag(domain, name);
        }
        return $.abiType;
    }

    function getTagFieldNamesHashByIndex(string calldata domain, string calldata name, uint256 index)
        public
        view
        returns (bytes32)
    {
        TagType storage $ = __TagRegistry_getStorage().types[domain][name];
        if ($.abiType.length == 0) {
            revert UndefinedTag(domain, name);
        }
        return $.fieldNamesHash[index];
    }

    function getFieldNamesEventBlock(bytes32 hash) public view returns (uint256) {
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        return $.fieldNames.eventBlockNumber(hash);
    }

    function getDefinedTagCount(string calldata domain) public view returns (uint256) {
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        return $.tagNames[domain].length;
    }

    function getDefinedTagNameByIndex(string calldata domain, uint256 index) public view returns (string memory) {
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        return $.tagNames[domain][index];
    }

    function getDefinedTagNames(string calldata domain) public view returns (string[] memory) {
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        return $.tagNames[domain];
    }

    function defineTag(
        string calldata domain,
        string calldata name,
        bytes calldata abiType,
        string[][] calldata fieldNames
    ) public {
        _authorizeDefineTag(domain);
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        TagType storage tagType = $.types[domain][name];

        if (tagType.abiType.length > 0) {
            revert RedefinedTag(domain, name);
        }
        if (!__TagRegistry_isValidName(name) || abiType.length > 31) {
            revert InvalidTagDefinition();
        }

        uint16[] memory fieldCounts = ABI.countTupleFieldsPreorder(abiType);
        if (fieldNames.length != fieldCounts.length) {
            revert InvalidTagDefinition();
        }
        bytes32[] memory fieldNamesHash = new bytes32[](fieldNames.length);

        for (uint256 i = 0; i < fieldNames.length; ++i) {
            string[] calldata fieldNameList = fieldNames[i];
            if (fieldNameList.length != fieldCounts[i]) {
                revert InvalidTagDefinition();
            }

            __TagRegistry_validateFieldNames(fieldNameList);
            (fieldNamesHash[i],) = $.fieldNames.add(fieldNameList);
        }

        tagType.abiType = abiType;
        tagType.fieldNamesHash = fieldNamesHash;

        $.tagNames[domain].push(name);
        emit NewTagType(domain, name, abiType, fieldNamesHash);
    }

    function _authorizeDefineTag(string calldata domain) internal virtual;

    function _authorizeSetTag(string calldata from, string calldata to, string calldata name) internal virtual;

    function __TagRegistry_validateFieldNames(string[] calldata fieldNames) private pure {
        for (uint256 i = 0; i < fieldNames.length; ++i) {
            string calldata fieldName = fieldNames[i];
            if (!__TagRegistry_isValidName(fieldName)) {
                revert InvalidTagDefinition();
            }

            bytes32 s;
            assembly {
                s := calldataload(fieldName.offset)
                if shl(shl(3, fieldName.length), s) { revert(0, 0) }
            }
            for (uint256 j = 0; j < i; ++j) {
                string calldata fieldNameUsed = fieldNames[j];
                if (bytes(fieldNameUsed).length == bytes(fieldName).length) {
                    bytes32 diff;
                    assembly {
                        diff := xor(s, calldataload(fieldNameUsed.offset))
                    }
                    if (diff == 0) {
                        revert InvalidTagDefinition();
                    }
                }
            }
        }
    }

    function __TagRegistry_isValidName(string calldata fieldName) private pure returns (bool) {
        uint256 len = bytes(fieldName).length;
        if (len == 0 || len > 31) {
            return false;
        }
        bytes32 s;
        assembly {
            s := calldataload(fieldName.offset)
        }
        uint8 c0 = uint8(s[0]);
        if (c0 < 0x61 || c0 > 0x7a) {
            return false;
        }
        for (uint256 i = 1; i < len; ++i) {
            uint8 c = uint8(s[i]);
            if ((c >= 0x61 && c <= 0x7a) || (c >= 0x41 && c <= 0x5a) || (c >= 0x30 && c <= 0x39)) {
                continue;
            }
            return false;
        }
        return true;
    }

    function __TagRegistry_getReflectVar(
        string calldata from,
        string calldata to,
        string calldata name,
        uint256[] calldata elemPath
    ) private view returns (ABI.ReflectVar memory) {
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        bytes memory abiType = $.types[from][name].abiType;
        ABI.ReflectVar memory rv = $.tags[from][to].get(name).bind(abiType);
        for (uint256 i = 0; i < elemPath.length; ++i) {
            rv = rv.at(elemPath[i]);
        }
        return rv;
    }

    function __TagRegistry_getStorage() private pure returns (__TagRegistry_Storage storage $) {
        assembly {
            $.slot := __TagRegistry_STORAGE
        }
    }
}
