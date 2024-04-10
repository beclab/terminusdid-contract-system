// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {TerminusDID} from "../../core/TerminusDID.sol";

contract CustomTagger is Context {
    TerminusDID private _terminusDID;
    string private _typeDefineDomain;

    string private _staffIDTagName = "staffID";

    error Unauthorized();
    error TagNoExists(string domain, string tagName);

    constructor(address terminusDID_, string memory domain) {
        _terminusDID = TerminusDID(terminusDID_);
        _typeDefineDomain = domain;
    }

    function terminusDID() external view returns (address) {
        return address(_terminusDID);
    }

    function typeDefineDomain() external view returns (string memory) {
        return _typeDefineDomain;
    }

    function setStaffId(string calldata domain, uint32 id) external {
        address caller = _msgSender();
        (, uint256 ownedLevel,) = _terminusDID.traceOwner(domain, caller);
        if (ownedLevel == 0) {
            revert Unauthorized();
        }

        bool hasTag = _terminusDID.hasTag(_typeDefineDomain, domain, _staffIDTagName);

        // remove tag
        if (id == 0) {
            if (!hasTag) {
                revert TagNoExists(domain, _staffIDTagName);
            }
            return _terminusDID.removeTag(_typeDefineDomain, domain, _staffIDTagName);
        }

        // update
        if (hasTag) {
            uint256[] memory elemPath;
            _terminusDID.updateTagElem(_typeDefineDomain, domain, _staffIDTagName, elemPath, abi.encode(id));
        } else {
            // add rsaPubKey
            _terminusDID.addTag(_typeDefineDomain, domain, _staffIDTagName, abi.encode(id));
        }
    }

    function getStaffId(string calldata domain) external view returns (uint32 id) {
        if (!_terminusDID.hasTag(_typeDefineDomain, domain, _staffIDTagName)) {
            revert TagNoExists(domain, _staffIDTagName);
        }
        uint256[] memory elemPath;
        bytes memory gotData = _terminusDID.getTagElem(_typeDefineDomain, domain, _staffIDTagName, elemPath);
        return abi.decode(gotData, (uint32));
    }
}
