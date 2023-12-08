// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {TerminusDID} from "../src/core/TerminusDID.sol";
import {RootResolver} from "../src/resolvers/RootResolver.sol";
// import {Registrar} from "../src/core/Registrar.sol";
// import {Metadata} from "../src/core/MetadataRegistryUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    // function run() external {
    //     uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    //     address deployer = vm.addr(deployerPrivateKey);
    //     address bot = vm.envAddress("BOT");
    //     string memory _name = vm.envString("TERMINUSDID_NAME");
    //     string memory _symbol = vm.envString("TERMINUSDID_SYMBOL");

    //     vm.startBroadcast(deployerPrivateKey);

    //     Registrar registrar = new Registrar(address(0), address(0), deployer);

    //     TerminusDID registry = new TerminusDID();
    //     bytes memory initData = abi.encodeWithSelector(TerminusDID.initialize.selector, _name, _symbol);
    //     ERC1967Proxy proxy = new ERC1967Proxy(address(registry), initData);
    //     TerminusDID registryProxy = TerminusDID(address(proxy));
    //     registryProxy.setRegistrar(address(registrar));

    //     RootResolver rootResolver = new RootResolver(address(registrar), address(registryProxy), bot);

    //     registrar.setRegistry(address(registryProxy));
    //     registrar.setRootResolver(address(rootResolver));

    //     registrar.register(bot, Metadata("com", "did", "", true));
    //     registrar.register(bot, Metadata("snowinning.com", "did", "", true));
    //     registrar.setOperator(bot);

    //     vm.stopBroadcast();
    // }
}
