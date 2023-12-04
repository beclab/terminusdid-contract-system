// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {ABI} from "../../src/utils/ABI.sol";

contract ABITest is Test {
    using ABI for ABI.Var;
    using ABI for ABI.ReflectVar;

    ABI.Var v;

    /*//////////////////////////////////////////////////////////////
                    elementary types test of set and get
    //////////////////////////////////////////////////////////////*/

    // int8
    function testFuzzTypeInt8(int16 value) public {
        bytes2 intType = ABI.intT(8);

        if (value >= type(int8).min && value <= type(int8).max) {
            v.bind(bytes.concat(intType)).set(abi.encode(value));
            int8 got = abi.decode(v.bind(bytes.concat(intType)).get(), (int8));
            assertEq(got, value);
        } else {
            vm.expectRevert(ABI.InvalidValue.selector);
            v.bind(bytes.concat(intType)).set(abi.encode(value));
        }
    }

    // int128
    function testFuzzTypeInt128(int256 value) public {
        bytes2 intType = ABI.intT(128);

        if (value >= type(int128).min && value <= type(int128).max) {
            v.bind(bytes.concat(intType)).set(abi.encode(value));
            int128 got = abi.decode(v.bind(bytes.concat(intType)).get(), (int128));
            assertEq(got, value);
        } else {
            vm.expectRevert(ABI.InvalidValue.selector);
            v.bind(bytes.concat(intType)).set(abi.encode(value));
        }
    }

    // int256
    function testFuzzTypeInt256(int256 value) public {
        bytes2 intType = ABI.intT(256);

        v.bind(bytes.concat(intType)).set(abi.encode(value));
        int256 got = abi.decode(v.bind(bytes.concat(intType)).get(), (int256));
        assertEq(got, value);
    }

    // int800 expect to fail
    function testTypeInt800() public {
        vm.expectRevert(ABI.InvalidType.selector);
        ABI.intT(800);
    }

    // uint8
    function testFuzzTypeUInt8(uint16 value) public {
        bytes2 uintType = ABI.uintT(8);

        if (value <= type(uint8).max) {
            v.bind(bytes.concat(uintType)).set(abi.encode(value));
            uint8 got = abi.decode(v.bind(bytes.concat(uintType)).get(), (uint8));
            assertEq(got, value);
        } else {
            vm.expectRevert(ABI.InvalidValue.selector);
            v.bind(bytes.concat(uintType)).set(abi.encode(value));
        }
    }

    // uint128
    function testFuzzTypeUInt128(uint256 value) public {
        bytes2 uintType = ABI.uintT(128);

        if (value <= type(uint128).max) {
            v.bind(bytes.concat(uintType)).set(abi.encode(value));
            uint128 got = abi.decode(v.bind(bytes.concat(uintType)).get(), (uint128));
            assertEq(got, value);
        } else {
            vm.expectRevert(ABI.InvalidValue.selector);
            v.bind(bytes.concat(uintType)).set(abi.encode(value));
        }
    }

    // uint256
    function testFuzzTypeUInt256(uint256 value) public {
        bytes2 uintType = ABI.uintT(256);

        v.bind(bytes.concat(uintType)).set(abi.encode(value));
        uint256 got = abi.decode(v.bind(bytes.concat(uintType)).get(), (uint256));
        assertEq(got, value);
    }

    // uint800 expect to fail
    function testTypeUInt800() public {
        vm.expectRevert(ABI.InvalidType.selector);
        ABI.uintT(800);
    }

    // bool
    function testFuzzTypeBool(bool value) public {
        bytes1 boolType = ABI.boolT();

        v.bind(bytes.concat(boolType)).set(abi.encode(value));
        bool got = abi.decode(v.bind(bytes.concat(boolType)).get(), (bool));
        assertEq(got, value);
    }

    // string
    function testFuzzTypeString(string calldata value) public {
        bytes1 stringType = ABI.stringT();

        v.bind(bytes.concat(stringType)).set(abi.encode(value));
        string memory got = abi.decode(v.bind(bytes.concat(stringType)).get(), (string));
        assertEq(got, value);
    }

    // address
    function testFuzzTypeAddress(address value) public {
        bytes1 addressType = ABI.addressT();

        v.bind(bytes.concat(addressType)).set(abi.encode(value));
        address got = abi.decode(v.bind(bytes.concat(addressType)).get(), (address));
        assertEq(got, value);
    }

    // bytes1
    function testFuzzTypeBytes1(bytes1 value) public {
        bytes2 bytesType = ABI.bytesT(1);

        v.bind(bytes.concat(bytesType)).set(abi.encode(value));
        bytes1 got = abi.decode(v.bind(bytes.concat(bytesType)).get(), (bytes1));
        assertEq(got, value);
    }

    // bytes16
    function testFuzzTypeBytes16(bytes16 value) public {
        bytes2 bytesType = ABI.bytesT(16);

        v.bind(bytes.concat(bytesType)).set(abi.encode(value));
        bytes16 got = abi.decode(v.bind(bytes.concat(bytesType)).get(), (bytes16));
        assertEq(got, value);
    }

    // bytes32
    function testFuzzTypeBytes32(bytes32 value) public {
        bytes2 bytesType = ABI.bytesT(32);

        v.bind(bytes.concat(bytesType)).set(abi.encode(value));
        bytes32 got = abi.decode(v.bind(bytes.concat(bytesType)).get(), (bytes32));
        assertEq(got, value);
    }

    // bytes33 expect to fail
    function testTypeBytes33() public {
        vm.expectRevert(ABI.InvalidType.selector);
        ABI.bytesT(33);
    }

    // bytes
    function testFuzzTypeBytes(bytes calldata value) public {
        bytes2 bytesType = ABI.bytesT();

        v.bind(bytes.concat(bytesType)).set(abi.encode(value));
        bytes memory got = abi.decode(v.bind(bytes.concat(bytesType)).get(), (bytes));
        assertEq(got, value);
    }

    // arrayN fix array length cannot be 0
    function testTypeArray0() public {
        vm.expectRevert(ABI.InvalidType.selector);
        ABI.arrayT(bytes.concat(ABI.uintT(256)), 0);
    }

    // arrayN fix-length array
    function testFuzzTypeArrayN(uint8 length) public {
        vm.assume(length != 0);

        bytes memory uintArrayNType = ABI.arrayT(bytes.concat(ABI.uintT(256)), length);
        for (uint256 i; i < length; i++) {
            v.bind(uintArrayNType).at(i).set(abi.encode(i));
        }
    }

    function testTypeArrayN() public {
        bytes memory intArray3Type = ABI.arrayT(bytes.concat(ABI.intT(256)), 3);

        int256[3] memory intArray3 = [type(int256).max, type(int256).min, 0];
        v.bind(intArray3Type).set(abi.encode(intArray3));

        int256[3] memory got = abi.decode(v.bind(intArray3Type).get(), (int256[3]));
        assertEq(got[0], intArray3[0]);
        assertEq(got[1], intArray3[1]);
        assertEq(got[2], intArray3[2]);

        v.bind(intArray3Type).at(0).set(abi.encode(100));
        v.bind(intArray3Type).at(1).set(abi.encode(150));
        v.bind(intArray3Type).at(2).set(abi.encode(200));

        got = abi.decode(v.bind(intArray3Type).get(), (int256[3]));
        assertEq(got[0], 100);
        assertEq(got[1], 150);
        assertEq(got[2], 200);
    }

    // array dynamic length array
    function testFuzzTypeArray(uint8 length, uint256 value) public {
        bytes memory uintArrayType = ABI.arrayT(bytes.concat(ABI.uintT(256)));
        for (uint256 i; i < length; i++) {
            v.bind(uintArrayType).push(abi.encode(i));
        }
        assertEq(v.bind(uintArrayType).length(), uint256(length));

        v.bind(uintArrayType).push(abi.encode(value));
        assertEq(v.bind(uintArrayType).length(), uint256(length) + 1);

        uint256[] memory got = abi.decode(v.bind(uintArrayType).get(), (uint256[]));
        for (uint256 i; i < length; i++) {
            assertEq(got[i], i);
        }
        assertEq(got[length], value);

        uint256[] memory arrayValue = new uint[](2);
        arrayValue[0] = type(uint256).max;
        arrayValue[1] = type(uint256).min;

        v.bind(uintArrayType).set(abi.encode(arrayValue));

        got = abi.decode(v.bind(uintArrayType).get(), (uint256[]));
        assertEq(got[0], arrayValue[0]);
        assertEq(got[1], arrayValue[1]);
        assertEq(v.bind(uintArrayType).length(), 2);

        v.bind(uintArrayType).pop();
        got = abi.decode(v.bind(uintArrayType).get(), (uint256[]));
        assertEq(got[0], arrayValue[0]);
        assertEq(v.bind(uintArrayType).length(), 1);

        v.bind(uintArrayType).pop();
        got = abi.decode(v.bind(uintArrayType).get(), (uint256[]));
        assertEq(v.bind(uintArrayType).length(), 0);
    }

    // tuple
    struct TupleNormal {
        bool xx;
        uint8[] yy;
    }

    function testFuzzTypeTuple(bool boolValue, uint8[] calldata uint8ArrayData) public {
        bytes memory boolType = bytes.concat(ABI.boolT());
        bytes memory uint8Array = ABI.arrayT(bytes.concat(ABI.uintT(8)));
        bytes memory myType = ABI.tupleT(bytes.concat(boolType, uint8Array));

        v.bind(myType).set(abi.encode(TupleNormal(boolValue, uint8ArrayData)));
        TupleNormal memory got = abi.decode(v.bind(myType).get(), (TupleNormal));
        assertEq(got.xx, boolValue);
        assertEq(got.yy.length, uint8ArrayData.length);

        //"Index out of bounds"
        vm.expectRevert();
        assertEq(got.yy[got.yy.length], 0);
    }

    /*//////////////////////////////////////////////////////////////
                    edge cases
    //////////////////////////////////////////////////////////////*/

    function testFuzzTypeCompatible(bytes16 bytes16Value, uint32 uint32Value, uint64 uint64Value) public {
        vm.assume(uint64Value > type(uint32).max);

        // bytesN
        bytes2 bytes32Type = ABI.bytesT(32);

        v.bind(bytes.concat(bytes32Type)).set(abi.encode(bytes16Value));

        bytes16 got = abi.decode(v.bind(bytes.concat(bytes32Type)).get(), (bytes16));
        assertEq(got, bytes16Value);

        // uintN
        bytes2 uintType = ABI.uintT(64);

        v.bind(bytes.concat(uintType)).set(abi.encode(uint32Value));

        uint32 gotUint32 = abi.decode(v.bind(bytes.concat(uintType)).get(), (uint32));
        assertEq(gotUint32, uint32Value);

        // reverse operation revert
        uintType = ABI.uintT(32);

        vm.expectRevert(ABI.InvalidValue.selector);
        v.bind(bytes.concat(uintType)).set(abi.encode(uint64Value));
    }

    // occupy 1 slot fully and start next slot partially
    struct Tuple1 {
        uint128 x;
        uint128 y;
        // next slot
        uint16 z;
    }

    function testFuzzTypeTuple1(uint128 x, uint128 y, uint16 z) public {
        bytes memory myType = ABI.tupleT(
            bytes.concat(bytes.concat(ABI.uintT(128)), bytes.concat(ABI.uintT(128)), bytes.concat(ABI.uintT(16)))
        );

        v.bind(myType).at(0).set(abi.encode(x));
        v.bind(myType).at(1).set(abi.encode(y));
        v.bind(myType).at(2).set(abi.encode(z));

        Tuple1 memory got = abi.decode(v.bind(myType).get(), (Tuple1));
        assertEq(got.x, x);
        assertEq(got.y, y);
        assertEq(got.z, z);
    }

    // occupy 1 slot partially and start next slot partially
    struct Tuple2 {
        uint128 x;
        uint120 y;
        // next slot
        uint16 z;
    }

    function testFuzzTypeTuple2(uint128 x, uint120 y, uint16 z) public {
        bytes memory myType = ABI.tupleT(
            bytes.concat(bytes.concat(ABI.uintT(128)), bytes.concat(ABI.uintT(120)), bytes.concat(ABI.uintT(16)))
        );

        v.bind(myType).at(0).set(abi.encode(x));
        v.bind(myType).at(1).set(abi.encode(y));
        v.bind(myType).at(2).set(abi.encode(z));

        Tuple2 memory got = abi.decode(v.bind(myType).get(), (Tuple2));
        assertEq(got.x, x);
        assertEq(got.y, y);
        assertEq(got.z, z);
    }

    // array elements can fill in a slot: uint16[], uint16[8], uint16[16]
    function testFuzzTypeDifferentArrays(uint16[] calldata x, uint16[8] calldata y, uint16[16] calldata z) public {
        bytes memory myType = ABI.arrayT(bytes.concat(ABI.uintT(16)));

        v.bind(myType).set(abi.encode(x));
        uint16[] memory got = abi.decode(v.bind(myType).get(), (uint16[]));
        assertEq(got.length, x.length);

        myType = ABI.arrayT(bytes.concat(ABI.uintT(16)), 8);

        v.bind(myType).set(abi.encode(y));
        uint16[8] memory gotUint8Array = abi.decode(v.bind(myType).get(), (uint16[8]));
        assertEq(gotUint8Array.length, y.length);
        for (uint256 i = 0; i < y.length; i++) {
            assertEq(gotUint8Array[i], y[i]);
        }

        myType = ABI.arrayT(bytes.concat(ABI.uintT(16)), 16);

        v.bind(myType).set(abi.encode(z));
        uint16[16] memory gotUint16Array = abi.decode(v.bind(myType).get(), (uint16[16]));
        assertEq(gotUint16Array.length, z.length);
        for (uint256 i = 0; i < z.length; i++) {
            assertEq(gotUint16Array[i], z[i]);
        }
    }

    // array elements cannot fill in a slot: uint24[], uint24[5], uint24[10]
    function testFuzzTypeDifferentArrays1(uint24[] calldata x, uint24[5] calldata y, uint24[10] calldata z) public {
        bytes memory myType = ABI.arrayT(bytes.concat(ABI.uintT(24)));

        v.bind(myType).set(abi.encode(x));
        uint24[] memory got = abi.decode(v.bind(myType).get(), (uint24[]));
        assertEq(got.length, x.length);

        myType = ABI.arrayT(bytes.concat(ABI.uintT(24)), 5);

        v.bind(myType).set(abi.encode(y));
        uint24[5] memory gotUint8Array = abi.decode(v.bind(myType).get(), (uint24[5]));
        assertEq(gotUint8Array.length, y.length);
        for (uint256 i = 0; i < y.length; i++) {
            assertEq(gotUint8Array[i], y[i]);
        }

        myType = ABI.arrayT(bytes.concat(ABI.uintT(24)), 10);

        v.bind(myType).set(abi.encode(z));
        uint24[10] memory gotUint16Array = abi.decode(v.bind(myType).get(), (uint24[10]));
        assertEq(gotUint16Array.length, z.length);
        for (uint256 i = 0; i < z.length; i++) {
            assertEq(gotUint16Array[i], z[i]);
        }
    }

    // array elements cannot fill in a slot and they are in different slots: address[], address[5]
    function testFuzzTypeDifferentArrays2(address[] calldata x, address[5] calldata y) public {
        bytes memory myType = ABI.arrayT(bytes.concat(ABI.addressT()));

        v.bind(myType).set(abi.encode(x));
        address[] memory got = abi.decode(v.bind(myType).get(), (address[]));
        assertEq(got.length, x.length);

        myType = ABI.arrayT(bytes.concat(ABI.addressT()), 5);

        v.bind(myType).set(abi.encode(y));
        address[5] memory gotAddress5Array = abi.decode(v.bind(myType).get(), (address[5]));
        assertEq(gotAddress5Array.length, y.length);
        for (uint256 i = 0; i < y.length; i++) {
            assertEq(gotAddress5Array[i], y[i]);
        }
    }

    // array elements can fill in a slot and they are in different slots: uint256[], uint256[5]
    function testFuzzTypeDifferentArrays3(uint256[] calldata x, uint256[5] calldata y) public {
        bytes memory myType = ABI.arrayT(bytes.concat(ABI.uintT(256)));

        v.bind(myType).set(abi.encode(x));
        uint256[] memory got = abi.decode(v.bind(myType).get(), (uint256[]));
        assertEq(got.length, x.length);

        myType = ABI.arrayT(bytes.concat(ABI.uintT(256)), 5);

        v.bind(myType).set(abi.encode(y));
        uint256[5] memory gotUint5Array = abi.decode(v.bind(myType).get(), (uint256[5]));
        assertEq(gotUint5Array.length, y.length);
        for (uint256 i = 0; i < y.length; i++) {
            assertEq(gotUint5Array[i], y[i]);
        }
    }

    // tuple array occupy mutiple slots fully: Tuple3[], Tuple3[5]
    struct Tuple3 {
        uint256 x;
        uint256 y;
    }

    function testFuzzTypeTuple3(Tuple3[] calldata a, Tuple3[5] calldata b) public {
        bytes memory myType =
            ABI.arrayT(ABI.tupleT(bytes.concat(bytes.concat(ABI.uintT(256)), bytes.concat(ABI.uintT(256)))));
        v.bind(myType).set(abi.encode(a));
        Tuple3[] memory got = abi.decode(v.bind(myType).get(), (Tuple3[]));
        assertEq(got.length, a.length);

        myType = ABI.arrayT(ABI.tupleT(bytes.concat(bytes.concat(ABI.uintT(256)), bytes.concat(ABI.uintT(256)))), 5);
        v.bind(myType).set(abi.encode(b));
        Tuple3[5] memory gotTuple5Array = abi.decode(v.bind(myType).get(), (Tuple3[5]));
        assertEq(gotTuple5Array.length, b.length);
        for (uint256 i = 0; i < b.length; i++) {
            assertEq(gotTuple5Array[i].x, b[i].x);
            assertEq(gotTuple5Array[i].y, b[i].y);
        }
    }

    // arrays includes dynamic element: bytes[], bytes[5], string[][5], string[5][]
    function testFuzzTypeDifferentArrays4(
        bytes[] calldata a,
        bytes[5] calldata b,
        string[][5] calldata c,
        string[5][] calldata d
    ) public {
        bytes memory myType = ABI.arrayT(bytes.concat(ABI.bytesT()));
        v.bind(myType).set(abi.encode(a));
        bytes[] memory got = abi.decode(v.bind(myType).get(), (bytes[]));
        assertEq(got.length, a.length);

        myType = ABI.arrayT(bytes.concat(ABI.bytesT()), 5);
        v.bind(myType).set(abi.encode(b));
        bytes[5] memory gotBytes5Array = abi.decode(v.bind(myType).get(), (bytes[5]));
        assertEq(gotBytes5Array.length, b.length);
        for (uint256 i = 0; i < b.length; i++) {
            assertEq(gotBytes5Array[i], b[i]);
        }

        myType = ABI.arrayT(ABI.arrayT(bytes.concat(ABI.stringT())), 5);
        v.bind(myType).set(abi.encode(c));
        string[][5] memory got5StringArrayOfStringArray = abi.decode(v.bind(myType).get(), (string[][5]));
        assertEq(got5StringArrayOfStringArray.length, c.length);

        myType = ABI.arrayT(ABI.arrayT(bytes.concat(ABI.stringT()), 5));
        v.bind(myType).set(abi.encode(d));
        string[5][] memory gotStringArrayOf5StringArray = abi.decode(v.bind(myType).get(), (string[5][]));
        assertEq(gotStringArrayOf5StringArray.length, d.length);
    }

    // arrays includes dynamic element: bytes[][] (takes long time...)
    function testFuzzTypeDifferentArrays5(bytes[][] calldata a) public {
        bytes memory myType = ABI.arrayT(ABI.arrayT(bytes.concat(ABI.bytesT())));
        v.bind(myType).set(abi.encode(a));
        bytes[][] memory got = abi.decode(v.bind(myType).get(), (bytes[][]));
        assertEq(got.length, a.length);
    }

    struct Tuple4 {
        uint256[] x;
        string[] y;
    }

    // arrays includes dynamic element: Tuple4[] (takes long time...)
    function testFuzzTypeTuple4(Tuple4[] calldata a) public {
        bytes memory myType = ABI.arrayT(
            ABI.tupleT(bytes.concat(ABI.arrayT(bytes.concat(ABI.uintT(256))), ABI.arrayT(bytes.concat(ABI.stringT()))))
        );
        v.bind(myType).set(abi.encode(a));
        Tuple4[] memory got = abi.decode(v.bind(myType).get(), (Tuple4[]));
        assertEq(got.length, a.length);
        for (uint256 i = 0; i < a.length; i++) {
            for (uint256 j = 0; j < a[i].x.length; j++) {
                assertEq(got[i].x[j], a[i].x[j]);
            }
            for (uint256 k = 0; k < a[i].y.length; k++) {
                assertEq(got[i].y[k], a[i].y[k]);
            }
        }
    }

    struct Tuple5 {
        uint256 x;
        bytes y;
        uint256 z;
    }

    // tuple that has dynamic type in the middle
    function testFuzzTypeTuple5(Tuple5 calldata a) public {
        bytes memory myType = ABI.tupleT(
            bytes.concat(bytes.concat(ABI.uintT(256)), bytes.concat(ABI.bytesT()), bytes.concat(ABI.uintT(256)))
        );

        v.bind(myType).set(abi.encode(a));
        Tuple5 memory got = abi.decode(v.bind(myType).get(), (Tuple5));
        assertEq(got.x, a.x);
        assertEq(got.y, a.y);
        assertEq(got.z, a.z);
    }

    struct Tuple6_1 {
        bytes[] x;
        uint256 y;
    }

    struct Tuple6_2 {
        uint256 x;
        bytes[] y;
    }

    // tuple that has dynamic type in the one side
    function testFuzzTypeTuple6(Tuple6_1 calldata a, Tuple6_2 calldata b) public {
        bytes memory myType =
            ABI.tupleT(bytes.concat(ABI.arrayT(bytes.concat(ABI.bytesT())), bytes.concat(ABI.uintT(256))));

        v.bind(myType).set(abi.encode(a));
        Tuple6_1 memory got = abi.decode(v.bind(myType).get(), (Tuple6_1));
        assertEq(got.x.length, a.x.length);
        for (uint256 i = 0; i < a.x.length; i++) {
            assertEq(got.x[i], a.x[i]);
        }
        assertEq(got.y, a.y);

        myType = ABI.tupleT(bytes.concat(bytes.concat(ABI.uintT(256)), ABI.arrayT(bytes.concat(ABI.bytesT()))));

        v.bind(myType).set(abi.encode(b));
        Tuple6_2 memory got6_2 = abi.decode(v.bind(myType).get(), (Tuple6_2));
        assertEq(got6_2.x, b.x);
        assertEq(got6_2.y.length, b.y.length);
        for (uint256 i = 0; i < b.y.length; i++) {
            assertEq(got6_2.y[i], b.y[i]);
        }
    }

    function testWrongValueAssignment() public {
        // uint16
        uint16 x = 8;
        bytes memory value = abi.encode(x);
        value[0] = hex"88";
        vm.expectRevert(ABI.InvalidValue.selector);
        v.bind(bytes.concat(ABI.uintT(16))).set(value);
    }

    function testWrongValueAssignment1() public {
        // bool
        uint16 x = 8;
        bytes memory value = abi.encode(x);
        value[0] = hex"88";
        vm.expectRevert(ABI.InvalidValue.selector);
        v.bind(bytes.concat(ABI.boolT())).set(value);
    }

    function testWrongValueAssignment2() public {
        // address
        uint16 x = 8;
        bytes memory value = abi.encode(x);
        value[0] = hex"88";
        vm.expectRevert(ABI.InvalidValue.selector);
        v.bind(bytes.concat(ABI.addressT())).set(value);
    }

    function testWrongValueAssignment3() public {
        // bytes16
        uint16 x = 8;
        bytes memory value = abi.encode(x);
        value[0] = hex"88";
        vm.expectRevert(ABI.InvalidValue.selector);
        v.bind(bytes.concat(ABI.bytesT(16))).set(value);
    }

    function testWrongValueAssignment4() public {
        // uint256[]
        uint16 x = 8;
        bytes memory value = abi.encode(x);
        value[0] = hex"88";
        vm.expectRevert(ABI.InvalidValue.selector);
        v.bind(bytes.concat(ABI.arrayT(bytes.concat(ABI.uintT(256))))).set(value);
    }

    function testWrongValueAssignment5() public {
        // simple tuple
        uint16 x = 8;
        bytes memory value = abi.encode(x);
        value[0] = hex"88";
        vm.expectRevert(ABI.InvalidValue.selector);
        v.bind(ABI.tupleT(bytes.concat(bytes.concat(ABI.uintT(256)), bytes.concat(ABI.uintT(256))))).set(value);
    }

    function testFuzzWrongIndex(uint256[2] calldata a) public {
        bytes memory myType = ABI.arrayT(bytes.concat(ABI.uintT(256)), 2);
        v.bind(myType).set(abi.encode(a));
        vm.expectRevert(ABI.InvalidIndex.selector);
        v.bind(myType).at(2).set(abi.encode(100));
    }

    function testWrongIndex() public {
        bytes memory myType = ABI.tupleT(bytes.concat(bytes.concat(ABI.uintT(256)), bytes.concat(ABI.uintT(256))));
        vm.expectRevert(ABI.InvalidIndex.selector);
        v.bind(myType).at(2).set(abi.encode(100));
    }

    function testWrongOp() public {
        bytes memory myType = bytes.concat(ABI.uintT(256));
        vm.expectRevert(ABI.InvalidOp.selector);
        v.bind(myType).at(2).set(abi.encode(100));
    }

    function testWrongOp1() public {
        bytes memory myType = bytes.concat(ABI.uintT(256));
        vm.expectRevert(ABI.InvalidOp.selector);
        v.bind(myType).push(abi.encode(100));
    }

    function testWrongOp2() public {
        bytes memory myType = bytes.concat(ABI.uintT(256));
        vm.expectRevert(ABI.InvalidOp.selector);
        v.bind(myType).length();
    }

    function testWrongOp3() public {
        bytes memory myType = bytes.concat(ABI.uintT(256));
        vm.expectRevert(ABI.InvalidOp.selector);
        v.bind(myType).pop();
    }

    /*//////////////////////////////////////////////////////////////
                    layout test
    //////////////////////////////////////////////////////////////*/

    string str = "test data";

    // string
    function testLayoutString() public {
        bytes memory myType = bytes.concat(ABI.stringT());

        ABI.Var storage vs = _stringToABIVar(str);
        vs.bind(myType).set(abi.encode("change data"));

        string memory got = abi.decode(vs.bind(myType).get(), (string));
        string memory strM = str;
        assertEq(bytes(strM), bytes(got));
    }

    function _stringToABIVar(string storage s) private pure returns (ABI.Var storage vs) {
        assembly {
            vs.slot := s.slot
        }
    }

    // bytes
    function testFuzzLayoutBytes(bytes calldata data) public {
        vm.assume(data.length > 0);

        bytes memory typeT = bytes.concat(ABI.bytesT());
        v.bind(typeT).set(abi.encode(data));

        bytes storage b = _toBytesStorage(v);
        b[b.length - 1] = 0xff;

        bytes memory valueAfter = abi.decode(v.bind(typeT).get(), (bytes));
        assert(valueAfter[valueAfter.length - 1] == 0xff);
    }

    function _toBytesStorage(ABI.Var storage vv) private pure returns (bytes storage b) {
        assembly {
            b.slot := vv.slot
        }
    }

    // uint256[]
    function testFuzzLayoutArray(uint256[] calldata data) public {
        vm.assume(data.length > 1);

        bytes memory typeT = ABI.arrayT(bytes.concat(ABI.uintT(256)));
        v.bind(typeT).set(abi.encode(data));

        uint256[] storage a = _toArrayStorage(v);
        a[0] = 100;
        a[a.length - 1] = 200;

        uint256[] memory valueAfter = abi.decode(v.bind(typeT).get(), (uint256[]));
        assertEq(valueAfter[0], 100);
        assertEq(valueAfter[valueAfter.length - 1], 200);
    }

    function _toArrayStorage(ABI.Var storage vv) private pure returns (uint256[] storage a) {
        assembly {
            a.slot := vv.slot
        }
    }

    // fix-length array uint256[10]
    function testFuzzLayoutFixLengthArray(uint256[10] calldata data) public {
        bytes memory typeT = ABI.arrayT(bytes.concat(ABI.uintT(256)), 10);
        v.bind(typeT).set(abi.encode(data));

        uint256[10] storage a = _toFixLengthArrayStorage(v);
        for (uint256 i = 0; i < 10; i++) {
            a[i] = i;
        }

        uint256[10] memory valueAfter = abi.decode(v.bind(typeT).get(), (uint256[10]));
        for (uint256 i = 0; i < 10; i++) {
            valueAfter[i] = i;
        }
    }

    function _toFixLengthArrayStorage(ABI.Var storage vv) private pure returns (uint256[10] storage a) {
        bytes32 vvv;
        assembly {
            vvv := vv.slot
        }
        vvv = keccak256(bytes.concat(vvv));
        assembly {
            a.slot := vvv
        }
    }

    // tuple
    struct Tuple7 {
        int256 x;
        uint256 y;
        bool z;
        string a;
        address b;
    }

    function testFuzzLayoutTuple(Tuple7 calldata data) public {
        bytes memory typeT =
            ABI.tupleT(bytes.concat(ABI.intT(256), ABI.uintT(256), ABI.boolT(), ABI.stringT(), ABI.addressT()));

        v.bind(typeT).set(abi.encode(data));

        Tuple7 storage t = _toTupleStorage(v);
        t.x = type(int256).min;
        t.y = type(uint256).max;
        t.z = true;
        t.a = "this is DID ABI test";
        t.b = address(this);

        Tuple7 memory valueAfter = abi.decode(v.bind(typeT).get(), (Tuple7));

        assertEq(valueAfter.x, type(int256).min);
        assertEq(valueAfter.y, type(uint256).max);
        assertEq(valueAfter.z, true);
        assertEq(valueAfter.a, "this is DID ABI test");
        assertEq(valueAfter.b, address(this));
    }

    function _toTupleStorage(ABI.Var storage vv) private pure returns (Tuple7 storage t) {
        bytes32 vvv;
        assembly {
            vvv := vv.slot
        }
        vvv = keccak256(bytes.concat(vvv));
        assembly {
            t.slot := vvv
        }
    }

    /*//////////////////////////////////////////////////////////////
                    complex struct test
    //////////////////////////////////////////////////////////////*/
    struct Shapes {
        Circle c;
        Rectangle r;
        Octagon[8] os;
    }

    struct Point {
        uint128 x;
        uint128 y;
    }

    struct Circle {
        Point centre;
        uint256 radius;
    }

    struct Rectangle {
        Point leftLow;
        Point rightHigh;
    }

    struct Octagon {
        Point[8] points;
    }

    function testFuzzComplexStruct(Shapes calldata data) public {
        bytes memory typePoint = ABI.tupleT(bytes.concat(ABI.uintT(128), ABI.uintT(128)));
        bytes memory typeCircle = ABI.tupleT(bytes.concat(typePoint, ABI.uintT(256)));
        bytes memory typeRectangle = ABI.tupleT(bytes.concat(typePoint, typePoint));
        bytes memory typeOctagon = ABI.tupleT(ABI.arrayT(typePoint, 8));

        bytes memory typeShapes = ABI.tupleT(bytes.concat(typeCircle, typeRectangle, ABI.arrayT(typeOctagon, 8)));

        v.bind(typeShapes).set(abi.encode(data));
        Shapes memory got = abi.decode(v.bind(typeShapes).get(), (Shapes));
        assertEq(got.c.centre.x, data.c.centre.x);
        assertEq(got.c.centre.y, data.c.centre.y);
        assertEq(got.c.radius, data.c.radius);

        assertEq(got.r.leftLow.x, data.r.leftLow.x);
        assertEq(got.r.leftLow.y, data.r.leftLow.y);
        assertEq(got.r.rightHigh.x, data.r.rightHigh.x);
        assertEq(got.r.rightHigh.y, data.r.rightHigh.y);

        for (uint256 i = 0; i < 8; i++) {
            for (uint256 j = 0; j < 8; j++) {
                assertEq(got.os[i].points[j].x, data.os[i].points[j].x);
                assertEq(got.os[i].points[j].y, data.os[i].points[j].y);
            }
        }
    }

    struct Polygon {
        Point[] points;
    }

    struct Shapes1 {
        Polygon[] ps;
    }

    // (takes long time...)
    function testFuzzComplexStruct1(Shapes1 calldata data) public {
        bytes memory typePoint = ABI.tupleT(bytes.concat(ABI.uintT(128), ABI.uintT(128)));
        bytes memory typePolygon = ABI.tupleT(ABI.arrayT(typePoint));

        bytes memory typeShapes1 = ABI.tupleT(ABI.arrayT(typePolygon));

        v.bind(typeShapes1).set(abi.encode(data));
        Shapes1 memory got = abi.decode(v.bind(typeShapes1).get(), (Shapes1));
        for (uint256 i = 0; i < got.ps.length; i++) {
            for (uint256 j = 0; j < got.ps[i].points.length; j++) {
                assertEq(got.ps[i].points[j].x, data.ps[i].points[j].x);
                assertEq(got.ps[i].points[j].y, data.ps[i].points[j].y);
            }
        }
    }

    struct Tx {
        address from;
        address to;
        uint256 nonce;
        uint256 gasPrice;
        uint256 gasLimit;
        uint256 value;
        bytes data;
        bytes32 r;
        bytes32 s;
        bytes1 v;
    }

    struct BlockHeader {
        bytes32 parentHash;
        bytes32[] unclesHash;
        address minerAddress;
        bytes32 stateRoot;
        bytes32 txRoot;
        uint256 blockNum;
        uint256 gasLimit;
        uint256 gasUsed;
        uint256 diff;
        uint256 timestamp;
        bytes extraData;
    }

    struct Block {
        BlockHeader header;
        Tx[] txs;
    }

    function testFuzzComplexStruct2(Block calldata data) public {
        bytes memory typeTx = ABI.tupleT(
            bytes.concat(
                ABI.addressT(),
                ABI.addressT(),
                ABI.uintT(256),
                ABI.uintT(256),
                ABI.uintT(256),
                ABI.uintT(256),
                ABI.bytesT(),
                ABI.bytesT(32),
                ABI.bytesT(32),
                ABI.bytesT(1)
            )
        );
        bytes memory typeTxs = ABI.arrayT(typeTx);
        bytes memory typeBlockHeader = ABI.tupleT(
            bytes.concat(
                ABI.bytesT(32),
                ABI.arrayT(bytes.concat(ABI.bytesT(32))),
                ABI.addressT(),
                ABI.bytesT(32),
                ABI.bytesT(32),
                ABI.uintT(256),
                ABI.uintT(256),
                ABI.uintT(256),
                ABI.uintT(256),
                ABI.uintT(256),
                ABI.bytesT()
            )
        );
        bytes memory typeBlock = ABI.tupleT(bytes.concat(typeBlockHeader, typeTxs));

        v.bind(typeBlock).set(abi.encode(data));
        Block memory got = abi.decode(v.bind(typeBlock).get(), (Block));

        assertEq32(got.header.parentHash, data.header.parentHash);
        for (uint256 i = 0; i < got.header.unclesHash.length; i++) {
            assertEq32(got.header.unclesHash[i], data.header.unclesHash[i]);
        }
        assertEq(got.header.minerAddress, data.header.minerAddress);
        assertEq32(got.header.stateRoot, data.header.stateRoot);
        assertEq32(got.header.txRoot, data.header.txRoot);
        assertEq(got.header.blockNum, data.header.blockNum);
        assertEq(got.header.gasLimit, data.header.gasLimit);
        assertEq(got.header.gasUsed, data.header.gasUsed);
        assertEq(got.header.diff, data.header.diff);
        assertEq(got.header.timestamp, data.header.timestamp);
        assertEq0(got.header.extraData, data.header.extraData);

        for (uint256 i = 0; i < got.txs.length; i++) {
            assertEq(got.txs[i].from, data.txs[i].from);
            assertEq(got.txs[i].to, data.txs[i].to);
            assertEq(got.txs[i].nonce, data.txs[i].nonce);
            assertEq(got.txs[i].gasPrice, data.txs[i].gasPrice);
            assertEq(got.txs[i].gasLimit, data.txs[i].gasLimit);
            assertEq(got.txs[i].value, data.txs[i].value);
            assertEq0(got.txs[i].data, data.txs[i].data);
            assertEq32(got.txs[i].r, data.txs[i].r);
            assertEq32(got.txs[i].s, data.txs[i].s);
            assertEq(got.txs[i].v, data.txs[i].v);
        }
    }

    struct A {
        bytes32 x;
        bytes y;
    }

    struct B {
        A a;
    }

    struct C {
        B b;
    }

    struct D {
        C c;
    }

    struct E {
        D d;
    }

    struct F {
        E e;
    }

    struct G {
        F f;
    }

    struct H {
        G g;
    }

    struct I {
        H h;
    }

    struct J {
        I i;
    }

    struct K {
        J j;
    }

    function testFuzzComplexStruct3(K calldata data) public {
        bytes memory typeA = ABI.tupleT(bytes.concat(ABI.bytesT(32), ABI.bytesT()));
        bytes memory typeB = ABI.tupleT(typeA);
        bytes memory typeC = ABI.tupleT(typeB);
        bytes memory typeD = ABI.tupleT(typeC);
        bytes memory typeE = ABI.tupleT(typeD);
        bytes memory typeF = ABI.tupleT(typeE);
        bytes memory typeG = ABI.tupleT(typeF);
        bytes memory typeH = ABI.tupleT(typeG);
        bytes memory typeI = ABI.tupleT(typeH);
        bytes memory typeJ = ABI.tupleT(typeI);
        bytes memory typeK = ABI.tupleT(typeJ);

        v.bind(typeK).set(abi.encode(data));
        K memory got = abi.decode(v.bind(typeK).get(), (K));
        assertEq32(got.j.i.h.g.f.e.d.c.b.a.x, data.j.i.h.g.f.e.d.c.b.a.x);
        assertEq0(got.j.i.h.g.f.e.d.c.b.a.y, data.j.i.h.g.f.e.d.c.b.a.y);
    }

    /*//////////////////////////////////////////////////////////////
                    type test
    //////////////////////////////////////////////////////////////*/
    function testValidateType() public {
        bytes memory myType;
        // valid type
        for (uint16 i = 8; i <= 256; i += 8) {
            // int
            myType = bytes.concat(ABI.intT(i));
            ABI.validateType(myType);
            // uint
            myType = bytes.concat(ABI.uintT(i));
            ABI.validateType(myType);
        }
        // bool
        myType = bytes.concat(ABI.boolT());
        ABI.validateType(myType);
        // string
        myType = bytes.concat(ABI.stringT());
        ABI.validateType(myType);
        // address
        myType = bytes.concat(ABI.addressT());
        ABI.validateType(myType);
        for (uint8 i = 1; i <= 32; i++) {
            // bytes1~32
            myType = bytes.concat(ABI.bytesT(i));
            ABI.validateType(myType);
        }
        // bytes
        myType = bytes.concat(ABI.bytesT());
        ABI.validateType(myType);

        bytes memory wrongType = bytes(hex"12345678");
        vm.expectRevert(ABI.InvalidType.selector);
        ABI.validateType(wrongType);
        wrongType = bytes(hex"2453654764574235");
        vm.expectRevert(ABI.InvalidType.selector);
        ABI.validateType(wrongType);
        wrongType = bytes(hex"0000");
        vm.expectRevert(ABI.InvalidType.selector);
        ABI.validateType(wrongType);
    }
}
