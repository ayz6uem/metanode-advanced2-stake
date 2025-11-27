// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {DuggeeStake} from "../src/DuggeeStake.sol";

contract CreatePoolScript is Script {

    DuggeeStake public duggeeStake;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address tokenAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        address stakeAddress = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
        address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

        duggeeStake = DuggeeStake(stakeAddress);

        duggeeStake.grantRole(duggeeStake.ADMIN_ROLE(), admin);
        duggeeStake.grantRole(duggeeStake.UPGRADE_ROLE(), admin);

        duggeeStake.createPool(address(0), 10, 0.001 ether, false);

        vm.stopBroadcast();
    }
}
