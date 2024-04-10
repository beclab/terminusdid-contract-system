// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TerminusDID} from "../src/core/TerminusDID.sol";
import {RootTagger} from "../src/taggers/RootTagger.sol";
import {ABI} from "../src/utils/ABI.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address bot = vm.envAddress("BOT");
        string memory _name = vm.envString("TERMINUSDID_NAME");
        string memory _symbol = vm.envString("TERMINUSDID_SYMBOL");

        vm.startBroadcast(deployerPrivateKey);

        // deploy terminusDID
        TerminusDID terminusDID = new TerminusDID();
        bytes memory initData = abi.encodeWithSelector(TerminusDID.initialize.selector, _name, _symbol);
        ERC1967Proxy proxy = new ERC1967Proxy(address(terminusDID), initData);
        TerminusDID terminusDIDProxy = TerminusDID(address(proxy));

        // set operator as deployer as need to define root types and set taggers, will set operator to bot at last
        terminusDIDProxy.setOperator(deployer);

        // deploy root tagger
        RootTagger rootTagger = new RootTagger(address(terminusDIDProxy), bot);

        // difine root tag types
        string memory rootDomain = "";
        string[][] memory fieldNames;

        // define bytes tag type
        string memory rsaPubKeyTagName = "rsaPubKey";
        {
            bytes memory rsaPubKeyType = bytes.concat(ABI.bytesT());
            terminusDIDProxy.defineTag(rootDomain, rsaPubKeyTagName, rsaPubKeyType, fieldNames);
        }

        // define bytes4 tag type
        string memory dnsARecordTagName = "dnsARecord";
        {
            bytes memory dnsARecordType = bytes.concat(ABI.bytesT(4));
            terminusDIDProxy.defineTag(rootDomain, dnsARecordTagName, dnsARecordType, fieldNames);
        }

        // define AuthAddress[] tag type
        string memory authAddressesTagName = "authAddresses";
        {
            string[][] memory authAddressesTypefieldNames = new string[][](1);
            authAddressesTypefieldNames[0] = new string[](2);
            authAddressesTypefieldNames[0][0] = "algorithm";
            authAddressesTypefieldNames[0][1] = "addr";
            bytes memory authAddressesType = ABI.arrayT(ABI.tupleT(bytes.concat(ABI.uintT(8), ABI.addressT())));
            terminusDIDProxy.defineTag(rootDomain, authAddressesTagName, authAddressesType, authAddressesTypefieldNames);
        }

        // define string tag type
        string memory latestDIDTagName = "latestDID";
        {
            bytes memory latestDIDType = bytes.concat(ABI.stringT());
            terminusDIDProxy.defineTag(rootDomain, latestDIDTagName, latestDIDType, fieldNames);
        }

        // define rootTagger for rootDomain and the above 4 tags
        terminusDIDProxy.setTagger(rootDomain, rsaPubKeyTagName, address(rootTagger));
        terminusDIDProxy.setTagger(rootDomain, dnsARecordTagName, address(rootTagger));
        terminusDIDProxy.setTagger(rootDomain, authAddressesTagName, address(rootTagger));
        terminusDIDProxy.setTagger(rootDomain, latestDIDTagName, address(rootTagger));

        // register domain
        terminusDIDProxy.register(bot, TerminusDID.Metadata("com", "did", "", true));
        terminusDIDProxy.register(bot, TerminusDID.Metadata("myterminus.com", "did", "", true));

        // transfer operator to bot
        terminusDIDProxy.setOperator(bot);

        vm.stopBroadcast();
    }
}
