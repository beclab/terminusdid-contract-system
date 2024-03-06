// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SignatureHelper {
    enum SigAlg {ECDSA}
    enum Action {
        Add,
        Remove
    }

    struct AuthAddressReq {
        address addr;
        SigAlg algorithm;
        string domain;
        uint256 signAt;
        Action action;
    }

    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 constant AUTH_ADDRESS_TYPEHASH =
        keccak256("AuthAddressReq(address addr,uint8 algorithm,string domain,uint256 signAt,uint8 action)");

    bytes32 public immutable DOMAIN_SEPARATOR;

    constructor() {
        DOMAIN_SEPARATOR =
            keccak256(abi.encode(EIP712DOMAIN_TYPEHASH, keccak256("Terminus DID Root Tagger"), keccak256("1"), getChainId(), this));
    }

    function recoverSigner(AuthAddressReq calldata authAddressReq, bytes calldata sig)
        internal
        view
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(sig);
        return ECDSA.recover(getSigningMessage(authAddressReq), v, r, s);
    }

    function getSigningMessage(AuthAddressReq calldata authAddressReq) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        AUTH_ADDRESS_TYPEHASH,
                        authAddressReq.addr,
                        authAddressReq.algorithm,
                        keccak256(bytes(authAddressReq.domain)),
                        authAddressReq.signAt,
                        authAddressReq.action
                    )
                )
            )
        );
    }

    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");
        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }

    /**
     * @notice Returns the current chainId using the chainid opcode
     * @return id uint256 The chain id
     */
    function getChainId() internal view returns (uint256 id) {
        // no-inline-assembly
        assembly {
            id := chainid()
        }
    }
}
