// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IResolver} from "../IResolver.sol";
import {ITerminusDID, IRegistrar} from "../../utils/Interfaces.sol";
import {DomainUtils} from "../../utils/DomainUtils.sol";

contract CustomResolver is IResolver, Context {
    using DomainUtils for string;

    uint256 private constant _STAFF_ID = 0xffff01;

    IRegistrar private _registrar;
    ITerminusDID private _registry;

    error Unauthorized();

    error InvalidId();

    constructor(address registrar_, address registry_) {
        _registrar = IRegistrar(registrar_);
        _registry = ITerminusDID(registry_);
    }

    function supportsTag(uint256 key) public pure returns (bool) {
        return key == _STAFF_ID;
    }

    function getRegistrar() external view returns (address) {
        return address(_registrar);
    }

    function getRegistry() external view returns (address) {
        return address(_registry);
    }

    function setStaffId(string calldata domain, uint32 id) external {
        if (id == 0) {
            revert InvalidId();
        }

        address caller = _msgSender();
        (, uint256 ownedLevel,) = _registrar.traceOwner(domain, caller);
        if (ownedLevel == 0) {
            revert Unauthorized();
        }

        _registrar.setTag(domain, _STAFF_ID, bytes.concat(bytes4(id)));
    }

    function getStaffId(string calldata domain) external view returns (uint32 id) {
        (bool exists, bytes memory value) = _registry.getTagValue(domain.tokenId(), _STAFF_ID);
        if (exists) {
            id = uint32(bytes4(value));
        } else {
            id = 0;
        }
        
    }
}
