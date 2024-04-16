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
    LendingPool pool;

    /* Mocks */
    MockERC20 asset;
    MockERC20 borrowAsset;

    MockPriceOracle oracle;
    MockInterestRateModel interestRateModel;
    // MockLiquidator liquidator;

    function setUp() public {
        pool = new LendingPool(address(this), address(this));

        interestRateModel = new MockInterestRateModel();

        asset = new MockERC20();
        asset.initialize("Test Token", "TEST", 18);

        pool.configureAsset(address(asset), 0.5e18, 0);
        pool.setInterestRateModel(address(asset), address(interestRateModel));

        oracle = new MockPriceOracle();
        oracle.updatePrice(address(asset), 1e18);
        pool.setOracle(address(oracle));

        borrowAsset = new MockERC20();
        borrowAsset.initialize("Borrow Test Token", "TBT", 18);

        pool.configureAsset(address(borrowAsset), 0, 1e18);
        pool.setInterestRateModel(
            address(borrowAsset),
            address(interestRateModel)
        );

        // liquidator = new MockLiquidator(pool, PriceOracle(address(oracle)));
    }

    function testDeposit(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Mint, approve, and deposit the asset.
        mintAndApprove(asset, amount);

        uint256 userBalance = asset.balanceOf(address(this));
        uint256 poolBalance = asset.balanceOf(address(pool));

        pool.deposit(address(asset), amount, false);

        uint256 userBalance2 = asset.balanceOf(address(this));
        uint256 poolBalance2 = asset.balanceOf(address(pool));

        // Checks. Note that the default exchange rate is 1,
        // so the values should be equal to the input amount.
        assertEq(
            pool.balanceOf(address(asset), address(this)),
            amount,
            "Incorrect Balance"
        );
        assertEq(
            pool.totalUnderlying(address(asset)),
            amount,
            "Incorrect Total Underlying"
        );
    }

    function testWithdrawal(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Mint, approve, and deposit the asset.
        testDeposit(amount);

        // Withdraw the asset.
        pool.withdraw(address(asset), amount, false);

        // Checks.
        assertEq(
            asset.balanceOf(address(this)),
            amount,
            "Incorrect asset balance"
        );
        assertEq(
            pool.balanceOf(address(asset), address(this)),
            0,
            "Incorrect pool balance"
        );
    }

    /*///////////////////////////////////////////////////////////////
                  DEPOSIT/WITHDRAWAL SANITY CHECK TESTS
    //////////////////////////////////////////////////////////////*/

    function testFailDepositAssetNotInPool() public {
        // Mock token.
        MockERC20 mockAsset = new MockERC20();
        mockAsset.initialize("Mock Token", "MKT", 18);

        // Mint tokens.
        mockAsset.mint(address(this), 1e18);

        // Approve the pool to spend half of the tokens.
        mockAsset.approve(address(pool), 0.5e18);

        // Attempt to deposit the tokens.
        pool.deposit(address(mockAsset), 1e18, false);
    }

    function testFailDepositWithNotEnoughApproval() public {
        // Mint tokens.
        asset.mint(address(this), 1e18);

        // Approve the pool to spend half of the tokens.
        asset.approve(address(pool), 0.5e18);

        // Attempt to deposit the tokens.
        pool.deposit(address(asset), 1e18, false);
    }

    function testFailWithdrawAssetNotInPool() public {
        // Mock token.
        MockERC20 mockAsset = new MockERC20();
        mockAsset.initialize("Mock Token", "MKT", 18);

        // Mint tokens.
        testDeposit(1e18);

        // Attempt to withdraw the tokens.
        pool.withdraw(address(mockAsset), 1e18, false);
    }

    function testFailWithdrawWithNotEnoughBalance() public {
        // Mint tokens.
        testDeposit(1e18);

        // Attempt to withdraw the tokens.
        pool.withdraw(address(asset), 2e18, false);
    }

    function testFailWithdrawWithNoBalance() public {
        // Attempt to withdraw tokens.
        pool.withdraw(address(asset), 1e18, false);
    }

    function testFailWithNoApproval() public {
        // Attempt to deposit tokens.
        pool.deposit(address(asset), 1e18, false);
    }

    /*///////////////////////////////////////////////////////////////
                         COLLATERALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testEnableCollateral() public {
        // Enable asset as collateral.
        pool.enableAsset(address(asset));

        // Checks.
        assertTrue(pool.enabledCollateral(address(this), address(asset)));
    }

    function testDisableCollateral() external {
        // Enable the asset as collateral.
        testEnableCollateral();

        // Disable the asset as collateral.
        pool.disableAsset(address(asset));

        // Checks.
        assertFalse(pool.enabledCollateral(address(this), address(asset)));
    }

    /*///////////////////////////////////////////////////////////////
                         BORROW/REPAYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testBorrow(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Deposit tokens and enable them as collateral.
        mintAndApprove(asset, amount);
        pool.deposit(address(asset), amount, true);

        // Mint borrow tokens and supply them to the pool.
        mintAndApprove(borrowAsset, amount / 4);
        pool.deposit(address(borrowAsset), amount / 4, false);

        // Set the price of collateral to 1 ETH.
        oracle.updatePrice(address(asset), 1e18);

        // Set the price of the borrow asset to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        oracle.updatePrice(address(borrowAsset), 2e18);

        // Borrow the asset.
        pool.borrow(address(borrowAsset), amount / 4);

        // Checks.
        assertEq(borrowAsset.balanceOf(address(this)), amount / 4);
        assertEq(
            pool.borrowBalance(address(borrowAsset), address(this)),
            amount / 4
        );
        assertEq(pool.totalBorrows(address(borrowAsset)), amount / 4);
        assertEq(pool.totalUnderlying(address(borrowAsset)), amount / 4);
    }

    function testRepay(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Borrow tokens.
        testBorrow(amount);

        // Repay the tokens.
        borrowAsset.approve(address(pool), amount / 4);
        pool.repay(address(borrowAsset), amount / 4);
    }

    function testInterestAccrual() public {
        uint256 amount = 1e18;

        // block number is 1.

        // Borrow tokens.
        testBorrow(amount);

        // Warp block number to 6.
        vm.roll(block.number + 5);

        // Calculate the expected amount (after interest).
        // The borrow rate is constant, so the interest is always 5% per block.
        // expected = borrowed * interest ^ (blockDelta)
        uint256 expected = (amount / 4).mulWadDown(
            uint256(interestRateModel.getBorrowRate(0, 0, 0)).rpow(5, 1e18)
        );

        // Checks.
        assertEq(
            pool.borrowBalance(address(borrowAsset), address(this)),
            expected
        );
        assertEq(pool.totalBorrows(address(borrowAsset)), expected);
        assertEq(pool.totalUnderlying(address(borrowAsset)), expected);
        assertEq(pool.balanceOf(address(borrowAsset), address(this)), expected);
    }

    // /*///////////////////////////////////////////////////////////////
    //                BORROW/REPAYMENT SANITY CHECK TESTS
    // //////////////////////////////////////////////////////////////*/

    function testFailBorrowAssetNotInPool() public {
        // Mock token.
        MockERC20 mockAsset = new MockERC20();
        mockAsset.initialize("Mock Token", "MKT", 18);

        // Amount to mint.
        uint256 amount = 1e18;

        // Deposit tokens and enable them as collateral.
        mintAndApprove(asset, amount);
        pool.deposit(address(asset), amount, true);

        // Mint borrow tokens and supply them to the pool.
        mintAndApprove(borrowAsset, amount / 4);
        pool.deposit(address(borrowAsset), amount / 4, false);

        // Set the price of collateral to 1 ETH.
        oracle.updatePrice(address(asset), 1e18);

        // Set the price of the borrow asset to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        oracle.updatePrice(address(borrowAsset), 2e18);

        // Borrow the asset.
        pool.borrow(address(mockAsset), amount / 4);
    }

    function testFailBorrowWithCollateralDisabled(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Deposit tokens and enable them as collateral.
        mintAndApprove(asset, amount);
        pool.deposit(address(asset), amount, false);

        // Mint borrow tokens and supply them to the pool.
        mintAndApprove(borrowAsset, amount / 2);
        pool.deposit(address(borrowAsset), amount / 2, false);

        // Set the price of collateral to 1 ETH.
        oracle.updatePrice(address(asset), 1e18);

        // Set the price of the borrow asset to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        oracle.updatePrice(address(borrowAsset), 2e18);

        // Borrow the asset.
        pool.borrow(address(borrowAsset), amount / 4);
    }

    function testFailBorrowWithNoCollateral(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Mint borrow tokens and supply them to the pool.
        mintAndApprove(borrowAsset, amount);
        pool.deposit(address(borrowAsset), amount, false);

        // Set the price of collateral to 1 ETH.
        oracle.updatePrice(address(asset), 1e18);

        // Set the price of the borrow asset to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        oracle.updatePrice(address(borrowAsset), 2e18);

        // Borrow the asset.
        pool.borrow(address(borrowAsset), amount);
    }

    function testFailBorrowWithNotEnoughCollateral(uint256 amount) public {
        vm.assume(amount >= 1e5 && amount <= 1e27);

        // Deposit tokens and enable them as collateral.
        mintAndApprove(asset, amount);
        pool.deposit(address(asset), amount, true);

        // Mint borrow tokens and supply them to the pool.
        mintAndApprove(borrowAsset, amount / 2);
        pool.deposit(address(borrowAsset), amount / 2, false);

        // Set the price of collateral to 1 ETH.
        oracle.updatePrice(address(asset), 1e18);

        // Set the price of the borrow asset to 2 ETH.
        // This means that with a 0.5 lend factor, we should be able to borrow 0.25 ETH.
        oracle.updatePrice(address(borrowAsset), 2e18);

        // Borrow the asset.
        pool.borrow(address(borrowAsset), amount / 2);
    }

    function testCannotDisableIfBeingBorrowed() public {
        // Borrow asset.
        testBorrow(1e18);

        // Attempt to disable the asset as collateral.
        pool.disableAsset(address(borrowAsset));

        // Checks.
        assertTrue(pool.enabledCollateral(address(this), address(borrowAsset)));
    }

    // UTILS ================================================================

    function mintAndApprove(MockERC20 underlying, uint256 amount) internal {
        underlying.mint(address(this), amount);
        underlying.approve(address(pool), amount);

        uint256 userBalance = asset.balanceOf(address(this));
    }
}
