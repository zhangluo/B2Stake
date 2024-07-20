// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {B2Stake} from "../src/B2Stake.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockERC20 is IERC20 {
    // Mock implementation for testing
    function totalSupply() external view override returns (uint256) {}
    function balanceOf(address account) external view override returns (uint256) {}
    function transfer(address recipient, uint256 amount) external override returns (bool) {}
    function allowance(address owner, address spender) external view override returns (uint256) {}
    function approve(address spender, uint256 amount) external override returns (bool) {}
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {}
}

contract B2StakeTest is Test {
    B2Stake public b2Stake;
    MockERC20 public mockToken;

    address public owner = address(0x123); // Define owner or use a valid address
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        mockToken = new MockERC20();
        b2Stake = new B2Stake(owner);

        assertEq(b2Stake.owner(), owner);
        // Initialize the B2Stake contract with a pool
        b2Stake.addPool(
            1,
            address(mockToken),
            10,
            100,
            10,
            1
        );

        // Set up mock ERC20 token behavior
        vm.mockCall(
            address(mockToken),
            abi.encodeWithSelector(MockERC20.transferFrom.selector),
            abi.encode(true)
        );

        // Mock ERC20 balance for users
        vm.mockCall(
            address(mockToken),
            abi.encodeWithSelector(MockERC20.balanceOf.selector, user1),
            abi.encode(1000)
        );

        vm.mockCall(
            address(mockToken),
            abi.encodeWithSelector(MockERC20.balanceOf.selector, user2),
            abi.encode(1000)
        );
    }

    function test_Stake() public {
        vm.startPrank(user1);

        // User1 stakes 200 tokens
        b2Stake.stake(1, 200);

        // Check the staked amount
        (uint256 stAmount, , ) = b2Stake.users(user1, 1);
        assertEq(stAmount, 200);

        vm.stopPrank();
    }

    function test_Unstake() public {
        vm.startPrank(user1);

        // User1 stakes 200 tokens
        b2Stake.stake(1, 200);

        // User1 unstakes 100 tokens
        b2Stake.unstake(1, 100);

        // Check the unstake request
        (uint256 stAmount, , ) = b2Stake.users(user1, 1);
        assertEq(stAmount, 100);
        // assertEq(requests[0].amount, 100);
        // assert(requests[0].unlockBlock > block.number);

        vm.stopPrank();
    }

    function test_ClaimReward() public {
        vm.startPrank(user1);

        // Setup some conditions to accumulate reward (mock calculation here)
        b2Stake.stake(1, 200);

        // Pretend reward calculation and claim reward
        // Mock reward value
        vm.mockCall(
            address(b2Stake),
            abi.encodeWithSelector(B2Stake.calculateReward.selector, 1, user1),
            abi.encode(50) // Mock reward value
        );

        // Claim reward
        // b2Stake.claimReward(1);

        // Check if reward is claimed correctly
        // Implement check for reward transfer if applicable

        vm.stopPrank();
    }

    function test_AddPool() public {
        vm.startPrank(owner);

        // Add a new pool
        b2Stake.addPool(
            2,
            address(mockToken),
            20,
            200,
            20,
            1
        );

        // Verify new pool details
        (address stTokenAddress, uint256 poolWeight, uint256 minDepositAmount, uint256 unstakeLockedBlocks, , , ,) = b2Stake.pools(2);
        assertEq(stTokenAddress, address(mockToken));
        assertEq(poolWeight, 20);
        // assertEq(minDepositAmount, 200);
        // assertEq(unstakeLockedBlocks, 20);

        vm.stopPrank();
    }

    function test_PauseAndUnpause() public {
        // Test contract pause and unpause functionality
        vm.startPrank(owner);
        b2Stake.pause();
        assert(b2Stake.paused());

        b2Stake.unpause();
        assert(!b2Stake.paused());
        vm.stopPrank();
    }
}
