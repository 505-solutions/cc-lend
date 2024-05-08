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

import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceOracle} from "./mocks/MockPriceOracle.sol";
import {MockInterestRateModel} from "./mocks/MockInterestRateModel.sol";
// import {MockLiquidator} from "./mocks/MockLiquidator.sol";

import {LendingPool} from "src/LendingPool.sol";

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/// @title Configuration Test Contract
contract ConfigurationTest is Test {
    using FixedPointMathLib for uint256;

    /* Lending Pool Contracts */
    LendingPool ethPool;
    LendingPool flarePool;

    /* Mocks */
    MockERC20 asset;
    MockERC20 borrowAsset;

    MockPriceOracle oracle;
    MockInterestRateModel interestRateModel;
    // MockLiquidator liquidator;

    function setUp() public {
        ethPool = new LendingPool(address(this), address(this));
        flarePool = new LendingPool(address(this), address(this));

        interestRateModel = new MockInterestRateModel();

        asset = new MockERC20("Mock Token", "MKT", 18);

        ethPool.configureAsset(address(asset), 0.5e18, 0);
        ethPool.setInterestRateModel(address(asset), address(interestRateModel));
        flarePool.configureAsset(address(asset), 0.5e18, 0);
        flarePool.setInterestRateModel(address(asset), address(interestRateModel));

        oracle = new MockPriceOracle();
        oracle.updatePrice(address(asset), 1e18);
        ethPool.setOracle(address(oracle));
        flarePool.setOracle(address(oracle));

        borrowAsset = new MockERC20("Mock Token", "MKT", 18);

        ethPool.configureAsset(address(borrowAsset), 0, 1e18);
        ethPool.setInterestRateModel(address(borrowAsset), address(interestRateModel));
        flarePool.configureAsset(address(borrowAsset), 0, 1e18);
        flarePool.setInterestRateModel(address(borrowAsset), address(interestRateModel));

        // liquidator = new MockLiquidator(pool, PriceOracle(address(oracle)));
    }

    function increaseExchangeLiquidity() internal {
        // NOTE: Funds both pools with enough assets to test crosschain interactions.
        mintAndApprove(asset, 100 ether, address(ethPool));
        ethPool.increaseAvailableLiquidity(address(asset), 100 ether);

        mintAndApprove(borrowAsset, 100 ether, address(ethPool));
        ethPool.increaseAvailableLiquidity(address(borrowAsset), 100 ether);

        mintAndApprove(asset, 100 ether, address(flarePool));
        flarePool.increaseAvailableLiquidity(address(asset), 100 ether);

        mintAndApprove(borrowAsset, 100 ether, address(flarePool));
        flarePool.increaseAvailableLiquidity(address(borrowAsset), 100 ether);
    }

    function testCrossChainDeposit(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Mint, approve, and deposit the asset.
        mintAndApprove(asset, amount, address(ethPool));

        ethPool.deposit(address(asset), amount, true);

        // Checks. Note that the default exchange rate is 1,
        // so the values should be equal to the input amount.
        assertEq(ethPool.balanceOf(address(asset), address(this)), amount, "Incorrect Balance");
        assertEq(ethPool.totalUnderlying(address(asset)), amount, "Incorrect Total Underlying");

        flarePool.handleCrossChainDeposit(address(asset), amount, address(this), true);

        // The message was relayed and the balance was updated.
        assertEq(flarePool.balanceOf(address(asset), address(this)), amount, "Incorrect Balance");
        assertEq(flarePool.totalUnderlying(address(asset)), amount, "Incorrect Total Underlying");
    }

    function testCrossChainSourceWithdrawal(uint256 amount) public {
        vm.assume(amount >= 1e12 && amount <= 1e27);

        // Mint, approve, and deposit the asset.
        testCrossChainDeposit(amount);

        // Withdraw the asset.
        ethPool.withdraw(address(asset), amount, false);

        // Checks.
        assertEq(asset.balanceOf(address(this)), amount, "Incorrect asset balance");
        assertEq(ethPool.balanceOf(address(asset), address(this)), 0, "Incorrect pool balance");

        flarePool.handleCrossChainWithdrawal(address(asset), amount, address(this), false);

        assertEq(asset.balanceOf(address(this)), amount, "Incorrect asset balance");
        assertEq(flarePool.balanceOf(address(asset), address(this)), 0, "Incorrect pool balance");
    }

    function testCrossChainDestWithdrawal(uint256 amount) public {
        vm.assume(amount >= 1e12 && amount <= 1e19);

        // Mint, approve, and deposit the asset.
        testCrossChainDeposit(amount);

        increaseExchangeLiquidity();

        console.log("Flare Pool Balance: ", flarePool.balanceOf(address(asset), address(this)));

        // Withdraw the asset.
        flarePool.withdraw(address(asset), amount, false);

        // Checks.
        assertEq(asset.balanceOf(address(this)), amount, "Incorrect asset balance");
        assertApproxEqAbs(flarePool.balanceOf(address(asset), address(this)), 100 ether, 100, "Incorrect pool balance");

        ethPool.handleCrossChainWithdrawal(address(asset), amount, address(this), false);

        assertEq(asset.balanceOf(address(this)), amount, "Incorrect asset balance");
        assertApproxEqAbs(ethPool.balanceOf(address(asset), address(this)), 100 ether, 100, "Incorrect pool balance");
    }

    function testCrossChainSourceBorrow(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e19);

        // Mint, approve, and deposit the asset.
        testCrossChainDeposit(amount);

        increaseExchangeLiquidity();

        // Set the price of collateral to 1 ETH.
        oracle.updatePrice(address(asset), 1e18);

        // Set the price of the borrow asset to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        oracle.updatePrice(address(borrowAsset), 2e18);

        // Borrow the asset.
        ethPool.borrow(address(borrowAsset), amount / 4);

        // Checks.
        assertEq(borrowAsset.balanceOf(address(this)), amount / 4);
        assertEq(ethPool.borrowBalance(address(borrowAsset), address(this)), amount / 4);
        assertEq(ethPool.totalBorrows(address(borrowAsset)), amount / 4);

        flarePool.handleCrossChainBorrow(address(borrowAsset), amount / 4, address(this));

        assertEq(borrowAsset.balanceOf(address(this)), amount / 4);
        assertEq(flarePool.borrowBalance(address(borrowAsset), address(this)), amount / 4);
        assertEq(flarePool.totalBorrows(address(borrowAsset)), amount / 4);
    }

    function testCrossChainDestBorrow(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        uint256 amount = 1e18;

        // Mint, approve, and deposit the asset.
        testCrossChainDeposit(amount);

        increaseExchangeLiquidity();

        // Set the price of collateral to 1 ETH.
        oracle.updatePrice(address(asset), 1e18);

        // Set the price of the borrow asset to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        oracle.updatePrice(address(borrowAsset), 2e18);

        // Borrow the asset.
        flarePool.borrow(address(borrowAsset), amount / 4);

        // Checks.
        assertEq(borrowAsset.balanceOf(address(this)), amount / 4);
        assertEq(flarePool.borrowBalance(address(borrowAsset), address(this)), amount / 4);
        assertEq(flarePool.totalBorrows(address(borrowAsset)), amount / 4);

        ethPool.handleCrossChainBorrow(address(borrowAsset), amount / 4, address(this));

        assertEq(borrowAsset.balanceOf(address(this)), amount / 4);
        assertEq(ethPool.borrowBalance(address(borrowAsset), address(this)), amount / 4);
        assertEq(ethPool.totalBorrows(address(borrowAsset)), amount / 4);
    }

    //
    function testCrossChainSourceRepay(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e19);

        uint256 amount = 0.25 ether;

        testCrossChainSourceBorrow(amount);

        // Repay the tokens.
        borrowAsset.approve(address(ethPool), amount / 4);
        ethPool.repay(address(borrowAsset), amount / 4);

        // Checks.

        assertApproxEqAbs(borrowAsset.balanceOf(address(this)), 0, 100);
        assertApproxEqAbs(ethPool.borrowBalance(address(borrowAsset), address(this)), 0, 100);
        assertEq(ethPool.totalBorrows(address(borrowAsset)), 0);
    }

    function testCrossChainDestRepay(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e19);

        uint256 amount = 0.25 ether;

        testCrossChainDestBorrow(amount);

        // Repay the tokens.
        borrowAsset.approve(address(flarePool), amount);
        flarePool.repay(address(borrowAsset), amount);

        // Checks.

        assertApproxEqAbs(borrowAsset.balanceOf(address(this)), 0, 100);
        assertApproxEqAbs(flarePool.borrowBalance(address(borrowAsset), address(this)), 0, 100);
        assertEq(flarePool.totalBorrows(address(borrowAsset)), 0);
    }

    // UTILS ================================================================

    function mintAndApprove(MockERC20 underlying, uint256 amount, address poolAddress) internal {
        underlying.mint(address(this), amount);
        underlying.approve(poolAddress, amount);

        uint256 userBalance = asset.balanceOf(address(this));
    }
}
