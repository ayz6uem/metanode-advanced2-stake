// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DuggeeToken is ERC20 {
    constructor() ERC20("DuggeeToken", "DGT") {
    }

    function mint(address user, uint256 amount) public {
        _mint(user, amount);
    }
}