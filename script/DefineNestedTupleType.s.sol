// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {TerminusDID} from "../src/core/TerminusDID.sol";
import {ABI} from "../src/utils/ABI.sol";

contract DefineNestedTupleType is Script {
    struct Student {
        People info;
        Class class;
    }

    struct Class {
        uint8 grade;
        uint8 classNum;
        Teacher[] teachers;
    }

    struct People {
        string name;
        uint8 age;
        string gender;
    }

    struct Teacher {
        People info;
        string subject;
    }

    function run() external {
        uint256 botPrivateKey = vm.envUint("PRIVATE_KEY");
        address bot = vm.addr(botPrivateKey);
        address terminusDIDProxyAddr = vm.envAddress("TERMINUSDIDPROXY_ADDR");

        vm.startBroadcast(botPrivateKey);

        // terminusDIDProxy
        TerminusDID terminusDIDProxy = TerminusDID(terminusDIDProxyAddr);

        string memory rootDomain = "";
        string memory targetDomain = "song.net";

        // define tag type
        string memory tagName = "studentFile";

        bytes memory peopleType = ABI.tupleT(bytes.concat(ABI.stringT(), ABI.uintT(8), ABI.stringT()));
        bytes memory teachersType = ABI.arrayT(ABI.tupleT(bytes.concat(peopleType, ABI.stringT())));
        bytes memory classType = ABI.tupleT(bytes.concat(ABI.uintT(8), ABI.uintT(8), teachersType));
        bytes memory studentType = ABI.tupleT(bytes.concat(peopleType, classType));

        string[][] memory fieldNames = new string[][](5);
        fieldNames[0] = new string[](2);
        fieldNames[0][0] = "info";
        fieldNames[0][1] = "class";

        fieldNames[1] = new string[](3);
        fieldNames[1][0] = "name";
        fieldNames[1][1] = "age";
        fieldNames[1][2] = "gender";

        fieldNames[2] = new string[](3);
        fieldNames[2][0] = "grade";
        fieldNames[2][1] = "classNum";
        fieldNames[2][2] = "teachers";

        fieldNames[3] = new string[](2);
        fieldNames[3][0] = "info";
        fieldNames[3][1] = "subject";

        fieldNames[4] = new string[](3);
        fieldNames[4][0] = "name";
        fieldNames[4][1] = "age";
        fieldNames[4][2] = "gender";
        terminusDIDProxy.defineTag(rootDomain, tagName, studentType, fieldNames);

        People memory mrwang = People({
            name: "Mr.Wang",
            age: 40,
            gender: "M"
        });
        People memory msliu = People({
            name: "Ms.Liu",
            age: 36,
            gender: "F"
        });
        People memory xiaoming = People({
            name: "Xiao Ming",
            age: 10,
            gender: "M"
        });

        Teacher memory t1 = Teacher({
            info: mrwang,
            subject: "Math"
        });

        Teacher memory t2 = Teacher({
            info: msliu,
            subject: "Chinese"
        });
        Teacher[] memory ts = new Teacher[](2);
        ts[0] = t1;
        ts[1] = t2;
        Class memory c = Class({
            grade: 4,
            classNum: 2,
            teachers: ts
        });
        Student memory s = Student({
            info: xiaoming,
            class: c
        });

        // setTagger
        terminusDIDProxy.setTagger(rootDomain, tagName, bot);

        // set tag
        terminusDIDProxy.addTag(rootDomain, targetDomain, tagName, abi.encode(s));

        vm.stopBroadcast();
    }
}
