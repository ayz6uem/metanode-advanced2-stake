// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DuggeeStake is Initializable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    constructor() {
        // _disableInitializers();
    }

    function initialize(address _rewardToken) initializer public {
        __AccessControl_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        rewardToken = IERC20(_rewardToken);
        startBlock = block.number;
        rewardAmountPerBlock = 100 * 10 ** 18;
        unstakeLockBlocks = 100;
    }

    struct Pool {
        // 资金池权重
        uint256 weight;
        // 最小可质押数量
        uint256 minStakeAmount;
        // 当前总质押token数
        uint256 totalStakeAmount;
        // 每份token可获得奖励数
        uint256 accAmountPerShare;
        // 最后更新accAmount的block
        uint256 lastAccAmountBlock;
    }

    struct Staker {
        // 质押数量
        uint256 stakeAmount;
        // 奖励
        uint256 rewardStart;
        // 待领取的奖励
        uint256 claimingReward;
        // 解除质押请求
        UnstakeRequest[] unstakeRequest;
    }

    // 解除质押请求
    struct UnstakeRequest {
        uint256 amount;
        bool finished;
        uint256 unlockBlock;
    }

    event PoolCreated(address tokenAddress, uint256 weight, uint256 minStakeAmount);
    event Staked(address tokenAddress, address staker, uint256 amount);
    event Unstaked(address tokenAddress, address staker, uint256 amount, uint256 unlockBlock);
    event Withdraw(address tokenAddress, address staker, uint256 amount);
    event Claim(address tokenAddress, address staker, uint256 amount);
    
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADE_ROLE) {
    }

    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade");
    bytes32 public constant ADMIN_ROLE = keccak256("admin");

    IERC20 public rewardToken;
    // 每个块奖励数量
    uint256 public rewardAmountPerBlock;
    // 解押锁定区块数
    uint256 public unstakeLockBlocks;
    // 总权重
    uint256 public totalWeight;
    // 产生收益开始区块
    uint256 public startBlock;

    bool public stakePaused;
    bool public withdrawPaused;
    bool public claimPaused;

    // token 是否支持
    mapping(address => bool) public tokens;
    // 池信息 可通过token地址快速找到池
    mapping(address => uint256) public tokenPools;
    // 池信息
    Pool[] public pools;
    // 质押者信息 token地址 => 用户地址 => 质押者信息
    mapping(address => mapping(address => Staker)) stakers;

    modifier checkToken(address tokenAddress) {
        require(tokens[tokenAddress], "token not support");
        _;
    }

    function createPool(
        address _tokenAddress, uint256 _weight, uint256 _minStakeAmount, bool _withupdate
    ) external onlyRole(ADMIN_ROLE) whenNotPaused  {
        require(_weight > 0, "weight error");
        require(_weight < 10000, "weight error");
        require(!tokens[_tokenAddress], "token already exists");

        if (_withupdate) {
            _massUpdatePools();
        }

        tokens[_tokenAddress] = true;
        tokenPools[_tokenAddress] = pools.length;
        pools.push(Pool({
            weight: _weight,
            minStakeAmount: _minStakeAmount,
            totalStakeAmount: 0,
            accAmountPerShare: 0,
            lastAccAmountBlock: block.number
        }));
        totalWeight += _weight;
        emit PoolCreated(_tokenAddress, _weight, _minStakeAmount);
    }

    function _massUpdatePools() internal {
        for (uint256 i=0; i<pools.length ; i++) {
            _updatePool(i);
        }
    }

    function updatePool(uint256 pid) external {
        _updatePool(pid);
    }

    function _updatePool(uint256 pid) internal {
        Pool storage pool = pools[pid];
        if (block.number <= pool.lastAccAmountBlock) {
            return;
        }
        if (pool.totalStakeAmount == 0) {
            pool.accAmountPerShare = 0;
        } else {
            uint256 poolAmount = (block.number - pool.lastAccAmountBlock) * rewardAmountPerBlock * pool.weight / totalWeight;
            pool.accAmountPerShare = pool.accAmountPerShare + poolAmount / pool.totalStakeAmount;
        }
        pool.lastAccAmountBlock = block.number;
    }

    function stake(address tokenAddress, uint256 amount) public payable checkToken(tokenAddress) whenNotPaused nonReentrant {
        require(!stakePaused, "stake/unstake pausing");
        uint256 pid = tokenPools[tokenAddress];
        Pool storage pool = pools[pid];
        require(amount >= pool.minStakeAmount, "Stake amount too low");
        Staker storage staker = stakers[tokenAddress][msg.sender];
        if (tokenAddress == address(0)) {
            require(msg.value == amount, "Incorrect ETH amount sent");
        } else {
            IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
            // require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount), "transfer token failed");
        }

        _updatePool(pid);

        pool = pools[pid];
        if (staker.stakeAmount > 0) {
            staker.claimingReward += pool.accAmountPerShare * staker.stakeAmount - staker.rewardStart;
        }
        
        staker.stakeAmount += amount;
        pool.totalStakeAmount += amount;
        staker.rewardStart = pool.accAmountPerShare * staker.stakeAmount;

        emit Staked(tokenAddress, msg.sender, amount);
    }

    function unstake(
        address tokenAddress, uint256 _amount
        ) public whenNotPaused checkToken(tokenAddress) nonReentrant {
        require(_amount > 0, "amount error");
        require(!stakePaused, "stake/unstake pausing");
        Staker storage staker = stakers[tokenAddress][msg.sender];
        require(staker.stakeAmount >= _amount, "amount error");
        uint256 pid = tokenPools[tokenAddress];

        _updatePool(pid);

        Pool storage pool = pools[pid];
        if (staker.stakeAmount > 0) {
            staker.claimingReward += pool.accAmountPerShare * staker.stakeAmount - staker.rewardStart;
        }

        staker.stakeAmount -= _amount;
        pool.totalStakeAmount -= _amount;
        staker.rewardStart = pool.accAmountPerShare * staker.stakeAmount;

        uint256 _unlockBlock = block.number + unstakeLockBlocks;
        staker.unstakeRequest.push(UnstakeRequest({
            amount: _amount,
            finished: false,
            unlockBlock: _unlockBlock
        }));

        emit Unstaked(tokenAddress, msg.sender, _amount, _unlockBlock);
    }

    function withdraw(address tokenAddress) external whenNotPaused nonReentrant checkToken(tokenAddress) {
        require(!withdrawPaused, "withdraw pausing");
        Staker storage staker = stakers[tokenAddress][msg.sender];

        uint256 amount = 0;
        for(uint256 i=0;i<staker.unstakeRequest.length; i++) {
            UnstakeRequest storage request = staker.unstakeRequest[i];
            if (!request.finished && request.unlockBlock <= block.number) {
                amount += request.amount;
                request.finished = true;
            }
        }

        if (amount > 0) {
            if(tokenAddress == address(0)) {
                (bool ok, ) = payable(msg.sender).call{value:amount}("");
                require(ok, "unstake error");
            } else {
                IERC20(tokenAddress).safeTransfer(msg.sender, amount);
                // require(tokenAddress.transfer(msg.sender, amount), "withdraw fail");
            }

            emit Withdraw(tokenAddress, msg.sender, amount);
        }
    }

    function claim(address tokenAddress) public whenNotPaused nonReentrant checkToken(tokenAddress) {
        require(!claimPaused, "claim pausing");
        Staker storage staker = stakers[tokenAddress][msg.sender];

        uint256 pid = tokenPools[tokenAddress];
        _updatePool(pid);
        Pool storage pool = pools[pid];
        if (staker.stakeAmount > 0) {
            staker.claimingReward += pool.accAmountPerShare * staker.stakeAmount - staker.rewardStart;
        }
        staker.rewardStart = pool.accAmountPerShare * staker.stakeAmount;

        if (staker.claimingReward > 0) {
            uint256 amount = staker.claimingReward;
            staker.claimingReward = 0;
            require(rewardToken.balanceOf(address(this)) >= amount, "contract reward token balance not enough");
            rewardToken.safeTransfer(msg.sender, amount);
            // require(rewardToken.transfer(msg.sender, amount), "claim fail");

            emit Claim(tokenAddress, msg.sender, amount);
        }
    }

    function getPool(uint256 pid) public view returns(Pool memory) {
        return pools[pid];
    }

    function getStaker(address tokenAddress, address staker) public view returns (Staker memory) {
        return stakers[tokenAddress][staker];
    }

    function setStakePaused(bool _stakePaused) external onlyRole(ADMIN_ROLE) {
        stakePaused = _stakePaused;
    }

    function setWithdrawPaused(bool _withdrawPaused) external onlyRole(ADMIN_ROLE) {
        withdrawPaused = _withdrawPaused;
    }
    function setClaimPaused(bool _claimPaused) external onlyRole(ADMIN_ROLE) {
        claimPaused = _claimPaused;
    }


}