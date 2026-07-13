// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {VestingWallet} from "../src/VestingWallet.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address beneficiary = vm.envAddress("BENEFICIARY");
        uint64 start = uint64(vm.envUint("VESTING_START"));
        uint64 cliffDuration = uint64(vm.envUint("CLIFF_DURATION"));
        uint64 vestingDuration = uint64(vm.envUint("VESTING_DURATION"));
        uint256 mintAmount = vm.envUint("MINT_AMOUNT");

        bool deployMock = vm.envOr("DEPLOY_MOCK_TOKEN", true);

        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        IERC20 token;
        if (deployMock) {
            MockERC20 mock = new MockERC20("Vest Token", "VEST");
            mock.mint(deployer, mintAmount);
            token = IERC20(address(mock));
            console2.log("MockERC20:", address(mock));
        } else {
            token = IERC20(vm.envAddress("TOKEN_ADDRESS"));
        }

        VestingWallet wallet = new VestingWallet(
            beneficiary,
            token,
            start,
            cliffDuration,
            vestingDuration
        );

        if (deployMock) {
            MockERC20(address(token)).transfer(address(wallet), mintAmount);
        }

        vm.stopBroadcast();

        console2.log("VestingWallet:", address(wallet));
        console2.log("Beneficiary:", beneficiary);
        console2.log("Start:", start);
        console2.log("Cliff (s):", cliffDuration);
        console2.log("Duration (s):", vestingDuration);
        console2.log("Allocation:", token.balanceOf(address(wallet)));
    }
}
