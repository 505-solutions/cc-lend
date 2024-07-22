// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import {LendingPool} from "src/LendingPool.sol";

// // TODO: I should not have to import ERC20 from here.
// import {ERC20} from "solmate/utils/SafeTransferLib.sol";

import {PriceOracle} from "src/Interfaces/IPriceOracle.sol";
import {InterestRateModel} from "src/Interfaces/IIRM.sol";

import {PriceOraclePlugin} from "src/PriceOraclePlugin.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceOracle} from "./mocks/MockPriceOracle.sol";
import {MockFtsoRegistry} from "./mocks/MockFtsoRegistry.sol";
import {MockInterestRateModel} from "./mocks/MockInterestRateModel.sol";
// import {MockLiquidator} from "./mocks/MockLiquidator.sol";

import {LendingPool} from "src/LendingPool.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/// @title Configuration Test Contract
contract ConfigurationTest is Test {
    using FixedPointMathLib for uint256;

    /* Lending Pool Contracts */
    LendingPool pool;

    /* Mocks */
    MockERC20 asset;
    MockERC20 borrowAsset;

    MockPriceOracle oracle;
    MockFtsoRegistry ftsoRegistry;
    MockInterestRateModel interestRateModel;
    // MockLiquidator liquidator;

    PriceOraclePlugin priceOraclePlugin;

    uint256 constant ETH_FTSO_IDX = 1e18;

    function setUp() public {
        // ! For non upgradable contracts
        // pool = new LendingPool(address(this), address(this));

        // ! For upgradable contracts
        pool = new LendingPool();
        pool.initialize(address(this), address(this));

        interestRateModel = new MockInterestRateModel();

        asset = new MockERC20("Mock Token", "MKT", 18);

        pool.configureAsset(address(asset), address(asset), 0.5e18, 0);
        pool.setInterestRateModel(address(asset), address(interestRateModel));

        borrowAsset = new MockERC20("Mock Token", "MKT", 18);

        pool.configureAsset(address(borrowAsset), address(borrowAsset), 0, 1e18);
        pool.setInterestRateModel(address(borrowAsset), address(interestRateModel));

        // * ORACLE CONFIGURATIONS
        priceOraclePlugin = new PriceOraclePlugin(address(asset), ETH_FTSO_IDX);
        priceOraclePlugin.setOracleSource(address(this));

        pool.setPriceOraclePlugin(address(priceOraclePlugin));

        if (block.chainid != 16) {
            // ! If on Sepolia
            oracle = new MockPriceOracle();
            oracle.updatePrice(address(asset), 1e18);
            priceOraclePlugin.setOracleSource(address(oracle));
        } else {
            // ! If on Flare
            priceOraclePlugin.setFtsoIndex(address(asset), ETH_FTSO_IDX);

            ftsoRegistry = new MockFtsoRegistry();
            ftsoRegistry.updatePrice(ETH_FTSO_IDX, 3000e5, 5);

            priceOraclePlugin.setOracleSource(address(ftsoRegistry));
        }

        // liquidator = new MockLiquidator(pool, PriceOracle(address(oracle)));
    }

    /*///////////////////////////////////////////////////////////////
                        ORACLE CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testOracleConfiguration() public view {
        assertEq(address(pool.priceOraclePlugin()), address(priceOraclePlugin));
    }

    // function testNewOracleConfiguration() public {
    //     MockPriceOracle newOracle = new MockPriceOracle();
    //     newOracle.updatePrice(address(asset), 1e18);
    //     pool.setOracle(PriceOracle(address(newOracle)));

    //     assertEq(address(PriceOracle(pool.oracle())), address(newOracle));
    // }

    /*///////////////////////////////////////////////////////////////
                    ORACLE CONFIGURATION SANITY CHECKS
    //////////////////////////////////////////////////////////////*/

    // function testFailNewOracleConfigurationNotOwner() public {
    //     MockPriceOracle newOracle = new MockPriceOracle();
    //     newOracle.updatePrice(address(asset), 1e18);

    //     vm.startPrank(address(0xBABE));
    //     pool.setOracle(PriceOracle(address(newOracle)));
    // }

    /*///////////////////////////////////////////////////////////////
                        IRM CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testIRMConfiguration() public {
        assertEq(address(pool.interestRateModels(address(asset))), address(interestRateModel));
    }

    // function testNewIRMConfiguration() public {
    //     MockInterestRateModel newInterestRateModel = new MockInterestRateModel();
    //     pool.setInterestRateModel(
    //         address(asset),
    //         InterestRateModel(address(newInterestRateModel))
    //     );

    //     assertEq(
    //         address(pool.interestRateModels(address(asset))),
    //         address(newInterestRateModel)
    //     );
    // }

    /*///////////////////////////////////////////////////////////////
                     IRM CONFIGURATION SANITY CHECKS
    //////////////////////////////////////////////////////////////*/

    // function testFailNewIRMConfigurationNotOwner() public {
    //     MockInterestRateModel newInterestRateModel = new MockInterestRateModel();
    //     vm.startPrank(address(0xBABE));
    //     pool.setInterestRateModel(
    //         address(asset),
    //         InterestRateModel(address(newInterestRateModel))
    //     );
    // }

    /*///////////////////////////////////////////////////////////////
                        ASSET CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testAssetConfiguration() public {
        (uint256 lendFactor, uint256 borrowFactor) = pool.configurations(address(asset));

        assertEq(lendFactor, 0.5e18);
        assertEq(borrowFactor, 0);
        assertEq(pool.baseUnits(address(asset)), 1e18);
    }

    // function testNewAssetConfiguration() public {
    //     MockERC20 newAsset = new MockERC20("Mock Token", "MKT", 18);

    //     pool.configureAsset(newAsset,newAsset, 0.6e18, 0);

    //     (uint256 lendFactor, uint256 borrowFactor) = pool.configurations(
    //         newAsset
    //     );

    //     assertEq(lendFactor, 0.6e18);
    //     assertEq(borrowFactor, 0);
    //     assertEq(pool.baseUnits(newAsset), 1e18);
    // }

    // function testUpdateConfiguration() public {
    //     pool.updateConfiguration(asset, LendingPool.Configuration(0.9e18, 0));

    //     (uint256 lendFactor, ) = pool.configurations(asset);

    //     assertEq(lendFactor, 0.9e18);
    // }

    /*///////////////////////////////////////////////////////////////
                    ASSET CONFIGURATION SANITY CHECKS
    //////////////////////////////////////////////////////////////*/

    // function testFailNewAssetConfigurationNotOwner() public {
    //     MockERC20 newAsset = new MockERC20("Mock Token", "MKT", 18);

    //     vm.startPrank(address(0xBABE));
    //     pool.configureAsset(newAsset,newAsset, 0.6e18, 0);
    // }

    // function testFailUpdateConfigurationNotOwner() public {
    //     vm.startPrank(address(0xBABE));
    //     pool.updateConfiguration(asset, LendingPool.Configuration(0.9e18, 0));
    // }
}
