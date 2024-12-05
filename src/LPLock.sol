// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC721, ERC721TokenReceiver} from "solmate/src/tokens/ERC721.sol";

import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
/**
 * @notice It implements univ4 LP lock
 * we implement lp locking by having a 1:1 nft mapping between our nft and univ4 lp nft
 * the uninft is minted to the hook contract itself.
 * user will be issued an nft that can be used to redeem back the uninft after locking window.
 */

abstract contract LPLock is ERC721, ERC721TokenReceiver {
    ///@dev lp lock window
    uint256 public constant LOCK_WINDOW = 1 days;

    ///@dev univ4 nft address. aka the positionManager address
    ERC721 public immutable uniNFT;

    uint256 private _nextTokenId;

    ///@dev map between our own nft and univ4 lp nft
    mapping(uint256 nftId => uint256 uniNftId) public nft2UniNFT;

    ///@dev record univ4 lp position lock time
    mapping(uint256 uniNFTId => uint256 time) lockTime;

    error ErrLocked();

    constructor(address _uniNFT) ERC721("VisonLP", "VLP") {
        uniNFT = ERC721(_uniNFT);
    }

    modifier AfterLock(uint256 uniNFTId) {
        if (lockTime[uniNFTId] + LOCK_WINDOW > block.timestamp) revert ErrLocked();
        _;
    }

    // call by hook contract
    function _mintLPProof(address to, uint256 uniNFTId) internal {
        uint256 tokenId = _nextTokenId++;
        lockTime[uniNFTId] = block.timestamp;
        _safeMint(to, tokenId);
        nft2UniNFT[tokenId] = uniNFTId;
    }

    // call by user to redeem lp back
    function redeemLP(uint256 tokenId) public AfterLock(nft2UniNFT[tokenId]) {
        ERC721._burn(tokenId);

        uniNFT.safeTransferFrom(address(this), msg.sender, nft2UniNFT[tokenId], "");

        delete lockTime[nft2UniNFT[tokenId]];
        delete nft2UniNFT[tokenId];
    }
}
