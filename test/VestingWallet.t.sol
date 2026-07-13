// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {VestingWallet} from "../src/VestingWallet.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VestingWalletTest is Test {
    VestingWallet internal vesting;
    MockERC20 internal token;

    address internal beneficiary = makeAddr("beneficiary");
    address internal funder = makeAddr("funder");

    uint64 internal constant START = 1_700_000_000;
    uint64 internal constant CLIFF = 90 days;
    uint64 internal constant DURATION = 365 days;
    uint256 internal constant TOTAL = 1_000_000 ether;

    function setUp() public {
        token = new MockERC20("Vest Token", "VEST");
        token.mint(funder, TOTAL);

        vesting = new VestingWallet(
            beneficiary,
            IERC20(address(token)),
            START,
            CLIFF,
            DURATION
        );

        vm.prank(funder);
        token.transfer(address(vesting), TOTAL);

        vm.warp(START);
    }

    function test_BeforeCliff_NothingVested() public view {
        assertEq(vesting.vestedAmount(START + CLIFF - 1), 0);
    }

    function test_ReleaseBeforeCliff_Reverts() public {
        vm.warp(START + CLIFF - 1);
        vm.expectRevert("VestingWallet: nothing to release");
        vesting.release();
    }

    function test_AtCliff_PartialVested() public view {
        uint64 atCliff = START + CLIFF;
        uint256 expected = (TOTAL * CLIFF) / DURATION;
        assertEq(vesting.vestedAmount(atCliff), expected);
    }

    function test_LinearVesting_Midpoint() public view {
        uint64 midpoint = START + DURATION / 2;
        assertEq(vesting.vestedAmount(midpoint), TOTAL / 2);
    }

    function test_FullVest() public {
        vm.warp(START + DURATION);
        assertEq(vesting.vestedAmount(uint64(block.timestamp)), TOTAL);
        assertEq(vesting.releasable(), TOTAL);

        vesting.release();

        assertEq(token.balanceOf(beneficiary), TOTAL);
        assertEq(vesting.released(), TOTAL);
        assertEq(vesting.releasable(), 0);
    }

    function test_ReleaseUpdatesState() public {
        vm.warp(START + DURATION);

        vesting.release();
        assertEq(vesting.released(), TOTAL);

        vm.expectRevert("VestingWallet: nothing to release");
        vesting.release();
    }

    function test_PartialReleaseThenMore() public {
        vm.warp(START + DURATION / 2);

        uint256 first = vesting.releasable();
        vesting.release();
        assertEq(vesting.released(), first);
        assertEq(token.balanceOf(beneficiary), first);

        vm.warp(START + DURATION);
        uint256 second = vesting.releasable();
        assertEq(second, TOTAL - first);

        vesting.release();
        assertEq(token.balanceOf(beneficiary), TOTAL);
        assertEq(vesting.released(), TOTAL);
    }

    function test_AnyoneCanCallRelease() public {
        vm.warp(START + DURATION);

        address stranger = makeAddr("stranger");
        vm.prank(stranger);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), TOTAL);
    }

    function test_RevertZeroBeneficiary() public {
        vm.expectRevert("VestingWallet: zero beneficiary");
        new VestingWallet(address(0), IERC20(address(token)), START, CLIFF, DURATION);
    }

    function test_RevertZeroDuration() public {
        vm.expectRevert("VestingWallet: zero duration");
        new VestingWallet(beneficiary, IERC20(address(token)), START, CLIFF, 0);
    }

    function test_RevertCliffExceedsDuration() public {
        vm.expectRevert("VestingWallet: cliff exceeds duration");
        new VestingWallet(beneficiary, IERC20(address(token)), START, DURATION + 1, DURATION);
    }

    function testFuzz_VestedAmountMonotonic(uint64 t1, uint64 t2) public view {
        t1 = uint64(bound(t1, START, START + DURATION));
        t2 = uint64(bound(t2, START, START + DURATION));

        if (t1 > t2) (t1, t2) = (t2, t1);

        assertLe(vesting.vestedAmount(t1), vesting.vestedAmount(t2));
        assertLe(vesting.vestedAmount(t2), TOTAL);
    }

    function testFuzz_VestedAmountBounds(uint64 timestamp) public view {
        if (timestamp < START + CLIFF) {
            assertEq(vesting.vestedAmount(timestamp), 0);
        } else if (timestamp >= START + DURATION) {
            assertEq(vesting.vestedAmount(timestamp), TOTAL);
        } else {
            uint256 vested = vesting.vestedAmount(timestamp);
            assertGt(vested, 0);
            assertLt(vested, TOTAL);
        }
    }
}
