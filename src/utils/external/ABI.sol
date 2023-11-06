// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

library ABI {
    struct Var {
        uint256 $;
    }

    struct ReflectVar {
        bytes32 slot;
        uint256 offset;
        bytes typ;
        uint256 i;
    }

    bytes1 private constant INT_T = hex"00";
    bytes1 private constant UINT_T = hex"01";
    bytes1 private constant BOOL_T = hex"02";
    bytes1 private constant STRING_T = hex"03";
    bytes1 private constant DYNAMIC_ARRAY_T = hex"04";
    bytes1 private constant FIXED_ARRAY_T = hex"05";
    bytes1 private constant TUPLE_T = hex"06";
    bytes1 private constant ADDRESS_T = hex"07";
    bytes1 private constant FIXED_BYTES_T = hex"08";
    bytes1 private constant BYTES_T = hex"09";

    error InvalidIndex();

    error InvalidOp();

    error InvalidType();

    error InvalidValue();

    modifier releaseMemory() {
        uint256 p;
        assembly {
            p := mload(0x40)
        }

        _;

        assembly {
            mstore(0x40, p)
        }
    }

    function intT(uint16 bits) public pure returns (bytes2) {
        if (bits & 0x7 == 0) {
            uint16 size = bits >> 3;
            if (size >= 1 && size <= 32) {
                return bytes2(INT_T) | bytes2(size);
            }
        }
        revert InvalidType();
    }

    function uintT(uint16 bits) public pure returns (bytes2) {
        if (bits & 0x7 == 0) {
            uint16 size = bits >> 3;
            if (size >= 1 && size <= 32) {
                return bytes2(UINT_T) | bytes2(size);
            }
        }
        revert InvalidType();
    }

    function boolT() public pure returns (bytes1) {
        return BOOL_T;
    }

    function stringT() public pure returns (bytes1) {
        return STRING_T;
    }

    function addressT() public pure returns (bytes1) {
        return ADDRESS_T;
    }

    function bytesT(uint8 size) public pure returns (bytes2) {
        if (size >= 1 && size <= 32) {
            return bytes2(FIXED_BYTES_T) | bytes2(uint16(size));
        }
        revert InvalidType();
    }

    function bytesT() public pure returns (bytes1) {
        return BYTES_T;
    }

    function arrayT(bytes memory elem, uint16 count) public pure returns (bytes memory) {
        validateType(elem);
        if (count == 0) {
            revert InvalidType();
        }
        return bytes.concat(FIXED_ARRAY_T, bytes2(count), elem);
    }

    function arrayT(bytes memory elem) public pure returns (bytes memory) {
        validateType(elem);
        return bytes.concat(DYNAMIC_ARRAY_T, elem);
    }

    function tupleT(bytes memory elems) public pure returns (bytes memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < elems.length; ++count) {
            i = _typeEnd(elems, i);
        }
        if (count == 0 || count > type(uint16).max) {
            revert InvalidType();
        }
        return bytes.concat(TUPLE_T, bytes2(uint16(count)), elems);
    }

    function validateType(bytes memory typ) public pure {
        if (_typeEnd(typ, 0) != typ.length) {
            revert InvalidType();
        }
    }

    function countTupleFieldsPreorder(bytes memory typ) public pure returns (uint16[] memory) {
        uint16[] memory counts;
        uint256 p;
        assembly {
            counts := mload(0x40)
            p := add(32, counts)
        }
        (uint256 p_, uint256 i) = _countTupleFieldsPreorder(p, typ, 0);
        if (i != typ.length) {
            revert InvalidType();
        }
        assembly {
            mstore(counts, shr(5, sub(p_, p)))
            mstore(0x40, p_)
        }
        return counts;
    }

    function bind(Var storage self, bytes memory typ) public pure returns (ReflectVar memory) {
        bytes32 slot;
        assembly {
            slot := self.slot
        }

        bytes1 t = _read1(typ, 0);
        if (t == FIXED_ARRAY_T || t == TUPLE_T) {
            slot = _hashSlot(slot);
        }

        return ReflectVar({slot: slot, offset: 0, typ: typ, i: 0});
    }

    function at(ReflectVar memory self, uint256 index) public view returns (ReflectVar memory) {
        (bytes32 slot, bytes memory typ, uint256 i) = (self.slot, self.typ, self.i);
        (slot,) = _align(slot, self.offset);
        uint256 offset;

        bytes1 t = _read1(typ, i);

        if (t == DYNAMIC_ARRAY_T) {
            uint256 len;
            assembly {
                len := sload(slot)
            }
            if (index >= len) {
                revert InvalidIndex();
            }

            slot = _hashSlot(slot);
            (uint256 slots, uint256 bytes_,) = _storageSize(typ, ++i);
            if (slots > 0) {
                slot = bytes32(uint256(slot) + slots * index);
            } else {
                uint256 n = 32 / bytes_;
                slot = bytes32(uint256(slot) + index / n);
                offset = (index % n) * bytes_;
            }
        } else if (t == FIXED_ARRAY_T) {
            uint256 len = _readArrayTupleLength(typ, i + 1);
            if (index >= len) {
                revert InvalidIndex();
            }

            i += 3;
            (uint256 slots, uint256 bytes_,) = _storageSize(typ, i);
            if (slots > 0) {
                slot = bytes32(uint256(slot) + slots * index);
            } else {
                uint256 n = 32 / bytes_;
                slot = bytes32(uint256(slot) + index / n);
                offset = (index % n) * bytes_;
            }
        } else if (t == TUPLE_T) {
            uint256 len = _readArrayTupleLength(typ, i + 1);
            if (index >= len) {
                revert InvalidIndex();
            }

            i += 3;
            uint256 slots;
            uint256 bytes_;

            for (uint256 j = 0; j < index; ++j) {
                (slots, bytes_, i) = _storageSize(typ, i);

                if (slots > 0) {
                    if (offset > 0) {
                        slot = bytes32(uint256(slot) + 1);
                        offset = 0;
                    }
                    slot = bytes32(uint256(slot) + slots);
                } else {
                    offset += bytes_;
                    if (offset > 32) {
                        slot = bytes32(uint256(slot) + 1);
                        offset = bytes_;
                    }
                }
            }
        } else {
            revert InvalidOp();
        }

        self.i = i;
        self.slot = slot;
        self.offset = offset;
        return self;
    }

    function get(ReflectVar memory self) public view returns (bytes memory) {
        bytes memory meta = _typeMeta(self.typ, self.i);

        uint256 pMeta;
        bytes memory value;
        uint256 pHead;
        uint256 pTail;
        assembly {
            pMeta := add(32, meta)
            value := mload(0x40)
            pHead := add(32, value)
            pTail := add(32, pHead)
        }

        (,,, uint256 pMeta_, uint256 pHead_, uint256 pTail_) =
            _load(self.slot, self.offset, self.typ, self.i, pMeta, pHead, pTail);
        assert(pMeta_ == pMeta + meta.length);
        if (pTail_ == pTail) {
            pTail = pHead_;
        } else {
            assembly {
                mstore(pHead, 0x20)
            }
            pTail = pTail_;
        }

        assembly {
            let l := sub(pTail, pHead)
            mstore(value, l)
            mstore(0x40, add(pHead, and(not(0x1f), add(31, l))))
        }
        return value;
    }

    function set(ReflectVar memory self, bytes memory value) public releaseMemory {
        bytes memory meta = _typeMeta(self.typ, self.i);

        uint256 pMeta;
        uint256 pHead;
        uint256 pTail;
        assembly {
            pMeta := add(32, meta)
            pHead := add(32, value)
            pTail := add(32, pHead)
        }

        (,,, uint256 pMeta_, uint256 pHead_, uint256 pTail_) =
            _store(self.slot, self.offset, self.typ, self.i, pMeta, pHead, pHead, pTail);
        assert(pMeta_ == pMeta + meta.length);
        uint256 valueEnd = pHead + value.length;
        if (pHead_ != valueEnd && (pHead_ != pTail || pTail_ != valueEnd)) {
            revert InvalidValue();
        }
    }

    function length(ReflectVar memory self) public view returns (uint256) {
        (bytes32 slot,) = _align(self.slot, self.offset);

        bytes1 t = _read1(self.typ, self.i);
        uint256 len;

        if (t == STRING_T || t == BYTES_T) {
            assembly {
                len := sload(slot)
                switch and(1, len)
                case 0 { len := shr(1, and(0xff, len)) }
                default { len := shr(1, len) }
            }
        } else if (t == DYNAMIC_ARRAY_T) {
            assembly {
                len := sload(slot)
            }
        } else {
            revert InvalidOp();
        }

        return len;
    }

    function push(ReflectVar memory self, bytes memory value) public releaseMemory {
        (bytes memory typ, uint256 i) = (self.typ, self.i);
        (bytes32 slot, uint256 offset) = _align(self.slot, self.offset);

        bytes1 t = _read1(self.typ, i);

        if (t == DYNAMIC_ARRAY_T) {
            uint256 len;
            assembly {
                len := sload(slot)
            }
            uint256 index = len;
            ++len;
            assembly {
                sstore(slot, len)
            }

            slot = _hashSlot(slot);
            (uint256 slots, uint256 bytes_,) = _storageSize(typ, ++i);
            if (slots > 0) {
                slot = bytes32(uint256(slot) + slots * index);
            } else {
                uint256 n = 32 / bytes_;
                slot = bytes32(uint256(slot) + index / n);
                offset = (index % n) * bytes_;
            }

            ReflectVar memory elem = ReflectVar({slot: slot, offset: offset, typ: typ, i: i});
            set(elem, value);
        } else {
            revert InvalidOp();
        }
    }

    function pop(ReflectVar memory self) public {
        (bytes32 slot,) = _align(self.slot, self.offset);

        bytes1 t = _read1(self.typ, self.i);

        if (t == DYNAMIC_ARRAY_T) {
            uint256 len;
            assembly {
                len := sload(slot)
            }
            if (len == 0) {
                revert InvalidOp();
            }
            // TODO: clear last element?
            assembly {
                sstore(slot, sub(len, 1))
            }
        } else {
            revert InvalidOp();
        }
    }

    function _load(
        bytes32 slot,
        uint256 offset,
        bytes memory typ,
        uint256 i,
        uint256 pMeta,
        uint256 pHead,
        uint256 pTail
    )
        private
        view
        returns (bytes32 slot_, uint256 offset_, uint256 i_, uint256 pMeta_, uint256 pHead_, uint256 pTail_)
    {
        bytes1 t = _read1(typ, i);

        if (t == INT_T) {
            uint8 size = _readValueTypeSize(typ, i + 1);
            (slot, offset) = _alignShort(slot, offset, size);
            assembly {
                mstore(pHead, signextend(sub(size, 1), shr(shl(3, offset), sload(slot))))
                offset := add(size, offset)
            }
            return (slot, offset, i + 2, pMeta, pHead + 32, pTail);
        } else if (t == UINT_T) {
            uint8 size = _readValueTypeSize(typ, i + 1);
            (slot, offset) = _alignShort(slot, offset, size);
            assembly {
                mstore(pHead, and(shr(sub(256, shl(3, size)), not(0)), shr(shl(3, offset), sload(slot))))
                offset := add(size, offset)
            }
            return (slot, offset, i + 2, pMeta, pHead + 32, pTail);
        } else if (t == BOOL_T) {
            (slot, offset) = _alignShort(slot, offset, 1);
            assembly {
                switch and(0xff, shr(shl(3, offset), sload(slot)))
                case 0 { mstore(pHead, 0) }
                default { mstore(pHead, 1) }
                offset := add(1, offset)
            }
            return (slot, offset, i + 1, pMeta, pHead + 32, pTail);
        } else if (t == ADDRESS_T) {
            (slot, offset) = _alignShort(slot, offset, 20);
            assembly {
                mstore(pHead, and(shr(96, not(0)), shr(shl(3, offset), sload(slot))))
                offset := add(20, offset)
            }
            return (slot, offset, i + 1, pMeta, pHead + 32, pTail);
        } else if (t == FIXED_BYTES_T) {
            uint8 size = _readValueTypeSize(typ, i + 1);
            (slot, offset) = _alignShort(slot, offset, size);
            assembly {
                mstore(pHead, shl(sub(256, shl(3, size)), shr(shl(3, offset), sload(slot))))
                offset := add(size, offset)
            }
            return (slot, offset, i + 2, pMeta, pHead + 32, pTail);
        } else if (t == STRING_T || t == BYTES_T) {
            (slot,) = _align(slot, offset);
            bytes32 nextSlot = bytes32(uint256(slot) + 1);

            uint256 len;
            assembly {
                len := sload(slot)
            }

            if (len & 1 == 0) {
                bytes32 data;
                bytes32 pads;
                assembly {
                    data := len
                    len := shr(1, and(0xff, data))
                    data := and(not(0xff), data)
                    pads := shl(shl(3, len), data)
                }
                if (len >= 32 || pads != 0) {
                    revert InvalidValue();
                }
                assembly {
                    mstore(pTail, len)
                    pTail := add(32, pTail)
                    if len {
                        mstore(pTail, data)
                        pTail := add(32, pTail)
                    }
                }
            } else {
                slot = _hashSlot(slot);
                bytes32 pads;
                assembly {
                    len := shr(1, len)
                    mstore(pTail, len)
                    pTail := add(32, pTail)

                    let v
                    for { let j := 0 } lt(j, len) {
                        v := 0
                        j := add(32, j)
                        slot := add(1, slot)
                        pTail := add(32, pTail)
                    } {
                        v := sload(slot)
                        mstore(pTail, v)
                    }

                    pads := shl(shl(3, and(0x1f, len)), v)
                }
                if (pads != 0) {
                    revert InvalidValue();
                }
            }

            return (nextSlot, 0, i + 1, pMeta, pHead + 32, pTail);
        } else if (t == DYNAMIC_ARRAY_T) {
            (slot, offset) = _align(slot, offset);
            bytes32 nextSlot = bytes32(uint256(slot) + 1);
            uint256 nextPHead = pHead + 32;

            uint256 len;
            assembly {
                len := sload(slot)
                mstore(pTail, len)
                pTail := add(32, pTail)
            }

            if (len > 0) {
                slot = _hashSlot(slot);
                uint256 i0 = i + 1;
                uint256 pMeta0 = pMeta;
                uint256 pos = 32 * len;
                pHead = pTail;
                pTail += pos;
                for (uint256 j = 0; j < len; ++j) {
                    (slot, offset, i, pMeta, pHead_, pTail_) = _load(slot, offset, typ, i0, pMeta0, pHead, pTail);
                    assembly {
                        let d := sub(pTail_, pTail)
                        if d {
                            mstore(pHead, pos)
                            pos := add(pos, d)
                        }
                    }
                    pHead = pHead_;
                    pTail = pTail_;
                }
                if (pHead > pTail) {
                    pTail = pHead;
                }
            } else {
                (pMeta, i) = _typeMetaEnd(pMeta, typ, ++i);
            }

            return (nextSlot, 0, i, pMeta, nextPHead, pTail);
        } else if (t == FIXED_ARRAY_T) {
            (slot, offset) = _align(slot, offset);

            uint256 len = _readArrayTupleLength(typ, i + 1);
            bytes1 dt = _read1(pMeta);
            uint256 i0 = i + 3;
            uint256 pMeta0 = pMeta + 1;
            if (dt == 0) {
                for (uint256 j = 0; j < len; ++j) {
                    (slot, offset, i, pMeta, pHead,) = _load(slot, offset, typ, i0, pMeta0, pHead, type(uint256).max);
                }
            } else {
                uint256 nextPHead = pHead + 32;
                uint256 pos = 32 * len;
                pHead = pTail;
                pTail += pos;

                for (uint256 j = 0; j < len; ++j) {
                    (slot, offset, i, pMeta,, pTail_) = _load(slot, offset, typ, i0, pMeta0, pHead, pTail);
                    assembly {
                        mstore(pHead, pos)
                        pos := add(pos, sub(pTail_, pTail))
                    }
                    pHead += 32;
                    pTail = pTail_;
                }

                pHead = nextPHead;
            }

            (slot,) = _align(slot, offset);
            return (slot, 0, i, pMeta, pHead, pTail);
        } else if (t == TUPLE_T) {
            (slot, offset) = _align(slot, offset);

            uint256 len = _readArrayTupleLength(typ, i + 1);
            uint256 pos = 32 * uint16(_read2(pMeta));
            i += 3;
            pMeta += 2;
            if (pos == 0) {
                for (uint256 j = 0; j < len; ++j) {
                    (slot, offset, i, pMeta, pHead,) = _load(slot, offset, typ, i, pMeta, pHead, type(uint256).max);
                }
            } else {
                uint256 nextPHead = pHead + 32;
                pHead = pTail;
                pTail += pos;

                for (uint256 j = 0; j < len; ++j) {
                    (slot, offset, i, pMeta, pHead_, pTail_) = _load(slot, offset, typ, i, pMeta, pHead, pTail);
                    assembly {
                        let d := sub(pTail_, pTail)
                        if d {
                            mstore(pHead, pos)
                            pos := add(pos, d)
                        }
                    }
                    pHead = pHead_;
                    pTail = pTail_;
                }

                pHead = nextPHead;
            }

            (slot,) = _align(slot, offset);
            return (slot, 0, i, pMeta, pHead, pTail);
        }

        revert InvalidType();
    }

    function _store(
        bytes32 slot,
        uint256 offset,
        bytes memory typ,
        uint256 i,
        uint256 pMeta,
        uint256 pStart,
        uint256 pHead,
        uint256 pTail
    ) private returns (bytes32 slot_, uint256 offset_, uint256 i_, uint256 pMeta_, uint256 pHead_, uint256 pTail_) {
        bytes1 t = _read1(typ, i);

        if (t == INT_T) {
            uint8 size = _readValueTypeSize(typ, i + 1);
            (slot, offset) = _alignShort(slot, offset, size);
            bytes32 diff;
            assembly {
                let b := shl(3, offset)
                let m := shl(b, shr(sub(256, shl(3, size)), not(0)))
                let v := and(sload(slot), not(m))

                let w := mload(pHead)
                sstore(slot, or(v, and(m, shl(b, w))))

                diff := xor(w, signextend(sub(size, 1), w))
                offset := add(size, offset)
            }
            if (diff != 0) {
                revert InvalidValue();
            }
            return (slot, offset, i + 2, pMeta, pHead + 32, pTail);
        } else if (t == UINT_T) {
            uint8 size = _readValueTypeSize(typ, i + 1);
            (slot, offset) = _alignShort(slot, offset, size);
            bytes32 pads;
            assembly {
                let b := shl(3, offset)
                let m := shl(b, shr(sub(256, shl(3, size)), not(0)))
                let v := and(sload(slot), not(m))

                let w := mload(pHead)
                sstore(slot, or(v, shl(b, w)))

                pads := shr(shl(3, size), w)
                offset := add(size, offset)
            }
            if (pads != 0) {
                revert InvalidValue();
            }
            return (slot, offset, i + 2, pMeta, pHead + 32, pTail);
        } else if (t == BOOL_T) {
            (slot, offset) = _alignShort(slot, offset, 1);
            bytes32 pads;
            assembly {
                let b := shl(3, offset)
                let v := and(sload(slot), not(shl(b, 0xff)))

                let w := mload(pHead)
                sstore(slot, or(v, shl(b, w)))

                pads := shr(1, w)
                offset := add(1, offset)
            }
            if (pads != 0) {
                revert InvalidValue();
            }
            return (slot, offset, i + 1, pMeta, pHead + 32, pTail);
        } else if (t == ADDRESS_T) {
            (slot, offset) = _alignShort(slot, offset, 20);
            bytes32 pads;
            assembly {
                let b := shl(3, offset)
                let v := and(sload(slot), not(shl(b, shr(96, not(0)))))

                let w := mload(pHead)
                sstore(slot, or(v, shl(b, w)))

                pads := shr(160, w)
                offset := add(20, offset)
            }
            if (pads != 0) {
                revert InvalidValue();
            }
            return (slot, offset, i + 1, pMeta, pHead + 32, pTail);
        } else if (t == FIXED_BYTES_T) {
            uint8 size = _readValueTypeSize(typ, i + 1);
            (slot, offset) = _alignShort(slot, offset, size);
            bytes32 pads;
            assembly {
                let a := sub(256, shl(3, size))
                let b := shl(3, offset)
                let m := shl(b, shr(a, not(0)))
                let v := and(sload(slot), not(m))

                let w := mload(pHead)
                sstore(slot, or(v, shl(b, shr(a, w))))

                pads := shl(shl(3, size), w)
                offset := add(size, offset)
            }
            if (pads != 0) {
                revert InvalidValue();
            }
            return (slot, offset, i + 2, pMeta, pHead + 32, pTail);
        } else if (t == STRING_T || t == BYTES_T) {
            (slot,) = _align(slot, offset);
            bytes32 nextSlot = bytes32(uint256(slot) + 1);

            assembly {
                pTail_ := mload(pHead)
            }
            pTail_ += pStart;
            if (pTail_ != pTail) {
                revert InvalidValue();
            }

            uint256 len;
            assembly {
                len := mload(pTail)
                pTail := add(32, pTail)
            }

            bytes32 pads;
            if (len < 32) {
                assembly {
                    switch len
                    case 0 { sstore(slot, 0) }
                    default {
                        let v := mload(pTail)
                        sstore(slot, or(v, shl(1, len)))
                        pads := shl(shl(3, len), v)
                        pTail := add(32, pTail)
                    }
                }
            } else {
                assembly {
                    sstore(slot, or(1, shl(1, len)))
                }
                slot = _hashSlot(slot);
                assembly {
                    let v
                    for { let j := 0 } lt(j, len) {
                        v := 0
                        j := add(32, j)
                        slot := add(1, slot)
                        pTail := add(32, pTail)
                    } {
                        v := mload(pTail)
                        sstore(slot, v)
                    }
                    pads := shl(shl(3, and(0x1f, len)), v)
                }
            }

            if (pads != 0) {
                revert InvalidValue();
            }
            return (nextSlot, 0, i + 1, pMeta, pHead + 32, pTail);
        } else if (t == DYNAMIC_ARRAY_T) {
            (slot, offset) = _align(slot, offset);
            bytes32 nextSlot = bytes32(uint256(slot) + 1);
            uint256 nextPHead = pHead + 32;

            assembly {
                pTail_ := mload(pHead)
            }
            pTail_ += pStart;
            if (pTail_ != pTail) {
                revert InvalidValue();
            }

            uint256 len;
            assembly {
                len := mload(pTail)
                sstore(slot, len)
                pTail := add(32, pTail)
            }

            if (len > 0) {
                slot = _hashSlot(slot);
                uint256 i0 = i + 1;
                uint256 pMeta0 = pMeta;
                uint256 pos = 32 * len;
                pStart = pTail;
                pHead = pTail;
                pTail += pos;
                for (uint256 j = 0; j < len; ++j) {
                    (slot, offset, i, pMeta, pHead, pTail) = _store(slot, offset, typ, i0, pMeta0, pStart, pHead, pTail);
                }
                if (pHead > pTail) {
                    pTail = pHead;
                }
            } else {
                (pMeta, i) = _typeMetaEnd(pMeta, typ, ++i);
            }

            return (nextSlot, 0, i, pMeta, nextPHead, pTail);
        } else if (t == FIXED_ARRAY_T) {
            (slot, offset) = _align(slot, offset);

            uint256 len = _readArrayTupleLength(typ, i + 1);
            bytes1 dt = _read1(pMeta);
            uint256 i0 = i + 3;
            uint256 pMeta0 = pMeta + 1;
            if (dt == 0) {
                pStart = pHead;
                for (uint256 j = 0; j < len; ++j) {
                    (slot, offset, i, pMeta, pHead,) =
                        _store(slot, offset, typ, i0, pMeta0, pStart, pHead, type(uint256).max);
                }
            } else {
                assembly {
                    pTail_ := mload(pHead)
                }
                pTail_ += pStart;
                if (pTail_ != pTail) {
                    revert InvalidValue();
                }

                uint256 nextPHead = pHead + 32;
                uint256 pos = 32 * len;
                pStart = pTail;
                pHead = pTail;
                pTail += pos;
                for (uint256 j = 0; j < len; ++j) {
                    (slot, offset, i, pMeta, pHead, pTail) = _store(slot, offset, typ, i0, pMeta0, pStart, pHead, pTail);
                }

                pHead = nextPHead;
            }

            (slot,) = _align(slot, offset);
            return (slot, 0, i, pMeta, pHead, pTail);
        } else if (t == TUPLE_T) {
            (slot, offset) = _align(slot, offset);

            uint256 len = _readArrayTupleLength(typ, i + 1);
            uint256 pos = 32 * uint16(_read2(pMeta));
            i += 3;
            pMeta += 2;
            if (pos == 0) {
                pStart = pHead;
                for (uint256 j = 0; j < len; ++j) {
                    (slot, offset, i, pMeta, pHead,) =
                        _store(slot, offset, typ, i, pMeta, pStart, pHead, type(uint256).max);
                }
            } else {
                assembly {
                    pTail_ := mload(pHead)
                }
                pTail_ += pStart;
                if (pTail_ != pTail) {
                    revert InvalidValue();
                }

                uint256 nextPHead = pHead + 32;
                pStart = pTail;
                pHead = pTail;
                pTail += pos;
                for (uint256 j = 0; j < len; ++j) {
                    (slot, offset, i, pMeta, pHead, pTail) = _store(slot, offset, typ, i, pMeta, pStart, pHead, pTail);
                }

                pHead = nextPHead;
            }

            (slot,) = _align(slot, offset);
            return (slot, 0, i, pMeta, pHead, pTail);
        }

        revert InvalidType();
    }

    function _alignShort(bytes32 slot, uint256 offset, uint8 size)
        private
        pure
        returns (bytes32 slot_, uint256 offset_)
    {
        if (offset + size > 32) {
            slot = bytes32(uint256(slot) + 1);
            offset = 0;
        }
        return (slot, offset);
    }

    function _align(bytes32 slot, uint256 offset) private pure returns (bytes32 slot_, uint256 offset_) {
        if (offset > 0) {
            slot = bytes32(uint256(slot) + 1);
            offset = 0;
        }
        return (slot, offset);
    }

    function _hashSlot(bytes32 slot) private pure returns (bytes32 $) {
        assembly {
            mstore(0, slot)
            $ := keccak256(0, 0x20)
        }
    }

    function _storageSize(bytes memory typ, uint256 i)
        private
        pure
        returns (uint256 slots, uint256 bytes_, uint256 i_)
    {
        bytes1 t = _read1(typ, i);

        if (t == INT_T || t == UINT_T || t == FIXED_BYTES_T) {
            uint8 size = _readValueTypeSize(typ, i + 1);
            if (size < 32) {
                return (0, size, i + 2);
            }
            return (1, 0, i + 2);
        } else if (t == BOOL_T) {
            return (0, 1, i + 1);
        } else if (t == ADDRESS_T) {
            return (0, 20, i + 1);
        } else if (t == STRING_T || t == BYTES_T) {
            return (1, 0, i + 1);
        } else if (t == DYNAMIC_ARRAY_T) {
            return (1, 0, _typeEnd(typ, i + 1));
        } else if (t == FIXED_ARRAY_T) {
            uint16 len = _readArrayTupleLength(typ, i + 1);
            (slots, bytes_, i) = _storageSize(typ, i + 3);
            if (slots > 0) {
                return (slots * len, 0, i);
            }
            uint256 n = 32 / bytes_;
            return ((len + n - 1) / n, 0, i);
        } else if (t == TUPLE_T) {
            uint16 len = _readArrayTupleLength(typ, i + 1);
            i += 3;

            uint256 totalSlots;
            uint256 totalBytes;

            for (uint16 j = 0; j < len; ++j) {
                (slots, bytes_, i) = _storageSize(typ, i);

                if (slots > 0) {
                    if (totalBytes > 0) {
                        ++totalSlots;
                        totalBytes = 0;
                    }
                    totalSlots += slots;
                } else {
                    totalBytes += bytes_;
                    if (totalBytes > 32) {
                        ++totalSlots;
                        totalBytes = bytes_;
                    }
                }
            }

            if (totalBytes > 0) {
                ++totalSlots;
            }
            return (totalSlots, 0, i);
        }

        revert InvalidType();
    }

    function _typeMeta(bytes memory typ, uint256 i) private pure returns (bytes memory meta) {
        bytes memory m;
        uint256 p;
        assembly {
            m := mload(0x40)
            p := add(32, m)
        }
        uint256 pEnd;
        (pEnd,,,) = _typeMeta(p, typ, i);
        if (p != pEnd) {
            assembly {
                let l := sub(pEnd, p)
                mstore(m, l)
                mstore(0x40, add(p, and(not(0x1f), add(31, l))))
            }
            meta = m;
        }
    }

    function _typeMeta(uint256 p, bytes memory typ, uint256 i)
        private
        pure
        returns (uint256 p_, uint256 i_, bool isDynamic, uint256 size)
    {
        bytes1 t = _read1(typ, i);

        if (t == STRING_T || t == BYTES_T) {
            (i, isDynamic, size) = (i + 1, true, 1);
        } else if (t == DYNAMIC_ARRAY_T) {
            (p, i, isDynamic,) = _typeMeta(p, typ, i + 1);
            (isDynamic, size) = (true, 1);
        } else if (t == FIXED_ARRAY_T) {
            uint16 len = _readArrayTupleLength(typ, i + 1);
            uint256 pArray = p;
            (p, i, isDynamic, size) = _typeMeta(p + 1, typ, i + 3);

            uint256 meta;
            if (isDynamic) {
                meta = 0xff;
                size = 1;
            } else {
                size *= len;
            }
            assembly {
                mstore8(pArray, meta)
            }
        } else if (t == TUPLE_T) {
            uint16 len = _readArrayTupleLength(typ, i + 1);
            uint256 pTuple = p;
            p += 2;
            i += 3;

            uint256 total;
            for (uint16 j = 0; j < len; ++j) {
                bool isElemDynamic;
                uint256 elemSize;
                (p, i, isElemDynamic, elemSize) = _typeMeta(p, typ, i);
                if (isElemDynamic) {
                    isDynamic = true;
                }
                total += elemSize;
            }
            if (total > type(uint16).max) {
                revert InvalidType();
            }
            size = uint16(total);

            uint256 meta;
            if (isDynamic) {
                meta = size;
                size = 1;
            }
            assembly {
                mstore8(pTuple, shr(8, meta))
                mstore8(add(1, pTuple), meta)
            }
        } else {
            i = _typeEnd(typ, i);
            size = 1;
        }

        return (p, i, isDynamic, size);
    }

    function _typeMetaEnd(uint256 pMeta, bytes memory typ, uint256 i)
        private
        pure
        returns (uint256 pMeta_, uint256 i_)
    {
        bytes1 t = _read1(typ, i);

        if (t == DYNAMIC_ARRAY_T) {
            return _typeMetaEnd(pMeta, typ, i + 1);
        } else if (t == FIXED_ARRAY_T) {
            _readArrayTupleLength(typ, i + 1);
            return _typeMetaEnd(pMeta + 1, typ, i + 3);
        } else if (t == TUPLE_T) {
            uint16 len = _readArrayTupleLength(typ, i + 1);
            i += 3;
            pMeta += 2;
            for (uint16 j = 0; j < len; ++j) {
                (pMeta, i) = _typeMetaEnd(pMeta, typ, i);
            }
        } else {
            i = _typeEnd(typ, i);
        }

        return (pMeta, i);
    }

    function _countTupleFieldsPreorder(uint256 p, bytes memory typ, uint256 i)
        private
        pure
        returns (uint256 p_, uint256 i_)
    {
        bytes1 t = _read1(typ, i);

        if (t == DYNAMIC_ARRAY_T) {
            return _countTupleFieldsPreorder(p, typ, i + 1);
        } else if (t == FIXED_ARRAY_T) {
            _readArrayTupleLength(typ, i + 1);
            return _countTupleFieldsPreorder(p, typ, i + 3);
        } else if (t == TUPLE_T) {
            uint256 len = _readArrayTupleLength(typ, i + 1);
            assembly {
                mstore(p, len)
                p := add(32, p)
            }
            i += 3;
            for (uint256 j = 0; j < len; ++j) {
                (p, i) = _countTupleFieldsPreorder(p, typ, i);
            }
        } else {
            i = _typeEnd(typ, i);
        }

        return (p, i);
    }

    function _typeEnd(bytes memory typ, uint256 i) private pure returns (uint256) {
        bytes1 t = _read1(typ, i);

        if (t == INT_T || t == UINT_T || t == FIXED_BYTES_T) {
            _readValueTypeSize(typ, i + 1);
            return i + 2;
        } else if (t == BOOL_T || t == ADDRESS_T || t == STRING_T || t == BYTES_T) {
            return i + 1;
        } else if (t == DYNAMIC_ARRAY_T) {
            return _typeEnd(typ, i + 1);
        } else if (t == FIXED_ARRAY_T) {
            _readArrayTupleLength(typ, i + 1);
            return _typeEnd(typ, i + 3);
        } else if (t == TUPLE_T) {
            uint16 len = _readArrayTupleLength(typ, i + 1);
            i += 3;
            for (uint16 j = 0; j < len; ++j) {
                i = _typeEnd(typ, i);
            }
            return i;
        }

        revert InvalidType();
    }

    function _readValueTypeSize(bytes memory typ, uint256 i) private pure returns (uint8) {
        uint8 size = uint8(_read1(typ, i));
        if (size >= 1 && size <= 32) {
            return size;
        }
        revert InvalidType();
    }

    function _readArrayTupleLength(bytes memory typ, uint256 i) private pure returns (uint16) {
        uint16 size = uint16(_read2(typ, i));
        if (size > 0) {
            return size;
        }
        revert InvalidType();
    }

    function _read1(bytes memory b, uint256 i) private pure returns (bytes1) {
        if (i >= b.length) {
            revert InvalidType();
        }
        uint256 p;
        assembly {
            p := add(i, add(32, b))
        }
        return _read1(p);
    }

    function _read1(uint256 p) private pure returns (bytes1 $) {
        assembly {
            $ := and(shl(248, not(0)), mload(p))
        }
    }

    function _read2(bytes memory b, uint256 i) private pure returns (bytes2) {
        if (i + 1 >= b.length) {
            revert InvalidType();
        }
        uint256 p;
        assembly {
            p := add(i, add(32, b))
        }
        return _read2(p);
    }

    function _read2(uint256 p) private pure returns (bytes2 $) {
        assembly {
            $ := and(shl(240, not(0)), mload(p))
        }
    }
}
