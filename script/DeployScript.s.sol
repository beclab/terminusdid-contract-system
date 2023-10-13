// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {TerminusDID} from "../src/core/TerminusDID.sol";
import {PublicResolver} from "../src/resolvers/PublicResolver.sol";
import {Registrar} from "../src/core/Registrar.sol";
import {Metadata} from "../src/core/MetadataRegistryUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address operator = vm.envAddress("OPERATOR");
        address domainOwner = vm.envAddress("SNOWINNING_COM_OWNER");
        string memory _name = vm.envString("TERMINUSDID_NAME");
        string memory _symbol = vm.envString("TERMINUSDID_SYMBOL");

        vm.startBroadcast(deployerPrivateKey);

        TerminusDID registry = new TerminusDID();
        bytes memory initData = abi.encodeWithSelector(TerminusDID.initialize.selector, _name, _symbol);
        ERC1967Proxy proxy = new ERC1967Proxy(address(registry), initData);
        TerminusDID registryProxy = TerminusDID(address(proxy));

        PublicResolver resolver = new PublicResolver();
        Registrar registrar = new Registrar(address(registryProxy), address(resolver), operator);

        registryProxy.setRegistrar(address(registrar));

        registrar.register(domainOwner, Metadata("com", "did", "", true));
        registrar.register(domainOwner, Metadata("snowinning.com", "did", "", true));
        vm.stopBroadcast();
    }
}
