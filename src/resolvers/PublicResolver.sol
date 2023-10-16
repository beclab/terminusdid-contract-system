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

    /*
    support RSA Pkcs1 ASN.1 format.
    RSAPublicKey ::= SEQUENCE {
        modulus           INTEGER,  -- n
        publicExponent    INTEGER   -- e
    }
    refs to: https://www.rfc-editor.org/rfc/rfc3447#appendix-A.1
            http://luca.ntop.org/Teaching/Appunti/asn1.html
    */
    function setRsaPubKey(string calldata domain, bytes calldata pubKey) external {
        address caller = _msgSender();
        (, uint256 ownedLevel,) = _registrar.traceOwner(domain, caller);
        if (ownedLevel == 0) {
            revert Unauthorized();
        }

        Asn1Decode.ErrorCode errorCode;
        uint256 sequenceRange;
        (errorCode, sequenceRange) = pubKey.rootOfSequenceStringAt(0);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            revert Asn1DecodeError(errorCode);
        }
        bytes memory sequence = pubKey.bytesAt(sequenceRange);

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

        _registrar.setTag(domain, _RSA_PUBKEY_RESOLVER, pubKey);
    }

    function rsaPubKey(string calldata domain) external view returns (bytes memory pubKey) {
        bool exists;
        (exists, pubKey) = _registry.getTagValue(domain.tokenId(), _RSA_PUBKEY_RESOLVER);
        if (!exists) {
            pubKey = "";
        }
    }

    /*
    DNS A record can be represent by 4 bytes, in which each byte represents a number range from 0 to 255.
    The raw bytes data length must be 4.
    */
    function setDnsARecord(string memory domain, bytes4 ipv4) internal {
        address caller = _msgSender();
        (, uint256 ownedLevel,) = _registrar.traceOwner(domain, caller);
        if (ownedLevel == 0) {
            revert Unauthorized();
        }

        if (ipv4.length != 4) {
            revert InvalidIpV4Length();
        }

        _registrar.setTag(domain, _DNS_A_RECORD_RESOLVER, bytes.concat(ipv4));
    }

    function dnsARecord(string calldata domain) external view returns (bytes4 ipv4) {
        (bool exists, bytes memory value) = _registry.getTagValue(domain.tokenId(), _DNS_A_RECORD_RESOLVER);
        if (exists) {
            ipv4 = bytes4(value);
        } else {
            ipv4 = "";
        }
    }
}
