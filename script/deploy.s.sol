// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/B2Stake.sol";

contract Deploy {
    address public deployedAddress;

    function deploy() public {
        B2Stake b2Stake = new B2Stake();
        deployedAddress = address(b2Stake);
    }
}
