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
import {EVMTransaction} from "src/Interfaces/IEVMTransactionVerification.sol";

import {PriceOraclePlugin} from "src/PriceOraclePlugin.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceOracle} from "./mocks/MockPriceOracle.sol";
import {MockInterestRateModel} from "./mocks/MockInterestRateModel.sol";
// import {MockLiquidator} from "./mocks/MockLiquidator.sol";
import {MockFtsoRegistry} from "./mocks/MockFtsoRegistry.sol";

import {LendingPool} from "src/LendingPool.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/// @title Configuration Test Contract
contract CrossChainActionsTest is Test {
    using FixedPointMathLib for uint256;

    /* Mocks */
    MockERC20 testEth;
    MockERC20 testUsdc;

    MockPriceOracle oracle;
    MockFtsoRegistry ftsoRegistry;

    PriceOraclePlugin priceOraclePlugin;

    uint256 constant ETH_FTSO_IDX = 10;
    uint256 constant ETH_FTSO_DECIMALS = 5;
    uint256 constant USDC_FTSO_IDX = 25;
    uint256 constant USDC_FTSO_DECIMALS = 5;

    function setUp() public {
        testEth = new MockERC20("Mock Eth", "MKE", 18);
        testUsdc = new MockERC20("Mock USDC", "MKU", 18);

        priceOraclePlugin = new PriceOraclePlugin(address(testEth), ETH_FTSO_IDX);
        priceOraclePlugin.setOracleSource(address(this));

        if (block.chainid != 16) {
            // ! On Sepolia
            oracle = new MockPriceOracle();
            oracle.updatePrice(address(testEth), 3000e18);
            oracle.updatePrice(address(testUsdc), 1e18);
            priceOraclePlugin.setOracleSource(address(oracle));
        } else {
            // ! If on Flare
            ftsoRegistry = new MockFtsoRegistry();
            ftsoRegistry.updatePrice(ETH_FTSO_IDX, 3000e5, ETH_FTSO_DECIMALS);
            ftsoRegistry.updatePrice(USDC_FTSO_IDX, 1e5, USDC_FTSO_DECIMALS);

            priceOraclePlugin.setFtsoIndex(address(testEth), ETH_FTSO_IDX);
            priceOraclePlugin.setFtsoIndex(address(testUsdc), USDC_FTSO_IDX);

            priceOraclePlugin.setOracleSource(address(ftsoRegistry));
        }
    }

    function testGetOraclePrice() public view {
        if (block.chainid != 16) {
            uint256 ethPrice = priceOraclePlugin.getAssetPrice(address(testEth));
            uint256 usdcPrice = priceOraclePlugin.getAssetPrice(address(testUsdc));

            console.log("Eth Price: ", ethPrice);
            console.log("Usdc Price: ", usdcPrice);
        } else {
            uint256 ethPrice = priceOraclePlugin.getAssetPrice(address(testEth));
            uint256 usdcPrice = priceOraclePlugin.getAssetPrice(address(testUsdc));

            console.log("Eth Price: ", ethPrice);
            console.log("Usdc Price: ", usdcPrice);
        }
    }

    function testUpdateOraclePrice() public {
        if (block.chainid != 16) {
            updateOraclePrices(address(testEth), 4000e18);
            updateOraclePrices(address(testUsdc), 2e18);

            testGetOraclePrice();
        } else {
            updateOraclePrices(address(testEth), 4000e18);
            updateOraclePrices(address(testUsdc), 2e18);

            testGetOraclePrice();
        }
    }

    // UTILS ================================================================

    function updateOraclePrices(address _asset, uint256 price) private {
        if (block.chainid != 16) {
            oracle.updatePrice(_asset, price);
        } else {
            if (_asset == address(testEth)) {
                ftsoRegistry.updatePrice(ETH_FTSO_IDX, price / 10 ** (18 - ETH_FTSO_DECIMALS), ETH_FTSO_DECIMALS);
            } else if (_asset == address(testUsdc)) {
                ftsoRegistry.updatePrice(USDC_FTSO_IDX, price / 10 ** (18 - USDC_FTSO_DECIMALS), USDC_FTSO_DECIMALS);
            }
        }
    }
}
