const assert = require("assert");
const parse = require("..");

function test() {
    let t;

    // int 
    assert.throws(() => { parse("0x0000") }, Error("input is not a valid int type"));
    t = parse("0x0001");
    assert(t == "int8");
    t = parse("0x0002");
    assert(t == "int16");
    t = parse("0x0003");
    assert(t == "int24");
    t = parse("0x0004");
    assert(t == "int32");
    t = parse("0x0005");
    assert(t == "int40");
    t = parse("0x0006");
    assert(t == "int48");
    t = parse("0x0007");
    assert(t == "int56");
    t = parse("0x0008");
    assert(t == "int64");
    t = parse("0x0009");
    assert(t == "int72");
    t = parse("0x000a");
    assert(t == "int80");
    t = parse("0x000b");
    assert(t == "int88");
    t = parse("0x000c");
    assert(t == "int96");
    t = parse("0x0020");
    assert(t == "int256");
    assert.throws(() => { parse("0x0021") }, Error("input is not a valid int type"));

    // uint
    assert.throws(() => { parse("0x0100") }, Error("input is not a valid uint type"));
    t = parse("0x0101");
    assert(t == "uint8");
    t = parse("0x0102");
    assert(t == "uint16");
    t = parse("0x0103");
    assert(t == "uint24");
    t = parse("0x0104");
    assert(t == "uint32");
    t = parse("0x0105");
    assert(t == "uint40");
    t = parse("0x0106");
    assert(t == "uint48");
    t = parse("0x0107");
    assert(t == "uint56");
    t = parse("0x0108");
    assert(t == "uint64");
    t = parse("0x0109");
    assert(t == "uint72");
    t = parse("0x010a");
    assert(t == "uint80");
    t = parse("0x010b");
    assert(t == "uint88");
    t = parse("0x010c");
    assert(t == "uint96");
    t = parse("0x0120");
    assert(t == "uint256");
    assert.throws(() => { parse("0x0121") }, Error("input is not a valid uint type"));

    // bool
    t = parse("0x02");
    assert(t == "bool")
    assert.throws(() => { parse("0x0203") }, Error("input is not a valid typeBytes"));

    // string
    t = parse("0x03");
    assert(t == "string")

    // array[]
    t = parse("0x0407");
    assert(t == "address[]");
    t = parse("0x040407");
    assert(t == "address[][]");
    t = parse("0x040820");
    assert(t == "bytes32[]");
    t = parse("0x0406000200200020");
    assert(t == "tuple(int256,int256)[]");
    t = parse("0x04060002010107");
    assert(t == "tuple(uint8,address)[]");

    // arrayN
    t = parse("0x05000507");
    assert(t == "address[5]");
    t = parse("0x05000505000507");
    assert(t == "address[5][5]");

    // tuple
    t = parse("0x06000200200020");
    assert(t == "tuple(int256,int256)");
    t = parse("0x0600030407012006000200200020");
    assert(t == "tuple(address[],uint256,tuple(int256,int256))")
    t = parse("0x0600040407012004070120");
    assert(t == "tuple(address[],uint256,address[],uint256)");

    // address
    t = parse("0x07");
    assert(t == "address")

    // bytesN
    assert.throws(() => { parse("0x0800") }, Error("input is not a valid bytes type"));
    t = parse("0x0801");
    assert(t == "bytes1");
    t = parse("0x0802");
    assert(t == "bytes2");
    t = parse("0x0803");
    assert(t == "bytes3");
    t = parse("0x0804");
    assert(t == "bytes4");
    t = parse("0x0805");
    assert(t == "bytes5");
    t = parse("0x0806");
    assert(t == "bytes6");
    t = parse("0x0807");
    assert(t == "bytes7");
    t = parse("0x0808");
    assert(t == "bytes8");
    t = parse("0x0809");
    assert(t == "bytes9");
    t = parse("0x080a");
    assert(t == "bytes10");
    t = parse("0x080b");
    assert(t == "bytes11");
    t = parse("0x080c");
    assert(t == "bytes12");
    t = parse("0x0820");
    assert(t == "bytes32");
    assert.throws(() => { parse("0x0821") }, Error("input is not a valid bytes type"));

    // bytes
    t = parse("0x09");
    assert(t == "bytes")

    // tuple with field names
    t = parse("0x04060002010107", [['algorithm', 'addr']]);
    assert(t == "tuple(uint8 algorithm,address addr)[]")

    t = parse("0x06000206000106000206000203030600020120012006000102", [["a","b"], ["c"], ["e","f"], ["g","h"], ["i","j"], ["d"]]);
    assert(t == "tuple(tuple(tuple(tuple(string g,string h) e,tuple(uint256 i,uint256 j) f) c) a,tuple(bool d) b)");
}

test();