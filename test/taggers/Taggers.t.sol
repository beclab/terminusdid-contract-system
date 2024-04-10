// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TerminusDID} from "../../src/core/TerminusDID.sol";
import {RootTagger} from "../../src/taggers/RootTagger.sol";
import {CustomTagger} from "../../src/taggers/examples/CustomTagger.sol";
import {ABI} from "../../src/utils/ABI.sol";

contract TaggersTest is Test {
    TerminusDID public terminusDID;
    TerminusDID public terminusDIDProxy;
    RootTagger public rootTagger;
    string _name = "TestTerminusDID";
    string _symbol = "TDID";
    address _deployer = address(this);
    address _operator = address(0xabcd);
    address _bot = address(0x1234);

    function setUp() public {
        // deploy TerminusDID
        terminusDID = new TerminusDID();
        bytes memory initData = abi.encodeWithSelector(TerminusDID.initialize.selector, _name, _symbol);
        ERC1967Proxy proxy = new ERC1967Proxy(address(terminusDID), initData);
        terminusDIDProxy = TerminusDID(address(proxy));

        // set TerminusDID operator
        terminusDIDProxy.setOperator(_operator);

        // deploy RootTagger
        rootTagger = new RootTagger(address(terminusDIDProxy), _bot);

        // difine root tag types
        string memory rootDomain = "";
        string[][] memory fieldNames;

        // define bytes tag type
        string memory rsaPubKeyTagName = "rsaPubKey";
        {
            bytes memory rsaPubKeyType = bytes.concat(ABI.bytesT());
            vm.prank(_operator);
            terminusDIDProxy.defineTag(rootDomain, rsaPubKeyTagName, rsaPubKeyType, fieldNames);
        }

        // define bytes4 tag type
        string memory dnsARecordTagName = "dnsARecord";
        {
            bytes memory dnsARecordType = bytes.concat(ABI.bytesT(4));
            vm.prank(_operator);
            terminusDIDProxy.defineTag(rootDomain, dnsARecordTagName, dnsARecordType, fieldNames);
        }

        // define string tag type
        string memory latestDIDTagName = "latestDID";
        {
            bytes memory latestDIDType = bytes.concat(ABI.stringT());
            vm.prank(_operator);
            terminusDIDProxy.defineTag(rootDomain, latestDIDTagName, latestDIDType, fieldNames);
        }

        // define rootTagger for rootDomain and the above 3 tags
        vm.prank(_operator);
        terminusDIDProxy.setTagger(rootDomain, rsaPubKeyTagName, address(rootTagger));
        vm.prank(_operator);
        terminusDIDProxy.setTagger(rootDomain, dnsARecordTagName, address(rootTagger));
        vm.prank(_operator);
        terminusDIDProxy.setTagger(rootDomain, latestDIDTagName, address(rootTagger));
    }

    function testBasis() public {
        assertEq(rootTagger.terminusDID(), address(terminusDIDProxy));
        assertEq(rootTagger.operator(), _bot);
    }

    function testAddUpdateRemoveRsaPubKey() public {
        bytes memory value =
            hex"30819f300d06092a864886f70d010101050003818d0030818902818100ab42da3ee0bf48a1ddbf532f00878edec1407108f5ccea34cd90786729fff2df7122839b9c02ee1dcbbd580521a394b87c789e56a80785ab3aca088df45981bc7036f602f74d790df3c902f1ee97b8cd66cd69f2dd881048b8589703309ac679d1c6f2a17d00f2b9d4a27c5d2d5407a0e11829e0623d2a2deb03e2874d8286af0203010001";

        string memory domain = "a";
        address aOwner = address(100);
        vm.prank(_operator);
        terminusDIDProxy.register(aOwner, TerminusDID.Metadata(domain, "did", "", true));

        // add rsaPubKey
        vm.prank(_bot);
        rootTagger.setRsaPubKey(domain, value);
        bytes memory valueRet;
        valueRet = rootTagger.getRsaPubKey(domain);
        assertEq(value, valueRet);

        // update rsaPubKey
        bytes memory newValue =
            hex"30819f300d06092a864886f70d010101050003818d00308189028181008b78c3c4ed464ea747354398dd81007e06d6395b2182c5845ec7759ef6d8fb62eda681a75d4a37b6df6d705df9f3d375081fe76fc94eb41691a466a40863cc357fa8790c8764365ed01e5a07e74eab9dd4342b55786f500d4b7c551c9cd9dfd0276bf57a25b711596f51288402e3513b8f0dbcc8e6ee0043aa6192e5876e766b0203010001";
        vm.prank(_bot);
        rootTagger.setRsaPubKey(domain, newValue);
        valueRet = rootTagger.getRsaPubKey(domain);
        assertEq(newValue, valueRet);

        // remove rsaPubKey
        vm.prank(_bot);
        rootTagger.setRsaPubKey(domain, hex"");
        vm.expectRevert(abi.encodeWithSelector(RootTagger.RootTagNoExists.selector, domain, "rsaPubKey"));
        rootTagger.getRsaPubKey(domain);
    }

    function testSetInvalidRsaPubKey() public {
        bytes memory value =
            hex"3182010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001";

        address aOwner = address(100);
        vm.prank(_operator);
        terminusDIDProxy.register(aOwner, TerminusDID.Metadata("a", "did", "", true));

        vm.prank(_bot);
        vm.expectRevert(bytes("Asn1Decode: not type SEQUENCE STRING"));
        rootTagger.setRsaPubKey("a", value);
    }

    function testAddUpdateRemoveDnsARecord() public {
        bytes4 value;
        value = hex"ffffffff";

        string memory domain = "a";
        address aOwner = address(100);
        vm.prank(_operator);
        terminusDIDProxy.register(aOwner, TerminusDID.Metadata(domain, "did", "", true));

        // add dnsARecord
        vm.prank(_bot);
        rootTagger.setDnsARecord(domain, value);
        bytes4 valueRet = rootTagger.getDnsARecord(domain);
        assertEq(value, valueRet);

        // update dnsARecord
        bytes4 newValue = hex"00ff00ff";
        vm.prank(_bot);
        rootTagger.setDnsARecord(domain, newValue);
        assertEq(rootTagger.getDnsARecord(domain), newValue);

        // remove dnsARecord
        vm.prank(_bot);
        rootTagger.setDnsARecord(domain, bytes4(0));
        vm.expectRevert(abi.encodeWithSelector(RootTagger.RootTagNoExists.selector, domain, "dnsARecord"));
        rootTagger.getDnsARecord(domain);
    }

    function testAddUpdateRemoveLatestDID() public {
        string memory domain = "a";
        address aOwner = address(100);
        vm.prank(_operator);
        terminusDIDProxy.register(aOwner, TerminusDID.Metadata(domain, "did", "", true));

        string memory latestDID = "latestDID";

        // add latestDID
        vm.prank(_bot);
        rootTagger.setLatestDID(domain, latestDID);
        string memory valueRet = rootTagger.getLatestDID(domain);
        assertEq(valueRet, latestDID);

        // update latestDID
        string memory newLatestDID = "newLatestDID";
        vm.prank(_bot);
        rootTagger.setLatestDID(domain, newLatestDID);
        assertEq(rootTagger.getLatestDID(domain), newLatestDID);

        // remove latestDID
        vm.prank(_bot);
        rootTagger.setLatestDID(domain, "");
        vm.expectRevert(abi.encodeWithSelector(RootTagger.RootTagNoExists.selector, domain, "latestDID"));
        rootTagger.getLatestDID(domain);
    }

    function testAuthorizationCheck() public {
        address aOwner = address(100);
        vm.prank(_operator);
        terminusDIDProxy.register(aOwner, TerminusDID.Metadata("a", "did", "", true));

        address bOwner = address(200);
        vm.prank(_operator);
        terminusDIDProxy.register(bOwner, TerminusDID.Metadata("b.a", "did", "", true));

        string memory domain;

        domain = "b.a";
        vm.prank(_bot);
        rootTagger.setDnsARecord(domain, hex"ffffffff");
        assertEq(rootTagger.getDnsARecord(domain), hex"ffffffff");

        vm.prank(aOwner);
        rootTagger.setDnsARecord(domain, hex"ffffffaa");
        assertEq(rootTagger.getDnsARecord(domain), hex"ffffffaa");

        vm.prank(bOwner);
        rootTagger.setDnsARecord(domain, hex"ffffffbb");
        assertEq(rootTagger.getDnsARecord(domain), hex"ffffffbb");

        address notOwner = address(300);
        vm.prank(notOwner);
        vm.expectRevert(RootTagger.Unauthorized.selector);
        rootTagger.setDnsARecord(domain, hex"ffffffcc");
    }

    function testCustomTagger() public {
        string memory domain = "com";

        // define domain that define a tag type
        address comOwner = address(100);
        vm.prank(_operator);
        terminusDIDProxy.register(comOwner, TerminusDID.Metadata(domain, "did", "", true));

        // difine tag types
        string[][] memory fieldNames;
        string memory tagName = "staffID";
        bytes memory tagType = bytes.concat(ABI.uintT(32));
        vm.prank(comOwner);
        terminusDIDProxy.defineTag(domain, tagName, tagType, fieldNames);

        // deploy RootTagger
        CustomTagger tagger = new CustomTagger(address(terminusDIDProxy), domain);

        // define tagger for above domain and tag
        vm.prank(comOwner);
        terminusDIDProxy.setTagger(domain, tagName, address(tagger));

        // set tag for itself
        vm.prank(comOwner);
        tagger.setStaffId(domain, 1);
        assertEq(tagger.getStaffId(domain), 1);

        // update
        vm.prank(comOwner);
        tagger.setStaffId(domain, 2);
        assertEq(tagger.getStaffId(domain), 2);

        // remove
        vm.prank(comOwner);
        tagger.setStaffId(domain, 0);
        vm.expectRevert(abi.encodeWithSelector(CustomTagger.TagNoExists.selector, domain, tagName));
        tagger.getStaffId(domain);

        // define a subdomain
        string memory subdomain = "test.com";
        address subdomainOwner = address(200);
        vm.prank(_operator);
        terminusDIDProxy.register(subdomainOwner, TerminusDID.Metadata(subdomain, "did", "", true));

        // set tag for subdomain
        vm.prank(comOwner);
        tagger.setStaffId(subdomain, 3);
        assertEq(tagger.getStaffId(subdomain), 3);
    }
}
