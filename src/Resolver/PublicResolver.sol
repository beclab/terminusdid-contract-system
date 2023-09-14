// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseResolver} from "./BaseResolver.sol";
import {MetaResolver} from "./MetaResolver.sol";
import {TextResolver} from "./TextResolver.sol";
import {RsaResolver} from "./RsaResolver.sol";

contract PublicResolver is BaseResolver, MetaResolver, TextResolver, RsaResolver {
    constructor(address _oracle) BaseResolver(_oracle) {}
}
