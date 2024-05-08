// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {LendingPool} from "../src/LendingPool.sol";
import {MessageRelay} from "../src/MessageRelay.sol";

import {MainStorage} from "../src/utils/MainStorage.sol";

import {MockPriceOracle} from "../test/mocks/MockPriceOracle.sol";
// import {ILendingPool} from "../src/Interfaces/ILendingPool.sol";

import {HelperConfig} from "./HelperConfig.s.sol";

contract ConfigurePoolScript is Script {
    function run() external returns (LendingPool) {
        HelperConfig helperConfig = new HelperConfig();

        (
            address lendingPool,
            address messageRelay,
            address priceOracle,
            address interesRateModel,
            address weth,
            address usdc,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        (address counterWeth, address counterUsdc) = helperConfig.activeCounterAssets();

        LendingPool pool = LendingPool(lendingPool);

        vm.startBroadcast(deployerKey);

        pool.setOracle(priceOracle);

        pool.configureAsset(weth, counterWeth, 0.9e18, 0.9e18);
        pool.setInterestRateModel(weth, interesRateModel);

        pool.configureAsset(usdc, counterUsdc, 0.9e18, 0.9e18);
        pool.setInterestRateModel(usdc, interesRateModel);

        MockPriceOracle(priceOracle).updatePrice(weth, 1e18);
        MockPriceOracle(priceOracle).updatePrice(usdc, 0.0003e18);

        vm.stopBroadcast();

        return (pool);
    }
}

contract UpdateConfigurationPoolScript is Script {
    function run() external returns (LendingPool) {
        HelperConfig helperConfig = new HelperConfig();

        (address lendingPool,,,, address weth, address usdc, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        LendingPool pool = LendingPool(lendingPool);

        vm.startBroadcast(deployerKey);

        MainStorage.Configuration memory newConfiguration = MainStorage.Configuration(0.9e18, 0.9e18);

        pool.updateConfiguration(weth, newConfiguration);

        pool.updateConfiguration(usdc, newConfiguration);

        vm.stopBroadcast();

        return (pool);
    }
}

contract ConfigureRelayScript is Script {
    function run() external returns (LendingPool) {
        HelperConfig helperConfig = new HelperConfig();

        (address lendingPool, address messageRelay,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        address evmTxVerifier = helperConfig.getEvmTxVerifier();

        LendingPool pool = LendingPool(lendingPool);
        MessageRelay relay = MessageRelay(messageRelay);

        vm.startBroadcast(deployerKey);

        pool.setMessageRelay(messageRelay);

        relay.setLendingPool(lendingPool);
        relay.setEVMTxVerifier(evmTxVerifier);

        vm.stopBroadcast();

        return (pool);
    }
}
