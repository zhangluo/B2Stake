// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// import "../lib/openzeppelin/contracts/access/Ownable.sol";
// import "../lib/openzeppelin/contracts/token/ERC20/IERC20.sol";

// import "../lib/openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "../lib/openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "../lib/openzeppelin/contracts/utils/Address.sol";
// import "../lib/openzeppelin/contracts/utils/math/Math.sol";

// import "../lib/openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "../lib/openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "../lib/openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// import "../lib/openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";



import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract B2Stake is 
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable {

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    uint256 public constant BTC_PID = 0;

    // 数据结构
    struct Pool {
        address stTokenAddress;
        uint256 poolWeight;
        uint256 lastRewardBlock;
        uint256 accB2PerST;
        uint256 stTokenAmount;
        uint256 minDepositAmount;
        uint256 unstakeLockedBlocks;
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
 

    uint256 public startBlock;
    uint256 public endBlock;

    uint256 public b2PerBlock;
    bool public claimPaused;

    // B2 token
    IERC20 public B2;

    // 事件
    event SetB2(IERC20 indexed B2);
    event SetStartBlock(uint256 startBlock);
    event SetEndBlock(uint256 endBlock);
    event SetB2PerBlock(uint256 b2PerBlock);
    event Staked(address indexed user, uint256 pid, uint256 amount);
    event Unstaked(address indexed user, uint256 pid, uint256 amount);
    event RewardClaimed(address indexed user, uint256 pid, uint256 amount);
    event PoolAdded(uint256 pid, address stTokenAddress, uint256 poolWeight, uint256 minDepositAmount, uint256 unstakeLockedBlocks, uint256 rewardPerBlock);
    event PoolUpdated(uint256 pid, address stTokenAddress, uint256 poolWeight, uint256 minDepositAmount, uint256 unstakeLockedBlocks, uint256 rewardPerBlock);
    event UpgraderAuthorized(address indexed upgrader);
    event UpgraderRevoked(address indexed upgrader);
    event Paused();
    event Unpaused();


    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim is paused");
        _;
    }

    function initialize(
        IERC20 _B2,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _b2PerBlock
    ) public initializer {
        require(_startBlock <= _endBlock && _b2PerBlock > 0, "invalid parameters");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        setB2(_B2);

        startBlock = _startBlock;
        endBlock = _endBlock;
        b2PerBlock = _b2PerBlock;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADE_ROLE)
        override
    {

    }

    function setB2(IERC20 _B2) public onlyRole(ADMIN_ROLE) {
        B2 = _B2;

        emit SetB2(B2);
    }
    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        require(_startBlock <= endBlock, "start block must be smaller than end block");

        startBlock = _startBlock;

        emit SetStartBlock(_startBlock);
    }

    /**
     * @notice Update staking end block. Can only be called by admin.
     */
    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(startBlock <= _endBlock, "start block must be smaller than end block");

        endBlock = _endBlock;

        emit SetEndBlock(_endBlock);
    }

    /**
     * @notice Update the B2 reward amount per block. Can only be called by admin.
     */
    function setB2PerBlock(uint256 _b2PerBlock) public onlyRole(ADMIN_ROLE) {
        require(_b2PerBlock > 0, "invalid parameter");

        b2PerBlock = _b2PerBlock;

        emit SetB2PerBlock(_b2PerBlock);
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

        if (pool.lastRewardBlock == 0) {
            uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
            pool.lastRewardBlock = lastRewardBlock;
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

        IERC20(pool.stTokenAddress).transfer(msg.sender, _amount);
        user.stAmount -= _amount;
        pool.stTokenAmount -= _amount;

        uint256 pendingB2_ = user.stAmount * pool.accB2PerST / (1 ether) - user.finishedB2;

        if(pendingB2_ > 0) {
            user.pendingB2 = user.pendingB2 + pendingB2_;
        }

        pool.stTokenAmount = pool.stTokenAmount - _amount;
        user.finishedB2 = user.stAmount * pool.accB2PerST / (1 ether);

        emit Unstaked(msg.sender, _pid, _amount);
    }

    // 解除质押
    function withdraw(uint256 _pid) external whenNotPaused {
        Pool storage pool = pools[_pid];
        User storage user = users[msg.sender][_pid];

        require(user.requests.length > 0, "No unstake request");

        for(uint256 i = 0; i < user.requests.length; i++) {
            if(user.requests[i].unlockBlock <= block.number) {
                IERC20(pool.stTokenAddress).transfer(msg.sender, user.requests[i].amount);
                user.stAmount -= user.requests[i].amount;
                pool.stTokenAmount -= user.requests[i].amount;
                user.requests[i] = user.requests[user.requests.length - 1];
                user.requests.pop();
            }
        }

    }
    // 领取奖励
    function claimReward(uint256 _pid) external whenNotPaused {
        User storage user = users[msg.sender][_pid];
        uint256 reward = calculateReward(_pid, msg.sender);

        require(reward > 0, "No reward to claim");

        user.pendingB2 = 0;
        user.finishedB2 += reward;
        B2.transfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, _pid, reward);
    }

    // 授权升级者
    function authorizeUpgrader(address _upgrader) external onlyRole(ADMIN_ROLE) {
        authorizedUpgraders[_upgrader] = true;
        emit UpgraderAuthorized(_upgrader);
    }

    // 暂停合约
    function pause() external onlyRole(ADMIN_ROLE) {
        claimPaused = true;
        emit Paused();
    }

    // 恢复合约
    function unpause() external onlyRole(ADMIN_ROLE) {
        claimPaused = false;
        emit Unpaused();
    }

    // 更新池的奖励状态
    function _updatePool(uint256 _pid) internal {
        Pool storage pool = pools[_pid];
        uint256 rewardBlock = block.number;
        if (rewardBlock <= pool.lastRewardBlock) {
            return;
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
       
        uint256 totalReward = user.stAmount * pool.accB2PerST / (1 ether);
        
        // 计算用户的奖励
        uint256 userReward = totalReward - user.finishedB2;
       
        return userReward;
    }
}
