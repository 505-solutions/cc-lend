// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {MockPriceOracle} from "../test/mocks/MockPriceOracle.sol";
import {MockInterestRateModel} from "../test/mocks/MockInterestRateModel.sol";
import {MockFtsoRegistry} from "../test/mocks/MockFtsoRegistry.sol";

import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMockOracle is Script {
    function run() external returns (MockPriceOracle) {
        HelperConfig helperConfig = new HelperConfig();
        (,,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        MockPriceOracle oracle = new MockPriceOracle();
        vm.stopBroadcast();

        return (oracle);
    }
}

contract DeployMockIRM is Script {
    function run() external returns (MockInterestRateModel) {
        HelperConfig helperConfig = new HelperConfig();
        (,,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        MockInterestRateModel irm = new MockInterestRateModel();
        vm.stopBroadcast();

        return (irm);
    }
}

contract DeployMockFtsoRegistry is Script {
    function run() external returns (MockFtsoRegistry) {
        HelperConfig helperConfig = new HelperConfig();
        (,,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        MockFtsoRegistry oracle = new MockFtsoRegistry();
        vm.stopBroadcast();

        return (oracle);
    }
}
