// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {TerminusDID} from "../src/core/TerminusDID.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address terminusDIDProxyAddr = vm.envAddress("TERMINUSDIDPROXY_ADDR");

        vm.startBroadcast(deployerPrivateKey);

        // get current terminusDIDProxy
        TerminusDID terminusDIDProxy = TerminusDID(terminusDIDProxyAddr);
        
        // deploy new verison terminusDID
        TerminusDID newTerminusDID = new TerminusDID();

        // upgrade to new version
        terminusDIDProxy.upgradeToAndCall(address(newTerminusDID), "");

        vm.stopBroadcast();
    }
}
