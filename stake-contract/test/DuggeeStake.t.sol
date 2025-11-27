// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {console} from "forge-std/console.sol";
import {DuggeeToken} from "../src/DuggeeToken.sol";
import {DuggeeStake} from "../src/DuggeeStake.sol";

contract DuggeeStakeTest is Test {
    DuggeeToken public token;
    DuggeeStake public stake;

    address public staker1 = address(0x1);
    address public staker2 = address(0x2);

    function setUp() public {
        token = new DuggeeToken();
        stake = new DuggeeStake();
        stake.initialize(address(token));
        token.transfer(address(stake), 10000000 ether);

        vm.deal(staker1, 100 ether);
        vm.deal(staker2, 100 ether);

        stake.grantRole(stake.ADMIN_ROLE(), address(this));
        stake.grantRole(stake.UPGRADE_ROLE(), address(this));

        stake.createPool(address(0), 10, 0.001 ether, false);
    }

    function test_createPool_ETH() public view {
        assertTrue(stake.tokens(address(0)), "token not enable");
        uint256 pid = stake.tokenPools(address(0));
        DuggeeStake.Pool memory pool = stake.getPool(pid);
        assertEq(pool.weight, 10, "pool weight error");
        assertEq(stake.totalWeight(), 10, "total weight error");
    }

    function test_stake_amountCheck() public {
        vm.startPrank(staker1);
        vm.expectRevert("Incorrect ETH amount sent");
        stake.stake{value:9 ether}(address(0), 10 ether);
        vm.stopPrank();
    }

    function test_stake_one() public {
        vm.roll(10);
        vm.startPrank(staker1);
        stake.stake{value:10 ether}(address(0), 10 ether);
        vm.roll(20);
        stake.unstake(address(0), 10 ether);
        stake.claim(address(0));
        assertEq(token.balanceOf(staker1), 1000 ether, "claim error");
        vm.roll(120);
        stake.withdraw(address(0));
        assertEq(staker1.balance, 100 ether, "balance error");
        vm.stopPrank();
    }

    function test_stake_two() public {
        vm.roll(10);
        vm.prank(staker1);
        stake.stake{value:10 ether}(address(0), 10 ether);

        vm.roll(110);
        vm.prank(staker2);
        stake.stake{value:10 ether}(address(0), 10 ether);

        vm.roll(210);
        vm.prank(staker2);
        stake.unstake(address(0), 10 ether);

        vm.roll(310);
        vm.prank(staker1);
        stake.unstake(address(0), 10 ether);

        vm.roll(410);
        DuggeeStake.Staker memory ds1 = stake.getStaker(address(0), staker1);
        console.log("staker1 claimingReward ", ds1.claimingReward / 10 ** 18);
        DuggeeStake.Staker memory ds2 = stake.getStaker(address(0), staker2);
        console.log("staker2 claimingReward ", ds2.claimingReward / 10 ** 18);

        vm.startPrank(staker1);
        stake.claim(address(0));
        stake.withdraw(address(0));
        vm.stopPrank();
        
        vm.startPrank(staker2);
        stake.claim(address(0));
        stake.withdraw(address(0));
        vm.stopPrank();

        console.log("staker1 balance ", staker1.balance / 10 ** 18);
        console.log("staker1 token balance ", token.balanceOf(staker1) / 10 ** 18);
        console.log("staker2 balance ", staker2.balance / 10 ** 18);
        console.log("staker2 token balance ", token.balanceOf(staker2) / 10 ** 18);
    }

}
