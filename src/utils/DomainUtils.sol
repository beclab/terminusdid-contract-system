// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

library DomainUtils {
    using {asSlice} for string;
    using DomainUtils for uint256;

    function asSlice(string memory self) internal pure returns (uint256 $) {
        assembly {
            let l := mload(self)
            if shr(128, l) { revert(0, 0) }
            let p := add(32, self)
            if shr(128, add(p, l)) { revert(0, 0) }
            $ := or(l, shl(128, p))
        }
    }

    function isEmpty(string memory self) internal pure returns (bool $) {
        return bytes(self).length == 0;
    }

    function isEmpty(uint256 slice) internal pure returns (bool $) {
        assembly {
            $ := iszero(shl(128, slice))
        }
    }

    function toString(uint256 slice) internal pure returns (string memory $) {
        assembly ("memory-safe") {
            $ := mload(0x40)
            let l := and(slice, shr(128, not(0)))
            for {
                let ps := shr(128, slice)
                let e := add(ps, l)
                let pd := add(32, $)
            } lt(ps, e) {
                ps := add(32, ps)
                pd := add(32, pd)
            } { mstore(pd, mload(ps)) }
            mstore($, l)
            mstore(0x40, add(add(32, $), l))
        }
    }

    function tokenId(string memory domain) internal pure returns (uint256) {
        return uint256(keccak256(bytes(domain)));
    }

    function tokenId(uint256 slice) internal pure returns (uint256 $) {
        assembly {
            $ := keccak256(shr(128, slice), and(slice, shr(128, not(0))))
        }
    }

    function parent(string memory domain) internal pure returns (uint256) {
        return domain.asSlice().parent();
    }

    function parent(uint256 slice) internal pure returns (uint256 $) {
        (, $,) = slice.cut();
    }

    function cut(string memory domain) internal pure returns (uint256 label, uint256 parent_, bool hasParent) {
        return domain.asSlice().cut();
    }

    function cut(uint256 slice) internal pure returns (uint256 label, uint256 parent_, bool hasParent) {
        assembly {
            label := slice
            let p := shr(128, slice)
            let e := add(p, and(slice, shr(128, not(0))))
            for {} lt(p, e) { p := add(1, p) } {
                if eq(shr(248, mload(p)), 0x2e) {
                    hasParent := true
                    let b := shr(128, slice)
                    label := or(sub(p, b), shl(128, b))
                    p := add(1, p)
                    parent_ := or(sub(e, p), shl(128, p))
                    break
                }
            }
            if eq(p, e) { parent_ := shl(128, p) }
        }
    }

    function allLevels(string memory domain) internal pure returns (uint256[] memory) {
        return domain.asSlice().allLevels();
    }

    function allLevels(uint256 slice) internal pure returns (uint256[] memory $) {
        assembly ("memory-safe") {
            $ := mload(0x40)
            mstore(add(32, $), slice)
            let m := add(64, $)
            for {
                let p := shr(128, slice)
                let e := sub(add(p, and(slice, shr(128, not(0)))), 1)
            } lt(p, e) { p := add(1, p) } {
                if eq(shr(248, mload(p)), 0x2e) {
                    mstore(m, or(sub(e, p), shl(128, add(1, p))))
                    m := add(32, m)
                }
            }
            mstore($, shr(5, sub(m, add(32, $))))
            mstore(0x40, m)
        }
    }

    /**
     * @notice Checks whether `label` is a valid domain label.
     *
     *         A label is considered valid if and only if it:
     *         - is a well-formed non-empty UTF-8 sequence; and
     *         - contains only Unicode code points in category L, M, N, P, S; and
     *         - does not contain Unicode code points in the following ranges:
     *           - Full Stop (U+002E)
     *           - Mongolian Free Variation Selectors (U+180B..U+180D)
     *           - Variation Selectors (U+FE00..U+FE0F)
     *           - Replacement Characters (U+FFFC..U+FFFD)
     *           - Variation Selectors Supplement (U+E0100..U+E01EF).
     *
     *         (based on Unicode 15.0.0)
     */
    function isValidLabel(string memory label) internal pure returns (bool) {
        uint256 validLength = validateLabel(label.asSlice());
        return bytes(label).length == validLength && validLength > 0;
    }

    function isValidLabel(uint256 label) internal pure returns (bool) {
        uint256 length;
        assembly {
            length := and(label, shr(128, not(0)))
        }
        return length == validateLabel(label) && length > 0;
    }

    function validateLabel(uint256 slice) private pure returns (uint256 validLength) {
        uint256 latinTable = 0x000000000000000000002001ffffffff800000000000000000004001ffffffff;
        uint256[89] memory table = [
            0x00de0002_00e00004_00e2c001_00e34001_00e88001_014c0001_0155c002_0162c002,
            0x01640001_01720008_017ac004_017d4011_01870001_01b74001_01c38002_01d2c002,
            0x01ec800e_01fec002_020b8002_020fc001_02170002_0217c001_021ac005_0223c009,
            0x02388001_02610001_02634002_02644002_026a4001_026c4001_026cc003_026e8002,
            0x02714002_02724002_0273c008_02760004_02778001_02790002_027fc002_02810001,
            0x0282c004_02844002_028a4001_028c4001_028d0001_028dc001_028e8002_028f4001,
            0x0290c004_02924002_02938003_02948007_02974001_0297c007_029dc00a_02a10001,
            0x02a38001_02a48001_02aa4001_02ac4001_02ad0001_02ae8002_02b18001_02b28001,
            0x02b38002_02b4400f_02b90002_02bc8007_02c00001_02c10001_02c34002_02c44002,
            0x02ca4001_02cc4001_02cd0001_02ce8002_02d14002_02d24002_02d38007_02d60004,
            0x02d78001_02d90002_02de000a_02e10001_02e2c003_02e44001_02e58003_02e6c001,
            0x02e74001_02e80003_02e94003_02eac003_02ee8004_02f0c003_02f24001_02f38002,
            0x02f44006_02f6000e_02fec005_03034001_03044001_030a4001_030e8002_03114001,
            0x03124001_03138007_0315c001_0316c002_03178002_03190002_031c0007_03234001,
            0x03244001_032a4001_032d0001_032e8002_03314001_03324001_03338007_0335c006,
            0x0337c001_03390002_033c0001_033d000c_03434001_03444001_03514001_03524001,
            0x03540004_03590002_03600001_03610001_0365c003_036c8001_036f0001_036f8002,
            0x0371c003_0372c004_03754001_0375c001_03780006_037c0002_037d400c_038ec004,
            0x03970025_03a0c001_03a14001_03a2c001_03a90001_03a98001_03af8002_03b14001,
            0x03b1c001_03b3c001_03b68002_03b80020_03d20001_03db4004_03e60001_03ef4001,
            0x03f34001_03f6c025_04318001_04320005_04338002_04924001_04938002_0495c001,
            0x04964001_04978002_04a24001_04a38002_04ac4001_04ad8002_04afc001_04b04001,
            0x04b18002_04b5c001_04c44001_04c58002_04d6c002_04df4003_04e68006_04fd8002,
            0x04ff8002_05a00001_05a74003_05be4007_05c58009_05cdc009_05d5000c_05db4001,
            0x05dc4001_05dd000c_05f78002_05fa8006_05fe8006_0602c004_06068006_061e4007,
            0x062ac005_063d800a_0647c001_064b0004_064f0004_06504003_065b8002_065d400b,
            0x066b0004_06728006_0676c003_06870002_0697c001_069f4002_06a28006_06a68006,
            0x06ab8002_06b3c031_06d34003_06dfc001_06fd0008_070e0003_07128003_07224007,
            0x072ec002_07320008_073ec005_07c58002_07c78002_07d18002_07d38002_07d60001,
            0x07d68001_07d70001_07d78001_07df8002_07ed4001_07f14001_07f50002_07f70001,
            0x07fc0002_07fd4001_07ffc011_080a0008_0817c011_081c8002_0823c001_08274003,
            0x0830400f_083c400f_08630004_0909c019_0912c015_0add0002_0ae58001_0b3d0005,
            0x0b498001_0b4a0005_0b4b8002_0b5a0007_0b5c400e_0b65c009_0b69c001_0b6bc001,
            0x0b6dc001_0b6fc001_0b71c001_0b73c001_0b75c001_0b77c001_0b978022_0ba68001,
            0x0bbd000c_0bf5801a_0bff0005_0c100001_0c25c002_0c400005_0c4c0001_0c63c001,
            0x0c79000c_0c87c001_29234003_2931c009_298b0014_29be0008_29f2c005_29f48001,
            0x29f50001_29f68018_2a0b4003_2a0e8006_2a1e0008_2a318008_2a368006_2a55000b,
            0x2a5f4003_2a738001_2a768004_2a7fc001_2a8dc009_2a938002_2a968002_2ab0c018,
            0x2abdc00a_2ac1c002_2ac3c002_2ac5c009_2ac9c001_2acbc001_2adb0004_2afb8002,
            0x2afe8006_35e9000c_35f1c004_35ff2104_3e9b8002_3eb68026_3ec1c00c_3ec60005,
            0x3ecdc001_3ecf4001_3ecfc001_3ed08001_3ed14001_3ef0c010_3f640002_3f720007,
            0x3f740020_3f800010_3f868006_3f94c001_3f99c001_3f9b0004_3f9d4001_3fbf4004,
            0x3fefc003_3ff20002_3ff40002_3ff60002_3ff74003_3ff9c001_3ffbc011_40030001,
            0x4009c001_400ec001_400f8001_40138002_40178022_403ec005_4040c004_404d0003,
            0x4063c001_40674003_4068402f_407f8082_40a74003_40b4400f_40bf0004_40c90009,
            0x40d2c005_40dec005_40e78001_40f10004_40f5802a_41278002_412a8006_41350004,
            0x413f0004_414a0008_4159000b_415ec001_4162c001_4164c001_41658001_41688001,
            0x416c8001_416e8001_416f4043_41cdc009_41d5800a_41da0018_41e18001_41ec4001,
            0x41eec045_42018002_42024001_420d8001_420e4003_420f4002_42158001_4227c008,
            0x422c0030_423cc001_423d8005_42470003_424e8005_42500040_426e0004_42740002,
            0x42810001_4281c005_42850001_42860001_428d8002_428ec004_42924007_42964007,
            0x42a80020_42b9c004_42bdc009_42cd8003_42d58002_42dcc005_42e48007_42e7400c,
            0x42ec0050_43124037_432cc00d_433cc007_434a0008_434e8126_439fc001_43aa8001,
            0x43ab8002_43ac804b_43ca0008_43d68016_43e28026_43f30014_43fdc009_44138004,
            0x441d8009_442f4001_4430c00d_443a4007_443e8006_444d4001_44520008_445dc009,
            0x44780001_447d400b_44848001_4490803e_44a1c001_44a24001_44a38001_44a78001,
            0x44aa8006_44bac005_44be8006_44c10001_44c34002_44c44002_44ca4001_44cc4001,
            0x44cd0001_44ce8001_44d14002_44d24002_44d38002_44d44006_44d60005_44d90002,
            0x44db4003_44dd408b_45170001_4518801e_45320008_453680a6_456d8002_45778022,
            0x4591400b_45968006_459b4013_45ae8006_45b28036_45c6c002_45cb0004_45d1c0b9,
            0x460f0064_463cc00c_4641c002_46428002_46450001_4645c001_464d8001_464e4002,
            0x4651c009_46568046_466a0002_46760002_4679401b_46920008_46a8c00d_46be4007,
            0x46c280f6_47024001_470dc001_4711800a_471b4003_47240002_472a0001_472dc049,
            0x4741c001_47428001_474dc003_474ec001_474f8001_47520008_47568006_47598001,
            0x475a4001_4763c001_47648001_47664007_476a8136_47be4007_47c44001_47cec003,
            0x47d68056_47ec400f_47fc800d_48e68066_491bc001_491d400b_49510a4c_4bfcc00d,
            0x4d0c0010_4d158faa_5191e1b9_5a8e4007_5a97c001_5a9a8004_5aafc001_5ab28006,
            0x5abb8002_5abd800a_5ad1800a_5ad68001_5ad88001_5ade0005_5ae402b0_5ba6c065,
            0x5bd2c004_5be20007_5be80040_5bf9400b_5bfc800e_61fe0008_6335802a_634262e7,
            0x6bfd0001_6bff0001_6bffc001_6c48c00f_6c4cc01d_6c54c002_6c55800e_6c5a0008,
            0x6cbf0904_6f1ac005_6f1f4003_6f224007_6f268002_6f281260_73cb8002_73d1c009,
            0x73f1003c_743d800a_7449c002_745cc008_747ac015_7491807a_74b5000c_74bd000c,
            0x74d5c009_74de4087_75154001_75274001_75280002_7528c002_7529c002_752b4001,
            0x752e8001_752f0001_75310001_75418001_7542c002_75454001_75474001_754e8001,
            0x754fc001_75514001_7551c003_75544001_75a98002_75f30002_76a3000f_76a80001,
            0x76ac0450_77c7c006_77cac0d5_7801c001_78064002_78088001_78094001_780ac005,
            0x781b8021_78240070_784b4003_784f8002_78528004_78540140_78abc011_78be8005,
            0x78c001d0_793e82e6_79f9c001_79fb0001_79fbc001_79ffc001_7a314002_7a35c029,
            0x7a530004_7a568004_7a580311_7b2d404c_7b4f80c2_7b810001_7b880001_7b88c001,
            0x7b894002_7b8a0001_7b8cc001_7b8e0001_7b8e8001_7b8f0006_7b90c004_7b920001,
            0x7b928001_7b930001_7b940001_7b94c001_7b954002_7b960001_7b968001_7b970001,
            0x7b978001_7b980001_7b98c001_7b994002_7b9ac001_7b9cc001_7b9e0001_7b9f4001,
            0x7b9fc001_7ba28001_7ba70005_7ba90001_7baa8001_7baf0034_7bbc810e_7c0b0004,
            0x7c25000c_7c2bc002_7c300001_7c340001_7c3d800a_7c6b8038_7c80c00d_7c8f0004,
            0x7c924007_7c94800e_7c99809a_7db60004_7dbb4003_7dbf4003_7dddc004_7df68006,
            0x7dfb0004_7dfc400f_7e030004_7e120008_7e168006_7e220008_7e2b8002_7e2c804e,
            0x7e95000c_7e9b8002_7e9f4003_7ea24007_7eaf8001_7eb18008_7eb70004_7eba4007,
            0x7ebe4007_7ee4c001_7ef2c025_7efe8406_a9b80020_adce8006_ae078002_b3a8800e,
            0xbaf84c1f_be8785e2_c4d2c005_00000000_00000000_00000000_00000000_00000000
        ];

        assembly {
            function toCodePoint(s) -> cp, l {
                let c := shr(224, s)
                if lt(c, 0x80000000) {
                    cp := shr(24, c)
                    l := 1
                    leave
                }
                if eq(0xc0800000, and(0xe0c00000, c)) {
                    let t := or(and(0x7c0, shr(18, c)), and(0x3f, shr(16, c)))
                    if gt(t, 0x7f) {
                        cp := t
                        l := 2
                    }
                    leave
                }
                if eq(0xe0808000, and(0xf0c0c000, c)) {
                    let t := or(and(0xf000, shr(12, c)), or(and(0xfc0, shr(10, c)), and(0x3f, shr(8, c))))
                    if gt(t, 0x7ff) {
                        if eq(0xd800, and(0xf800, c)) { leave }
                        cp := t
                        l := 3
                    }
                    leave
                }
                if eq(0xf0808080, and(0xf8c0c0c0, c)) {
                    let t :=
                        or(and(0x1c0000, shr(6, c)), or(and(0x3f000, shr(4, c)), or(and(0xfc0, shr(2, c)), and(0x3f, c))))
                    if gt(t, 0xffff) {
                        cp := t
                        l := 4
                    }
                    leave
                }
            }

            let p := shr(128, slice)
            let l := and(slice, shr(128, not(0)))
            let cl
            for { let e := add(p, l) } lt(p, e) { p := add(cl, p) } {
                let cp
                cp, cl := toCodePoint(mload(p))
                if iszero(cl) { break }
                if lt(cp, 0x100) {
                    if and(1, shr(cp, latinTable)) { break }
                    continue
                }
                if gt(cp, 0x323af) { break }
                let b
                for {
                    let il := 0
                    let ir := 707
                } true {} {
                    let im := shr(1, add(il, ir))
                    let u := shr(224, mload(add(table, shl(2, im))))
                    let v := shr(14, u)
                    switch gt(v, cp)
                    case 0 {
                        if eq(il, im) {
                            b := lt(cp, add(v, and(0x3fff, u)))
                            break
                        }
                        il := im
                    }
                    default {
                        if eq(il, im) { break }
                        ir := im
                    }
                }
                if b { break }
            }
            let vl := sub(p, shr(128, slice))
            if gt(vl, l) { vl := sub(vl, cl) }

            validLength := vl
        }
    }
}
