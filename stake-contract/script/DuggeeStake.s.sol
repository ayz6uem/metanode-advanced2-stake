// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {DuggeeStake} from "../src/DuggeeStake.sol";
import {DuggeeToken} from "../src/DuggeeToken.sol";

contract DuggeeStakeScript is Script {

    DuggeeToken public duggeeToken;
    DuggeeStake public duggeeStake;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        
        duggeeToken = new DuggeeToken();

        duggeeStake = new DuggeeStake();
        duggeeStake.initialize(admin, address(duggeeToken));

        // duggeeStake.grantRole(duggeeStake.ADMIN_ROLE(), msg.sender);
        // duggeeStake.grantRole(duggeeStake.UPGRADE_ROLE(), msg.sender);

        // duggeeStake.createPool(address(0), 10, 0.001 ether, false);

        vm.stopBroadcast();
    }
}
