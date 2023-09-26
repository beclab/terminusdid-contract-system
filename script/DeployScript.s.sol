// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {TerminusDID} from "../src/TerminusDID.sol";
import {PublicResolver} from "../src/resolvers/PublicResolver.sol";
import {Registrar} from "../src/Registrar.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PublicResolver resolver = new PublicResolver();
        Registrar registrar = new Registrar(address(0), address(resolver));

        string memory _name = "TestTerminusDID";
        string memory _symbol = "TTDID";
        TerminusDID registry = new TerminusDID(_name, _symbol, address(registrar));
        registrar.setRegistry(address(registry));

        vm.stopBroadcast();
    }
}
