// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IResolver} from "./IResolver.sol";
import {ITerminusDID, IRegistrar} from "../utils/Interfaces.sol";
import {Asn1Decode} from "../utils/Asn1Decode.sol";
import {DomainUtils} from "../utils/DomainUtils.sol";

contract PublicResolver is IResolver, Context {
    using Asn1Decode for bytes;
    using DomainUtils for string;

    uint256 private constant _PUBLIC_KEY_LIMIT = 0xffff;
    uint256 private constant _RSA_PUBKEY_RESOLVER = 0x12;
    uint256 private constant _DNS_A_RECORD_RESOLVER = 0x13;

    IRegistrar private _registrar;
    ITerminusDID private _registry;

    error NoPublicReservedTag(uint256 key);

    error UnsupportedTag(uint256 key);

    error Unauthorized();

    error Asn1DecodeError(Asn1Decode.ErrorCode errorCode);

    error InvalidIpV4Length();

    constructor(address registrar_, address registry_) {
        _registrar = IRegistrar(registrar_);
        _registry = ITerminusDID(registry_);
    }

    function supportsTag(uint256 key) external pure returns (bool) {
        return key == _RSA_PUBKEY_RESOLVER || key == _DNS_A_RECORD_RESOLVER;
    }

    function getRegistrar() external view returns (address) {
        return address(_registrar);
    }

    function getRegistry() external view returns (address) {
        return address(_registry);
    }

    function setPublicTag(string calldata domain, uint256 key, bytes calldata value) external {
        if (key > _PUBLIC_KEY_LIMIT) {
            revert NoPublicReservedKey(key);
        }

        address caller = _msgSender();
        (, uint256 ownedLevel,) = _registrar.traceOwner(domain, caller);
        if (ownedLevel == 0) {
            revert Unauthorized();
        }

        if (key == _RSA_PUBKEY_RESOLVER) {
            _setRsaPubKey(domain, value);
        } else if (key == _DNS_A_RECORD_RESOLVER) {
            _setDnsARecord(domain, value);
        } else {
            revert UnsupportedTag(key);
        }
    }

    function getPublicTag(string calldata domain, uint256 key) external returns (bytes memory) {
        if (key > _PUBLIC_KEY_LIMIT) {
            revert NoPublicReservedKey(key);
        }

        if (key == _RSA_PUBKEY_RESOLVER) {
            return _getRsaPubKey(domain);
        } else if (key == _DNS_A_RECORD_RESOLVER) {
            return _getDnsARecord(domain);
        } else {
            revert UnsupportedTag(key);
        }
    }

    /*
    support RSA Pkcs1 ASN.1 format.
    RSAPublicKey ::= SEQUENCE {
        modulus           INTEGER,  -- n
        publicExponent    INTEGER   -- e
    }
    refs to: https://www.rfc-editor.org/rfc/rfc3447#appendix-A.1
            http://luca.ntop.org/Teaching/Appunti/asn1.html
    */
    function _setRsaPubKey(string calldata domain, bytes calldata value) internal {
        Asn1Decode.ErrorCode errorCode;
        uint256 sequenceRange;
        (errorCode, sequenceRange) = value.rootOfSequenceStringAt(0);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            revert Asn1DecodeError(errorCode);
        }
        bytes memory sequence = value.bytesAt(sequenceRange);

        uint256 modulusRange;
        (errorCode, modulusRange) = sequence.root();
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            revert Asn1DecodeError(errorCode);
        }

        (errorCode,) = sequence.uintBytesAt(modulusRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            revert Asn1DecodeError(errorCode);
        }

        uint256 publicExponentRange;
        (errorCode, publicExponentRange) = sequence.nextSiblingOf(modulusRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            revert Asn1DecodeError(errorCode);
        }

        (errorCode,) = sequence.uintAt(publicExponentRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            revert Asn1DecodeError(errorCode);
        }

        _registrar.setTag(domain, _RSA_PUBKEY_RESOLVER, value);
    }

    function _getRsaPubKey(string calldata domain) internal returns (bytes memory value) {
        bool exists;
        (exists, value) = _registry.getTagValue(domain.tokenId(), _RSA_PUBKEY_RESOLVER);
        if (exists) {
            return value;
        }
    }

    /*
    DNS A record can be represent by 4 bytes, in which each byte represents a number range from 0 to 255.
    The raw bytes data length must be 4.
    */
    function _setDnsARecord(string memory domain, bytes calldata value) internal {
        if (value.length != 4) {
            revert InvalidIpV4Length();
        }

        _registrar.setTag(domain, _DNS_A_RECORD_RESOLVER, value);
    }

    function _getDnsARecord(string calldata domain) internal returns (bytes memory value) {
        bool exists;
        (exists, value) = _registry.getTagValue(domain.tokenId(), _DNS_A_RECORD_RESOLVER);
        if (exists) {
            return value;
        }
    }
}
