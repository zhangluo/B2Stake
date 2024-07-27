// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../src/B2Stake.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract B2StakeTest is Test {
    B2Stake private b2Stake;
    MockERC20 private b2Token;
    MockERC20 private stakingToken;

    address private admin;
    address private user1;
    address private user2;

    function setUp() public {
    admin = address(0x1);
    user1 = address(0x2);
    user2 = address(0x3);

    // Deploy contracts
    b2Token = new MockERC20("B2 Token", "B2");
    stakingToken = new MockERC20("Staking Token", "STK");

    // Deploy B2Stake contract
    b2Stake = new B2Stake();

    // Mint tokens for users and B2Stake contract
    b2Token.mint(admin, 100000);  // Increased balance for admin
    stakingToken.mint(user1, 100000);  // Increased balance for user1
    stakingToken.mint(user2, 100000);  // Increased balance for user2
    b2Token.mint(address(b2Stake), 100000);  // Increased balance for B2Stake contract

    // Initialize the B2Stake contract
    b2Stake.initialize(b2Token, 0, 10000, 10);

    // Authorize the admin
    b2Stake.grantRole(b2Stake.ADMIN_ROLE(), admin);

    // Debugging: Verify token balances and addresses
    address b2StakeAddress = address(b2Stake);
    uint256 adminBalance = b2Token.balanceOf(admin);
    uint256 user1Balance = stakingToken.balanceOf(user1);
    uint256 user2Balance = stakingToken.balanceOf(user2);
    uint256 b2StakeBalance = b2Token.balanceOf(b2StakeAddress);

    console.log("B2Stake Contract Address:", b2StakeAddress);
    console.log("Admin B2 Token Balance:", adminBalance);
    console.log("User1 STK Token Balance:", user1Balance);
    console.log("User2 STK Token Balance:", user2Balance);
    console.log("B2Stake Contract B2 Token Balance:", b2StakeBalance);

    // Check addresses and balances
    require(b2StakeAddress != address(0), "B2Stake contract address is zero");
    require(adminBalance >= 100000, "Admin does not have enough B2 tokens");
    require(user1Balance >= 100000, "User1 does not have enough STK tokens");
    require(user2Balance >= 100000, "User2 does not have enough STK tokens");
    require(b2StakeBalance >= 100000, "B2Stake contract does not have enough B2 tokens");
}



    function testAddPool() public {
        uint256 pid = 1;
        uint256 poolWeight = 1;
        uint256 minDepositAmount = 10;
        uint256 unstakeLockedBlocks = 10;
        uint256 rewardPerBlock = 1;

        // Add the pool
        b2Stake.addPool(pid, address(stakingToken), poolWeight, minDepositAmount, unstakeLockedBlocks, rewardPerBlock);

        // Verify pool was added correctly
        (address stTokenAddress, uint256 poolWeightStored, uint256 lastRewardBlock, uint256 accB2PerST, uint256 stTokenAmount, uint256 minDepositAmountStored, uint256 unstakeLockedBlocksStored) = b2Stake.pools(pid);
        assertEq(stTokenAddress, address(stakingToken));
        assertEq(poolWeightStored, poolWeight);
        assertEq(minDepositAmountStored, minDepositAmount);
        assertEq(unstakeLockedBlocksStored, unstakeLockedBlocks);
    }

    function testStake() public {
    uint256 amount = 50;

    // Ensure users have enough tokens
    require(stakingToken.balanceOf(user1) >= amount, "User1 does not have enough tokens");

    // Stake tokens
    stakingToken.approve(address(b2Stake), amount);
    b2Stake.stake(1, amount);

    // Check updated balances and states
    uint256 userBalanceAfterStake = stakingToken.balanceOf(user1);
    // uint256 poolBalance = b2Stake.pools(1).stTokenAmount;

    assertEq(userBalanceAfterStake, 100000 - amount);
    // assertEq(poolBalance, amount);
}

function testUnstake() public {
    uint256 amount = 50;

    // Stake tokens first
    testStake();

    // Unstake tokens
    b2Stake.unstake(1, amount);

    // Check updated balances and states
    uint256 userBalanceAfterUnstake = stakingToken.balanceOf(user1);
    // uint256 poolBalanceAfterUnstake = b2Stake.pools(1).stTokenAmount;

    assertEq(userBalanceAfterUnstake, 100000);
    // assertEq(poolBalanceAfterUnstake, 0);
}

function testClaimReward() public {
    // Assuming rewards have been accrued
    uint256 rewardAmount = 50;

    // Claim rewards
    b2Stake.claimReward(1);

    // Check updated balances
    uint256 userB2Balance = b2Token.balanceOf(user1);
    uint256 b2StakeBalanceAfterClaim = b2Token.balanceOf(address(b2Stake));

    assertEq(userB2Balance, rewardAmount);
    assertEq(b2StakeBalanceAfterClaim, 100000 - rewardAmount);
}


    function testPauseUnpause() public {
        // Pause the contract
        b2Stake.pause();
        bool paused = b2Stake.claimPaused();
        assertTrue(paused);

        // Unpause the contract
        b2Stake.unpause();
        paused = b2Stake.claimPaused();
        assertFalse(paused);
    }
}
