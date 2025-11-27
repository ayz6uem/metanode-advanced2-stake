// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract MyTimelockController is TimelockController{
    
    constructor(
        uint256 minDelay,               // 最短延迟（秒）
        address[] memory proposers,     // 拥有 PROPOSER_ROLE 的地址
        address[] memory executors,     // 拥有 EXECUTOR_ROLE 的地址
        address admin                   // 初始 ADMIN_ROLE，部署后建议立即放弃
    ) TimelockController(minDelay, proposers, executors, admin) {}
}
