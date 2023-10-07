// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {TerminusDID} from "../src/TerminusDID.sol";
import {PublicResolver} from "../src/resolvers/PublicResolver.sol";
import {Registrar} from "../src/Registrar.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address domainOwner = vm.envAddress("SNOWINNING_COM_OWNER");
        string memory _name = vm.envString("TERMINUSDID_NAME");
        string memory _symbol = vm.envString("TERMINUSDID_SYMBOL");

        vm.startBroadcast(deployerPrivateKey);

        PublicResolver resolver = new PublicResolver();
        Registrar registrar = new Registrar(address(0), address(resolver));

        TerminusDID registry = new TerminusDID(_name, _symbol, address(registrar));
        registrar.setRegistry(address(registry));

        registrar.registerTLD("com", "did", domainOwner);
        registrar.register("snowinning", "com", "did", domainOwner, TerminusDID.Kind.Organization);

        vm.stopBroadcast();
    }
}
