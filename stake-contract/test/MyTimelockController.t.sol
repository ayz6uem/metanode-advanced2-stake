// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MyTimelockController} from "../src/MyTimelockController.sol";

contract MyTimelockControllerTest is Test {
    MyTimelockController public timelock;

    function setUp() public {
        address[] memory proposers = new address[](1);
        proposers[0] = msg.sender;
        timelock = new MyTimelockController(1 days, proposers, proposers, msg.sender);
    }

}
