// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {DuggeeToken} from "../src/DuggeeToken.sol";

contract MintScript is Script {

    DuggeeToken public duggeeToken;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address tokenAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        address stakeAddress = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
        
        duggeeToken = DuggeeToken(tokenAddress);

        duggeeToken.mint(stakeAddress, 10000 ether);

        vm.stopBroadcast();
    }
}
