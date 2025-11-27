
```
## 执行部署脚本

forge script script/DuggeeStake.s.sol:DuggeeStakeScript --fork-url http://localhost:8545 --broadcast --interactives 1

## token合约地址 0x5FbDB2315678afecb367f032d93F642f64180aa3
## stake合约地址
0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

## 创建池子
forge script script/CreatePool.s.sol:CreatePoolScript --fork-url http://localhost:8545 --broadcast --interactives 1


## Mint Token
forge script script/Mint.s.sol:MintScript --fork-url http://localhost:8545 --broadcast --interactives 1
```