// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VestingWallet {
    using SafeERC20 for IERC20;

    address public immutable beneficiary;
    IERC20 public immutable token;
    uint64 public immutable start;
    uint64 public immutable cliffDuration;
    uint64 public immutable vestingDuration;
    uint256 public released;

    event Released(address indexed beneficiary, uint256 amount);

    constructor(
        address beneficiary_,
        IERC20 token_,
        uint64 start_,
        uint64 cliffDuration_,
        uint64 vestingDuration_
    ) {
        require(beneficiary_ != address(0), "VestingWallet: zero beneficiary");
        require(vestingDuration_ > 0, "VestingWallet: zero duration");
        require(cliffDuration_ <= vestingDuration_, "VestingWallet: cliff exceeds duration");

        beneficiary = beneficiary_;
        token = token_;
        start = start_;
        cliffDuration = cliffDuration_;
        vestingDuration = vestingDuration_;
    }

    function totalAllocation() public view returns (uint256) {
        return token.balanceOf(address(this)) + released;
    }

    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        uint256 allocation = totalAllocation();
        if (allocation == 0) {
            return 0;
        }

        if (timestamp < start) {
            return 0;
        }

        if (timestamp < start + cliffDuration) {
            return 0;
        }

        if (timestamp >= start + vestingDuration) {
            return allocation;
        }

        return (allocation * (timestamp - start)) / vestingDuration;
    }

    function releasable() public view returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released;
    }

    function release() external {
        uint256 amount = releasable();
        require(amount > 0, "VestingWallet: nothing to release");

        released += amount;
        token.safeTransfer(beneficiary, amount);

        emit Released(beneficiary, amount);
    }
}
