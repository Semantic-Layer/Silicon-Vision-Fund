// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "solmate/src/tokens/ERC20.sol";

contract Token is ERC20 {
    bool private minted;

    error AlreadyMinted();

    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) {}

    /**
     * called by factory contract. only minted once
     * @param action action contract address
     */
    function mint(address action) public {
        if (minted) revert AlreadyMinted();
        _mint(msg.sender, 500 * 10 ** 18);
        _mint(action, 500 * 10 ** 18);
    }
}
