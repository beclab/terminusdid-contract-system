// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract ERC721Receiver is IERC721Receiver {
    event ReceivedERC721Token(address indexed operator, address indexed from, uint256 indexed tokenId, bytes data);

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        emit ReceivedERC721Token(operator, from, tokenId, data);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract ERC721InvalidReceiver {
    event ReceivedERC721Token(address indexed operator, address indexed from, uint256 indexed tokenId, bytes data);

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external {
        emit ReceivedERC721Token(operator, from, tokenId, data);
        revert("this is a invalid erc721 receiver");
    }
}
