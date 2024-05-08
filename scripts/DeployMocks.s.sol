// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {MockPriceOracle} from "../test/mocks/MockPriceOracle.sol";
import {MockInterestRateModel} from "../test/mocks/MockInterestRateModel.sol";

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
