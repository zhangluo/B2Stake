// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../lib/openzeppelin/contracts/access/Ownable.sol";
import "../lib/openzeppelin/contracts/token/ERC20/IERC20.sol";


contract B2Stake is Ownable {
    // 数据结构
    struct Pool {
        address stTokenAddress;
        uint256 poolWeight;
        uint256 lastRewardBlock;
        uint256 accB2PerST;
        uint256 stTokenAmount;
        uint256 minDepositAmount;
        uint256 unstakeLockedBlocks;
        uint256 rewardPerBlock; // 每个区块的奖励
    }

    struct User {
        uint256 stAmount;
        uint256 finishedB2;
        uint256 pendingB2;
        UnstakeRequest[] requests;
    }

    struct UnstakeRequest {
        uint256 amount;
        uint256 unlockBlock;
    }

    // 状态变量
    mapping(uint256 => Pool) public pools;
    mapping(address => mapping(uint256 => User)) public users;
    mapping(address => bool) public authorizedUpgraders;
    bool public paused = false;
    address public b2TokenAddress; // 奖励代币的地址

    // 事件
    event Staked(address indexed user, uint256 pid, uint256 amount);
    event Unstaked(address indexed user, uint256 pid, uint256 amount);
    event RewardClaimed(address indexed user, uint256 pid, uint256 amount);
    event PoolAdded(uint256 pid, address stTokenAddress, uint256 poolWeight, uint256 minDepositAmount, uint256 unstakeLockedBlocks, uint256 rewardPerBlock);
    event PoolUpdated(uint256 pid, address stTokenAddress, uint256 poolWeight, uint256 minDepositAmount, uint256 unstakeLockedBlocks, uint256 rewardPerBlock);
    event UpgraderAuthorized(address indexed upgrader);
    event UpgraderRevoked(address indexed upgrader);
    event Paused();
    event Unpaused();

    constructor(address _b2TokenAddress) Ownable(_b2TokenAddress) {
        b2TokenAddress = _b2TokenAddress;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    // 添加质押池
    function addPool(
        uint256 _pid,
        address _stTokenAddress,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks,
        uint256 _rewardPerBlock
    ) external { //onlyOwner {
        Pool storage pool = pools[_pid];
        pool.stTokenAddress = _stTokenAddress;
        pool.poolWeight = _poolWeight;
        pool.minDepositAmount = _minDepositAmount;
        pool.unstakeLockedBlocks = _unstakeLockedBlocks;
        pool.rewardPerBlock = _rewardPerBlock;

        if (pool.lastRewardBlock == 0) {
            pool.lastRewardBlock = block.number;
            emit PoolAdded(_pid, _stTokenAddress, _poolWeight, _minDepositAmount, _unstakeLockedBlocks, _rewardPerBlock);
        } else {
            emit PoolUpdated(_pid, _stTokenAddress, _poolWeight, _minDepositAmount, _unstakeLockedBlocks, _rewardPerBlock);
        }
    }

    // 质押
    function stake(uint256 _pid, uint256 _amount) external whenNotPaused {
        Pool storage pool = pools[_pid];
        User storage user = users[msg.sender][_pid];
        require(_amount >= pool.minDepositAmount, "Amount below minimum deposit");

        _updatePool(_pid);
        IERC20(pool.stTokenAddress).transferFrom(msg.sender, address(this), _amount);

        user.stAmount += _amount;
        pool.stTokenAmount += _amount;

        emit Staked(msg.sender, _pid, _amount);
    }

    // 解除质押
    function unstake(uint256 _pid, uint256 _amount) external whenNotPaused {
        Pool storage pool = pools[_pid];
        User storage user = users[msg.sender][_pid];
        require(_amount <= user.stAmount, "Amount exceeds staked amount");

        _updatePool(_pid);

        uint256 unlockBlock = block.number + pool.unstakeLockedBlocks;
        user.requests.push(UnstakeRequest({
            amount: _amount,
            unlockBlock: unlockBlock
        }));

        user.stAmount -= _amount;
        pool.stTokenAmount -= _amount;

        emit Unstaked(msg.sender, _pid, _amount);
    }

    // 领取奖励
    function claimReward(uint256 _pid) external whenNotPaused {
        User storage user = users[msg.sender][_pid];
        uint256 reward = calculateReward(_pid, msg.sender);

        require(reward > 0, "No reward to claim");

        user.pendingB2 = 0;
        IERC20(b2TokenAddress).transfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, _pid, reward);
    }

    // 授权升级者
    function authorizeUpgrader(address _upgrader) external onlyOwner {
        authorizedUpgraders[_upgrader] = true;
        emit UpgraderAuthorized(_upgrader);
    }

    // 撤销升级者权限
    function revokeUpgrader(address _upgrader) external onlyOwner {
        authorizedUpgraders[_upgrader] = false;
        emit UpgraderRevoked(_upgrader);
    }

    // 升级合约（示例，实际实现可能不同）
    function upgradeContract(address newContract) external {
        require(authorizedUpgraders[msg.sender], "Not authorized to upgrade");
        // Implementation of contract upgrade logic
    }

    // 暂停合约
    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    // 恢复合约
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    // 更新池的奖励状态
    function _updatePool(uint256 _pid) internal {
        Pool storage pool = pools[_pid];
        uint256 rewardBlock = block.number;
        if (rewardBlock <= pool.lastRewardBlock) {
            return;
        }

        uint256 multiplier = rewardBlock - pool.lastRewardBlock;

        if (pool.stTokenAmount > 0) {
            uint256 totalReward = multiplier * pool.rewardPerBlock * pool.poolWeight / pool.stTokenAmount;
            pool.accB2PerST += totalReward;
        }

        pool.lastRewardBlock = rewardBlock;
    }

    // 计算奖励
    function calculateReward(uint256 _pid, address _user) public view returns (uint256) {
        Pool storage pool = pools[_pid];
        User storage user = users[_user][_pid];

        // 计算奖励时间间隔
        uint256 rewardBlock = block.number;
        if (rewardBlock <= pool.lastRewardBlock) {
            return 0;
        }
        uint256 multiplier = rewardBlock - pool.lastRewardBlock;

        // 计算总奖励
        uint256 totalReward = multiplier * pool.rewardPerBlock * pool.poolWeight / pool.stTokenAmount;

        // 计算用户的奖励
        uint256 userReward = user.stAmount * totalReward / pool.stTokenAmount;

        return userReward;
    }
}
