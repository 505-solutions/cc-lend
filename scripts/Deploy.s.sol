// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {LendingPool} from "../src/LendingPool.sol";
import {MessageRelay} from "../src/MessageRelay.sol";

import {MockPriceOracle} from "../test/mocks/MockPriceOracle.sol";
// import {ILendingPool} from "../src/Interfaces/ILendingPool.sol";

import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployPoolScript is Script {
    function run() external returns (LendingPool) {
        address owner = address(0xaCEdF8742eDC7d923e1e6462852cCE136ee9Fb56);

        HelperConfig helperConfig = new HelperConfig();
        (,,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        LendingPool pool = new LendingPool(owner, owner);

        vm.stopBroadcast();

        return (pool);
    }
}

contract DeployRelayScript is Script {
    function run() external returns (MessageRelay) {
        address owner = address(0xaCEdF8742eDC7d923e1e6462852cCE136ee9Fb56);

        HelperConfig helperConfig = new HelperConfig();
        (,,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        MessageRelay relay = new MessageRelay(owner);

        vm.stopBroadcast();

        return (relay);
    }
}

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

        LendingPool pool = LendingPool(lendingPool);

        vm.startBroadcast(deployerKey);

        pool.setOracle(priceOracle);

        pool.configureAsset(weth, 0.5e18, 0);
        pool.setInterestRateModel(weth, interesRateModel);

        pool.configureAsset(usdc, 0.5e18, 0);
        pool.setInterestRateModel(usdc, interesRateModel);

        MockPriceOracle(priceOracle).updatePrice(weth, 1e18);
        MockPriceOracle(priceOracle).updatePrice(usdc, 0.0003e18);

        vm.stopBroadcast();

        return (pool);
    }
}
