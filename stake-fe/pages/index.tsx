import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useWriteContract, useReadContract, useBalance } from 'wagmi';
import { useState } from 'react';
import type { NextPage } from 'next';
import Head from 'next/head';
import styles from '../styles/Home.module.css';
import { parseEther, formatEther } from 'viem';

// 合约地址和 ABI
const DUGGEE_STAKE_ADDRESS = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'; // 质押合约地址

// ETH 池的 token 地址为 address(0)
const ETH_TOKEN_ADDRESS = '0x0000000000000000000000000000000000000000';

// 根据实际合约更新的 ABI
const STAKE_CONTRACT_ABI = [
  {
    inputs: [{ internalType: 'uint256', name: 'pid', type: 'uint256' }],
    name: 'getPool',
    outputs: [
      {
        components: [
          { internalType: 'uint256', name: 'weight', type: 'uint256' },
          { internalType: 'uint256', name: 'minStakeAmount', type: 'uint256' },
          { internalType: 'uint256', name: 'totalStakeAmount', type: 'uint256' },
          { internalType: 'uint256', name: 'accAmountPerShare', type: 'uint256' },
          { internalType: 'uint256', name: 'lastAccAmountBlock', type: 'uint256' }
        ],
        internalType: 'struct DuggeeStake.Pool',
        name: '',
        type: 'tuple'
      }
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'tokenAddress', type: 'address' },
      { internalType: 'address', name: 'staker', type: 'address' }
    ],
    name: 'getStaker',
    outputs: [
      {
        components: [
          { internalType: 'uint256', name: 'stakeAmount', type: 'uint256' },
          { internalType: 'uint256', name: 'rewardStart', type: 'uint256' },
          { internalType: 'uint256', name: 'claimingReward', type: 'uint256' },
          {
            components: [
              { internalType: 'uint256', name: 'amount', type: 'uint256' },
              { internalType: 'bool', name: 'finished', type: 'bool' },
              { internalType: 'uint256', name: 'unlockBlock', type: 'uint256' }
            ],
            internalType: 'struct DuggeeStake.UnstakeRequest[]',
            name: 'unstakeRequest',
            type: 'tuple[]'
          }
        ],
        internalType: 'struct DuggeeStake.Staker',
        name: '',
        type: 'tuple'
      }
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'tokenAddress', type: 'address' },
      { internalType: 'uint256', name: 'amount', type: 'uint256' }
    ],
    name: 'stake',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'tokenAddress', type: 'address' },
      { internalType: 'uint256', name: '_amount', type: 'uint256' }
    ],
    name: 'unstake',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: 'tokenAddress', type: 'address' }],
    name: 'claim',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: 'tokenAddress', type: 'address' }],
    name: 'withdraw',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;

const Home: NextPage = () => {
  const { address, isConnected, chain } = useAccount();
  const { writeContract } = useWriteContract();

  // 状态管理
  const [stakeAmount, setStakeAmount] = useState('');
  const [unstakeAmount, setUnstakeAmount] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  // 确认是否在正确的网络上（根据合约地址判断）
  const isCorrectNetwork = chain?.id === 31337 || chain?.id === 31338; // localhost/hardhat 网络

  // 读取合约数据 - 获取 ETH 池信息 (pid 为 0)
  const { data: poolData } = useReadContract({
    address: DUGGEE_STAKE_ADDRESS as `0x${string}`,
    abi: STAKE_CONTRACT_ABI,
    functionName: 'getPool',
    args: [BigInt(0)], // ETH 池的 pid 应该是 0
  });

  const { data: stakerData } = useReadContract({
    address: DUGGEE_STAKE_ADDRESS as `0x${string}`,
    abi: STAKE_CONTRACT_ABI,
    functionName: 'getStaker',
    args: address ? [ETH_TOKEN_ADDRESS, address] : undefined,
  });

  // 获取用户ETH余额
  const { data: ethBalance } = useBalance({
    address: address,
  });

  
  // 质押功能
  const handleStake = async () => {
    if (!stakeAmount || parseFloat(stakeAmount) <= 0) {
      alert('请输入有效的质押数量');
      return;
    }

    try {
      setIsLoading(true);
      const amountInWei = parseEther(stakeAmount);

      writeContract({
        address: DUGGEE_STAKE_ADDRESS as `0x${string}`,
        abi: STAKE_CONTRACT_ABI,
        functionName: 'stake',
        args: [ETH_TOKEN_ADDRESS, amountInWei],
        value: amountInWei,
      });

      setStakeAmount('');
    } catch (error) {
      console.error('质押失败:', error);
      alert('质押失败，请检查交易详情');
    } finally {
      setIsLoading(false);
    }
  };

  // 解质押功能
  const handleUnstake = async () => {
    if (!unstakeAmount || parseFloat(unstakeAmount) <= 0) {
      alert('请输入有效的解质押数量');
      return;
    }

    try {
      setIsLoading(true);
      const amountInWei = parseEther(unstakeAmount);

      writeContract({
        address: DUGGEE_STAKE_ADDRESS as `0x${string}`,
        abi: STAKE_CONTRACT_ABI,
        functionName: 'unstake',
        args: [ETH_TOKEN_ADDRESS, amountInWei],
      });

      setUnstakeAmount('');
    } catch (error) {
      console.error('解质押失败:', error);
      alert('解质押失败，请检查交易详情');
    } finally {
      setIsLoading(false);
    }
  };

  // 领取奖励功能
  const handleClaimRewards = async () => {
    try {
      setIsLoading(true);

      writeContract({
        address: DUGGEE_STAKE_ADDRESS as `0x${string}`,
        abi: STAKE_CONTRACT_ABI,
        functionName: 'claim',
        args: [ETH_TOKEN_ADDRESS],
      });
    } catch (error) {
      console.error('领取奖励失败:', error);
      alert('领取奖励失败，请检查交易详情');
    } finally {
      setIsLoading(false);
    }
  };

  // 格式化显示数值
  const formatDisplayValue = (value: bigint | undefined) => {
    if (!value) return '0.00';
    return parseFloat(formatEther(value)).toFixed(4);
  };

  return (
    <div className={styles.container}>
      <Head>
        <title>DUGGEE 质押平台</title>
        <meta
          content="DUGGEE ETH 质押平台"
          name="description"
        />
        <link href="/favicon.ico" rel="icon" />
      </Head>

      <header className={styles.header}>
        <div className={styles.htitle}>DUGGEE Stake 质押平台</div>
        <div className={styles.hwallet}>
          <ConnectButton />
        </div>
      </header>

      <main className={styles.main}>
        <div className={`${styles.stakePool} ${isLoading ? styles.loading : ''}`}>
          {/* 第一行：ETH 质押池标题 */}
          <div className={styles.stakeTitle}>ETH 质押池</div>

          {/* 第二行：总质押量 */}
          <div className={styles.totalStaked}>
            总质押量: {formatDisplayValue(poolData?.totalStakeAmount)} ETH
          </div>

          {/* 第三行：分割线 */}
          <div className={styles.divider}></div>

          {/* 第四行：我的质押量 */}
          <div className={styles.myStaked}>
            我的质押量: {formatDisplayValue(stakerData?.stakeAmount)} ETH
          </div>

          {/* 第四行新增：我的ETH余额 */}
          <div className={styles.myBalance}>
            我的ETH余额: {ethBalance ? parseFloat(formatEther(ethBalance.value)).toFixed(4) : '0.0000'} ETH
          </div>

  
          {/* 第五行：输入框 */}
          <div className={styles.inputSection}>
            <div className={styles.inputGroup}>
              <input
                type="number"
                className={styles.stakeInput}
                placeholder="输入质押数量"
                value={stakeAmount}
                onChange={(e) => setStakeAmount(e.target.value)}
                disabled={!isConnected || isLoading}
                step="0.001"
                min="0"
              />
              <span className={styles.inputUnit}>ETH</span>
            </div>
          </div>

          {/* 第六行：质押和解质押按钮 */}
          <div className={styles.buttonGroup}>
            <button
              className={styles.stakeButton}
              onClick={handleStake}
              disabled={!isConnected || isLoading || !stakeAmount}
            >
              {isLoading ? '处理中...' : '质押'}
            </button>
            <button
              className={styles.unstakeButton}
              onClick={() => {
                setStakeAmount('');
                setUnstakeAmount(stakerData?.stakeAmount ? formatDisplayValue(stakerData.stakeAmount) : '0');
              }}
              disabled={!isConnected || isLoading || !stakerData || stakerData.stakeAmount === BigInt(0)}
            >
              解质押
            </button>
          </div>

          {/* 解质押输入框 (仅在点击解质押后显示) */}
          {unstakeAmount && (
            <div className={styles.inputSection}>
              <div className={styles.inputGroup}>
                <input
                  type="number"
                  className={styles.stakeInput}
                  placeholder="输入解质押数量"
                  value={unstakeAmount}
                  onChange={(e) => setUnstakeAmount(e.target.value)}
                  disabled={!isConnected || isLoading}
                  step="0.001"
                  min="0"
                  max={stakerData?.stakeAmount ? formatDisplayValue(stakerData.stakeAmount) : '0'}
                />
                <span className={styles.inputUnit}>ETH</span>
              </div>
              <button
                className={styles.unstakeButton}
                onClick={handleUnstake}
                disabled={!isConnected || isLoading || !unstakeAmount}
                style={{ marginTop: '0.5rem', width: '100%' }}
              >
                {isLoading ? '处理中...' : '确认解质押'}
              </button>
            </div>
          )}

          {/* 第七行：分割线 */}
          <div className={styles.divider}></div>

          {/* 第八行：待领取奖励 */}
          <div className={styles.rewardsSection}>
            <div className={styles.pendingRewards}>
              待领取奖励: {formatDisplayValue(stakerData?.claimingReward)} TOKEN
            </div>
          </div>

          {/* 第九行：领取奖励按钮 */}
          <button
            className={styles.claimButton}
            onClick={handleClaimRewards}
            disabled={!isConnected || isLoading || !stakerData || stakerData.claimingReward === BigInt(0)}
          >
            {isLoading ? '处理中...' : '领取奖励'}
          </button>

          {/* 取款按钮 */}
          {stakerData && stakerData.unstakeRequest && stakerData.unstakeRequest.length > 0 && (
            <div style={{ marginTop: '1rem' }}>
              <button
                className={styles.unstakeButton}
                onClick={() => {
                  writeContract({
                    address: DUGGEE_STAKE_ADDRESS as `0x${string}`,
                    abi: STAKE_CONTRACT_ABI,
                    functionName: 'withdraw',
                    args: [ETH_TOKEN_ADDRESS],
                  });
                }}
                disabled={!isConnected || isLoading}
                style={{ width: '100%' }}
              >
                {isLoading ? '处理中...' : '取款'}
              </button>
              <div style={{ fontSize: '0.8rem', color: '#666', marginTop: '0.5rem', textAlign: 'center' }}>
                {stakerData.unstakeRequest.filter((req: any) => !req.finished).length} 笔解质押待取款
              </div>
            </div>
          )}

          {!isConnected && (
            <div style={{ textAlign: 'center', marginTop: '2rem', color: '#666' }}>
              请连接钱包以使用质押功能
            </div>
          )}
        </div>
      </main>

      <footer className={styles.footer}>
        <a href="https://rainbow.me" rel="noopener noreferrer" target="_blank">
          Made with ❤️ by your frens at 🌈
        </a>
      </footer>
    </div>
  );
};

export default Home;
