// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {MockPriceOracle} from "../test/mocks/MockPriceOracle.sol";
import {MockInterestRateModel} from "../test/mocks/MockInterestRateModel.sol";
import {PriceOraclePlugin} from "src/PriceOraclePlugin.sol";

import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMockOracle is Script {
    function run() external returns (MockPriceOracle) {
        vm.startBroadcast();
        MockPriceOracle oracle = new MockPriceOracle();
        vm.stopBroadcast();

        return (oracle);
    }
}

contract DeployMockIRM is Script {
    function run() external returns (MockInterestRateModel) {
        vm.startBroadcast();
        MockInterestRateModel irm = new MockInterestRateModel();
        vm.stopBroadcast();

        return (irm);
    }
}

contract DeployMockPOP is Script {
    uint256 constant WETH_FTSO_IDX = 10;

    function run() external returns (PriceOraclePlugin) {
        HelperConfig helperConfig = new HelperConfig();
        (,,,,, address wethAddress,,) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        PriceOraclePlugin pop = new PriceOraclePlugin(wethAddress, WETH_FTSO_IDX);
        vm.stopBroadcast();

        return (pop);
    }
}
