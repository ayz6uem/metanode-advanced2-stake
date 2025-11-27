// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DuggeeStake
 * @dev 多代币质押挖矿合约，支持多个代币池，每个池有不同的权重和最小质押数量
 * @notice 用户可以质押多种代币来获得奖励代币，支持解除质押锁定期和紧急暂停功能
 */
contract DuggeeStake is Initializable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    constructor() {
        // 禁用初始化器，防止代理合约的构造函数执行逻辑合约的构造函数
        // _disableInitializers();
    }

    /**
     * @dev 初始化合约
     * @param admin 管理员地址，将获得默认管理员角色
     * @param _rewardToken 奖励代币地址
     */
    function initialize(address admin, address _rewardToken) initializer public {
        // 初始化基础合约
        __AccessControl_init();    // 访问控制初始化
        __Pausable_init();        // 暂停功能初始化

        // 授予管理员角色
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        // 设置奖励代币
        rewardToken = IERC20(_rewardToken);

        // 设置基础参数
        startBlock = block.number;             // 奖励开始计算的区块
        rewardAmountPerBlock = 100 * 10 ** 18; // 每个区块产生100个奖励代币（18位小数）
        unstakeLockBlocks = 100;              // 解除质押锁定100个区块
    }

    /**
     * @dev 池信息结构体
     */
    struct Pool {
        uint256 weight;              // 池权重：用于分配总奖励的权重比例
        uint256 minStakeAmount;      // 最小质押数量：用户质押的最小数量要求
        uint256 totalStakeAmount;    // 总质押数量：当前池中所有用户质押的代币总量
        uint256 accAmountPerShare;   // 累积奖励：每单位代币累积的奖励数量
        uint256 lastAccAmountBlock;  // 最后更新区块：上一次更新累积奖励的区块号
    }

    /**
     * @dev 质押者信息结构体
     */
    struct Staker {
        uint256 stakeAmount;                // 当前质押数量：用户在当前池中质押的代币数量
        uint256 rewardStart;                // 奖励起始值：用于计算用户奖励的基准值
        uint256 claimingReward;             // 待领取奖励：用户累积但未领取的奖励数量
        UnstakeRequest[] unstakeRequest;    // 解除质押请求列表：用户发起的解除质押请求
    }

    /**
     * @dev 解除质押请求结构体
     */
    struct UnstakeRequest {
        uint256 amount;     // 解除质押数量：用户请求解除的代币数量
        bool finished;      // 是否已完成：标记该请求是否已处理完成
        uint256 unlockBlock; // 解锁区块：解除质押请求解锁的区块号
    }

    // 事件定义
    event PoolCreated(address tokenAddress, uint256 weight, uint256 minStakeAmount);
    event Staked(address tokenAddress, address staker, uint256 amount);
    event Unstaked(address tokenAddress, address staker, uint256 amount, uint256 unlockBlock);
    event Withdraw(address tokenAddress, address staker, uint256 amount);
    event Claim(address tokenAddress, address staker, uint256 amount);

    /**
     * @dev 授权升级函数，只有具有UPGRADE_ROLE的角色可以调用
     */
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADE_ROLE) {
    }

    // 角色定义
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade");  // 升级角色
    bytes32 public constant ADMIN_ROLE = keccak256("admin");      // 管理员角色

    // 核心变量
    IERC20 public rewardToken;              // 奖励代币合约
    uint256 public rewardAmountPerBlock;     // 每个区块产生的奖励数量
    uint256 public unstakeLockBlocks;        // 解除质押的锁定区块数
    uint256 public totalWeight;              // 所有池的总权重
    uint256 public startBlock;               // 奖励开始计算的区块号

    // 暂停开关
    // bool public stakePaused;     // 质押/解除质押是否暂停
    // bool public withdrawPaused;  // 提取是否暂停
    // bool public claimPaused;      // 领取奖励是否暂停
    uint8 public pausedConfig; // 0-未暂停 1-质押暂停 2-提现暂停 4-领取奖励暂停

    // 映射变量
    mapping(address => bool) public tokens;                                        // 代币是否支持质押
    mapping(address => uint256) public tokenPools;                                  // 代币地址到池ID的映射
    mapping(address => mapping(address => Staker)) stakers;                         // 代币地址 => 用户地址 => 质押者信息
    Pool[] public pools;                                                            // 池信息数组

    /**
     * @dev 修饰符：检查代币是否被支持
     */
    modifier checkToken(address tokenAddress) {
        _checkToken(tokenAddress);
        _;
    }

    /**
     * @dev 内部函数：检查代币是否支持质押
     * @param tokenAddress 代币地址
     */
    function _checkToken(address tokenAddress) internal view {
        require(tokens[tokenAddress], "token not support");
    }

    /**
     * @dev 创建新的质押池
     * @param _tokenAddress 代币地址（使用address(0)表示ETH）
     * @param _weight 池权重（1-9999）
     * @param _minStakeAmount 最小质押数量
     * @param _withupdate 是否在创建前更新所有池的奖励
     */
    function createPool(
        address _tokenAddress, uint256 _weight, uint256 _minStakeAmount, bool _withupdate
    ) external onlyRole(ADMIN_ROLE) whenNotPaused  {
        require(_weight > 0, "weight error");
        require(_weight < 10000, "weight error");
        require(!tokens[_tokenAddress], "token already exists");

        // 如果需要，在创建新池前更新所有现有池的累积奖励
        if (_withupdate) {
            _massUpdatePools();
        }

        // 创建新池
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

    /**
     * @dev 批量更新所有池的累积奖励
     */
    function _massUpdatePools() internal {
        for (uint256 i=0; i<pools.length ; i++) {
            _updatePool(i);
        }
    }

    /**
     * @dev 外部调用：更新指定池的累积奖励
     * @param pid 池ID
     */
    function updatePool(uint256 pid) external {
        _updatePool(pid);
    }

    /**
     * @dev 内部函数：更新池的累积奖励
     * @param pid 池ID
     */
    function _updatePool(uint256 pid) internal {
        Pool storage pool = pools[pid];
        // 如果当前区块小于等于最后更新区块，无需更新
        if (block.number <= pool.lastAccAmountBlock) {
            return;
        }

        // 如果池中没有质押，累积奖励归零
        if (pool.totalStakeAmount == 0) {
            pool.accAmountPerShare = 0;
        } else {
            // 计算池在当前期间产生的奖励：
            // 区块差 × 每区块奖励 × 池权重 / 总权重
            uint256 poolAmount = (block.number - pool.lastAccAmountBlock) * rewardAmountPerBlock * pool.weight / totalWeight;
            // 更新每单位代币的累积奖励
            pool.accAmountPerShare = pool.accAmountPerShare + poolAmount / pool.totalStakeAmount;
        }
        pool.lastAccAmountBlock = block.number;
    }

    /**
     * @dev 质押代币获得奖励
     * @param tokenAddress 代币地址（使用address(0)表示ETH）
     * @param amount 质押数量（ETH时需要与msg.value匹配）
     */
    function stake(address tokenAddress, uint256 amount) public payable checkToken(tokenAddress) whenNotPaused nonReentrant {
        require(pausedConfig & 1 != 1, "stake/unstake pausing");

        uint256 pid = tokenPools[tokenAddress];
        Pool storage pool = pools[pid];
        require(amount >= pool.minStakeAmount, "Stake amount too low");

        Staker storage staker = stakers[tokenAddress][msg.sender];

        // 处理代币转入
        if (tokenAddress == address(0)) {
            // ETH质押，检查发送的ETH数量
            require(msg.value == amount, "Incorrect ETH amount sent");
        } else {
            // ERC20代币质押，安全转入合约
            IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        }

        // 更新池的累积奖励
        _updatePool(pid);

        // 计算并保存用户当前待领取的奖励
        pool = pools[pid];
        if (staker.stakeAmount > 0) {
            staker.claimingReward += pool.accAmountPerShare * staker.stakeAmount - staker.rewardStart;
        }

        // 更新质押状态
        staker.stakeAmount += amount;
        pool.totalStakeAmount += amount;
        staker.rewardStart = pool.accAmountPerShare * staker.stakeAmount;

        emit Staked(tokenAddress, msg.sender, amount);
    }

    /**
     * @dev 解除质押，创建提取请求，经过锁定期后方可提取
     * @param tokenAddress 代币地址
     * @param _amount 解除质押数量
     */
    function unstake(
        address tokenAddress, uint256 _amount
        ) public whenNotPaused checkToken(tokenAddress) nonReentrant {
        require(_amount > 0, "amount error");
        require(pausedConfig & 1 != 1, "stake/unstake pausing");

        Staker storage staker = stakers[tokenAddress][msg.sender];
        require(staker.stakeAmount >= _amount, "amount error");

        uint256 pid = tokenPools[tokenAddress];

        // 更新池的累积奖励
        _updatePool(pid);

        Pool storage pool = pools[pid];

        // 计算并保存用户当前待领取的奖励
        if (staker.stakeAmount > 0) {
            staker.claimingReward += pool.accAmountPerShare * staker.stakeAmount - staker.rewardStart;
        }

        // 更新质押状态
        staker.stakeAmount -= _amount;
        pool.totalStakeAmount -= _amount;
        staker.rewardStart = pool.accAmountPerShare * staker.stakeAmount;

        // 创建解除质押请求，经过锁定期后可提取
        uint256 _unlockBlock = block.number + unstakeLockBlocks;
        staker.unstakeRequest.push(UnstakeRequest({
            amount: _amount,
            finished: false,
            unlockBlock: _unlockBlock
        }));

        emit Unstaked(tokenAddress, msg.sender, _amount, _unlockBlock);
    }

    /**
     * @dev 提取已解锁的解除质押代币
     * @param tokenAddress 代币地址
     */
    function withdraw(address tokenAddress) external whenNotPaused nonReentrant checkToken(tokenAddress) {
        require(pausedConfig & 2 != 2, "withdraw pausing");

        Staker storage staker = stakers[tokenAddress][msg.sender];
        uint256 amount = 0;

        // 查找所有已解锁的解除质押请求
        for(uint256 i=0; i<staker.unstakeRequest.length; i++) {
            UnstakeRequest storage request = staker.unstakeRequest[i];
            if (!request.finished && request.unlockBlock <= block.number) {
                amount += request.amount;
                request.finished = true;  // 标记为已处理
            }
        }

        // 如果有可提取的代币，执行转账
        if (amount > 0) {
            if(tokenAddress == address(0)) {
                // ETH提取
                (bool ok, ) = payable(msg.sender).call{value:amount}("");
                require(ok, "unstake error");
            } else {
                // ERC20代币提取
                IERC20(tokenAddress).safeTransfer(msg.sender, amount);
            }

            emit Withdraw(tokenAddress, msg.sender, amount);
        }
    }

    /**
     * @dev 领取质押产生的奖励
     * @param tokenAddress 代币地址
     */
    function claim(address tokenAddress) public whenNotPaused nonReentrant checkToken(tokenAddress) {
        require(pausedConfig & 4 != 4, "claim pausing");

        Staker storage staker = stakers[tokenAddress][msg.sender];
        uint256 pid = tokenPools[tokenAddress];

        // 更新池的累积奖励
        _updatePool(pid);
        Pool storage pool = pools[pid];

        // 计算用户当前待领取的奖励
        if (staker.stakeAmount > 0) {
            staker.claimingReward += pool.accAmountPerShare * staker.stakeAmount - staker.rewardStart;
        }

        // 重置奖励起始值
        staker.rewardStart = pool.accAmountPerShare * staker.stakeAmount;

        // 如果有待领取奖励，执行转账
        if (staker.claimingReward > 0) {
            uint256 amount = staker.claimingReward;
            staker.claimingReward = 0;

            // 检查合约奖励代币余额是否充足
            require(rewardToken.balanceOf(address(this)) >= amount, "contract reward token balance not enough");

            // 安全转账奖励代币
            rewardToken.safeTransfer(msg.sender, amount);

            emit Claim(tokenAddress, msg.sender, amount);
        }
    }

    /**
     * @dev 获取池信息
     * @param pid 池ID
     * @return Pool 池结构体数据
     */
    function getPool(uint256 pid) public view returns(Pool memory) {
        return pools[pid];
    }

    /**
     * @dev 获取质押者信息
     * @param tokenAddress 代币地址
     * @param staker 质押者地址
     * @return Staker 质押者结构体数据
     */
    function getStaker(address tokenAddress, address staker) public view returns (Staker memory) {
        return stakers[tokenAddress][staker];
    }

    /**
     * @dev 设置暂停状态
     */
    function setPausedConfig(uint8 _pausedConfig) external onlyRole(ADMIN_ROLE) {
        pausedConfig = _pausedConfig;
    }
}