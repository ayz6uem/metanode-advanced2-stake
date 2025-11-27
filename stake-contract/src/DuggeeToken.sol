// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DuggeeToken is ERC20 {
    constructor() ERC20("DuggeeToken", "DGT") {
        _mint(msg.sender, 10000000000000 * 10 ** decimals());
    }
}