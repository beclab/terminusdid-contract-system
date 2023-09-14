// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Oracle} from "../Oracle.sol";

abstract contract BaseResolver {
    Oracle public oracle;

    constructor(address _oracle) {
        oracle = Oracle(_oracle);
    }
}
