// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {BytesUtils} from "ens-contracts/dnssec-oracle/BytesUtils.sol";
import {IResolver} from "./IResolver.sol";
import {ITerminusDID, IRegistrar} from "../utils/Interfaces.sol";
import {Asn1Decode} from "../utils/Asn1Decode.sol";

contract RootResolver is IResolver, Context {
    using Asn1Decode for bytes;
    using BytesUtils for bytes;

    // http://oid-info.com/get/1.2.840.113549.1.1.1
    bytes public constant _OID_PKCS = hex"2a864886f70d010101";

    uint256 private constant _RSA_PUBKEY_RESOLVER = 0x12;
    uint256 private constant _DNS_A_RECORD_RESOLVER = 0x13;

    address private _operator;
    IRegistrar private _registrar;
    ITerminusDID private _registry;

    error Unauthorized();

    modifier authorizationCheck(string memory domain) {
        address caller = _msgSender();
        if (caller != _operator) {
            (, uint256 ownedLevel,) = _registrar.traceOwner(domain, caller);
            if (ownedLevel == 0) {
                revert Unauthorized();
            }
        }
        _;
    }

    constructor(address registrar_, address registry_, address operator_) {
        _registrar = IRegistrar(registrar_);
        _registry = ITerminusDID(registry_);
        _operator = operator_;
    }

    function tagGetter(uint256 key) external pure returns (bytes4) {
        if (key == _RSA_PUBKEY_RESOLVER) {
            return this.rsaPubKey.selector;
        } else if (key == _DNS_A_RECORD_RESOLVER) {
            return this.dnsARecord.selector;
        } else if (key <= 0xffff) {
            return bytes4(0xffffffff);
        } else {
            return 0;
        }
    }

    function registrar() external view returns (address) {
        return address(_registrar);
    }

    function registry() external view returns (address) {
        return address(_registry);
    }

    function operator() external view returns (address) {
        return _operator;
    }

    /*
    RSAPublicKey support RSA Pkcs8 ASN.1 format:
    EncryptedPrivateKeyInfo SEQUENE
        encryptionAlgorithm SEQUENCE
            algorithm OBJECT IDENTIFIER
            parameters
        encryptedData BIT STRING
            SEQUENCE
                INTEGER -- modulus
                INTEGER -- exponent
    */
    function setRsaPubKey(string calldata domain, bytes calldata pubKey) external authorizationCheck(domain) {
        if (pubKey.length == 0) {
            _registrar.setTag(domain, _RSA_PUBKEY_RESOLVER, "");
        } else {
            uint256 encryptedPrivateKeyInfoRange = pubKey.rootOfSequenceStringAt(0);
            bytes memory encryptedPrivateKeyInfo = pubKey.bytesAt(encryptedPrivateKeyInfoRange);

            uint256 encryptionAlgorithmRange = encryptedPrivateKeyInfo.rootOfSequenceStringAt(0);
            {
                bytes memory encryptionAlgorithm = encryptedPrivateKeyInfo.bytesAt(encryptionAlgorithmRange);

                uint256 algorithmRange = encryptionAlgorithm.rootOfObjectIdentifierAt(0);
                bytes memory algorithm = encryptionAlgorithm.bytesAt(algorithmRange);
                require(algorithm.equals(_OID_PKCS), "Rsa pub key parsing: not PKCS format");
            }

            {
                uint256 encryptedDataRange = encryptedPrivateKeyInfo.nextSiblingOf(encryptionAlgorithmRange);
                bytes memory encryptedData = encryptedPrivateKeyInfo.bitstringAt(encryptedDataRange);

                uint256 sequenceRange = encryptedData.rootOfSequenceStringAt(0);
                bytes memory sequence = encryptedData.bytesAt(sequenceRange);

                uint256 modulusRange = sequence.root();
                sequence.uintBytesAt(modulusRange);

                uint256 publicExponentRange = sequence.nextSiblingOf(modulusRange);
                sequence.uintAt(publicExponentRange);
            }

            _registrar.setTag(domain, _RSA_PUBKEY_RESOLVER, pubKey);
        }
    }

    function rsaPubKey(uint256 tokenId) external view returns (bytes memory pubKey) {
        (, pubKey) = _registry.getTagValue(tokenId, _RSA_PUBKEY_RESOLVER);
    }

    /*
    DNS A record can be represent by 4 bytes, in which each byte represents a number range from 0 to 255.
    The raw bytes data length must be 4.
    */
    function setDnsARecord(string memory domain, bytes4 ipv4) external authorizationCheck(domain) {
        if (ipv4 == bytes4(0)) {
            _registrar.setTag(domain, _DNS_A_RECORD_RESOLVER, "");
        } else {
            _registrar.setTag(domain, _DNS_A_RECORD_RESOLVER, bytes.concat(ipv4));
        }
    }

    function dnsARecord(uint256 tokenId) external view returns (bytes4 ipv4) {
        (bool exists, bytes memory value) = _registry.getTagValue(tokenId, _DNS_A_RECORD_RESOLVER);
        if (exists) {
            ipv4 = bytes4(value);
        }
    }
}
