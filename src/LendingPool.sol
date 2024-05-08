// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IERC20} from "./Interfaces/IERC20.sol";

import {Accounting} from "./utils/Accounting.sol";

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Owned} from "solmate/auth/Owned.sol";

import "forge-std/console.sol";

contract LendingPool is Accounting {
    using SafeTransferLib for IERC20;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    // TODO: Make everything non-reentrant

    constructor(address owner, address messageRelay) Owned(owner) {
        s_messageRelay = messageRelay;
    }

    /*///////////////////////////////////////////////////////////////
                       DEPOSIT/WITHDRAW INTERFACE
    //////////////////////////////////////////////////////////////*/

    // NOTE: Helper function for testing and possibly rebalancing the available liquidity.
    function increaseAvailableLiquidity(address asset, uint256 amount) external {
        // Transfer underlying in from the user.
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        availableLiquidity[asset] += amount;
    }

    // * DEPOSITS * //

    /// @notice Deposit underlying tokens into the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to be deposited.
    /// @param enable A boolean indicating whether to enable the underlying asset as collateral.
    function deposit(address asset, uint256 amount, bool enable) external {
        _deposit(asset, amount, msg.sender, enable);

        // Transfer underlying in from the user.
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        // Emit the event.
        emit Deposit(msg.sender, asset, amount, enable);
    }

    /// @notice Handle the deposit event passed from the Source Chain by the Message Relay.
    function handleCrossChainDeposit(address asset, uint256 amount, address depositor, bool enable)
        external
        onlyMessageRelay
    {
        _deposit(asset, amount, depositor, enable);
    }

    function _deposit(address asset, uint256 amount, address depositor, bool enable) internal {
        // Ensure the amount is valid.
        require(amount > 0, "INVALID_AMOUNT");

        // Calculate the amount of internal balance units to be stored.
        uint256 shares = amount.mulDivDown(baseUnits[asset], internalBalanceExchangeRate(asset));

        // Modify the internal balance of the sender.
        // Cannot overflow because the sum of all user
        // balances won't be greater than type(uint256).max
        unchecked {
            internalBalances[asset][depositor] += shares;
        }

        // Add to the asset's total internal supply.
        totalInternalBalances[asset] += shares;

        // Add to the available liquidity of the asset in the system (on Eth + on Flare).
        availableLiquidity[asset] += amount;

        // If `enable` is set to true, enable the asset as collateral.
        if (enable) _enableAsset(asset, depositor);
    }

    // * WITDHRAWALS * //

    /// @notice Withdraw underlying tokens from the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to be withdrawn.
    /// @param disable A boolean indicating whether to disable the underlying asset as collateral.
    function withdraw(address asset, uint256 amount, bool disable) external {
        _withdraw(asset, amount, msg.sender, disable);

        // Transfer underlying to the user.
        IERC20(asset).transfer(msg.sender, amount);

        // Emit the event.
        emit Withdraw(msg.sender, asset, amount, disable);
    }

    /// @notice Handle the withdrawal event passed from the Source Chain by the Message Relay.
    function handleCrossChainWithdrawal(address asset, uint256 amount, address depositor, bool disable)
        external
        onlyMessageRelay
    {
        _withdraw(asset, amount, depositor, disable);
    }

    function _withdraw(address asset, uint256 amount, address depositor, bool disable) internal {
        // Ensure the amount is valid.
        require(amount > 0, "AMOUNT_TOO_LOW");

        // Calculate the amount of internal balance units to be subtracted.
        uint256 shares = amount.mulDivDown(baseUnits[asset], internalBalanceExchangeRate(asset));

        // Modify the internal balance of the sender.
        internalBalances[asset][depositor] -= shares;

        // Subtract from the asset's total internal supply.
        // Cannot undeflow because the user balance will
        // never be greater than the total suuply.
        unchecked {
            totalInternalBalances[asset] -= shares;
        }

        // Remove from the available liquidity of the asset in the system (on Eth + on Flare).
        availableLiquidity[asset] -= amount;

        // If `disable` is set to true, disable the asset as collateral.
        if (disable) _disableAsset(asset, depositor);
    }

    /*///////////////////////////////////////////////////////////////
                      BORROW/REPAYMENT INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice Borrow underlying tokens from the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to borrow.
    function borrow(address asset, uint256 amount) external {
        _borrow(asset, amount, msg.sender);

        // Transfer tokens to the borrower.
        IERC20(asset).transfer(msg.sender, amount);

        // Emit the event.
        emit Borrow(msg.sender, asset, amount);
    }

    /// @notice Handle the borrow event passed from the Source Chain by the Message Relay.
    function handleCrossChainBorrow(address asset, uint256 amount, address depositor) external onlyMessageRelay {
        _borrow(asset, amount, depositor);
    }

    function _borrow(address asset, uint256 amount, address depositor) internal {
        // Ensure the amount is valid.
        require(amount > 0, "AMOUNT_TOO_LOW");

        // Accrue interest.
        // TODO: is this the right place to accrue interest?
        accrueInterest(asset);

        // Enable the asset, if it is not already enabled.
        enableAsset(asset);

        // Ensure the caller is able to execute this borrow.
        require(canBorrow(asset, depositor, amount));

        // Calculate the amount of internal debt units to be stored.
        uint256 debtUnits = amount.mulDivDown(baseUnits[asset], internalDebtExchangeRate(asset));

        // Update the internal borrow balance of the borrower.
        // Cannot overflow because the sum of all user
        // balances won't be greater than type(uint256).max
        unchecked {
            internalDebt[asset][depositor] += debtUnits;
        }

        // Add to the asset's total internal debt.
        totalInternalDebt[asset] += debtUnits;

        // Remove from the available liquidity of the asset in the system (on Eth + on Flare).
        availableLiquidity[asset] -= amount;

        // Update the cached debt of the asset.
        cachedTotalBorrows[asset] += amount;
    }

    /// @notice Repay underlying tokens to the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to repay.
    function repay(address asset, uint256 amount) external {
        _repay(asset, amount, msg.sender);

        // Transfer tokens from the user.
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        // Emit the event.
        emit Repay(msg.sender, asset, amount);
    }

    /// @notice Handle the repay event passed from the Source Chain by the Message Relay.
    function handleCrossChainRepay(address asset, uint256 amount, address depositor) external onlyMessageRelay {
        _repay(asset, amount, depositor);
    }

    function _repay(address asset, uint256 amount, address depositor) internal {
        // Ensure the amount is valid.
        require(amount > 0, "AMOUNT_TOO_LOW");

        // Calculate the amount of internal debt units to be stored.
        uint256 debtUnits = amount.mulDivDown(baseUnits[asset], internalDebtExchangeRate(asset));

        // Update the internal borrow balance of the borrower.
        internalDebt[asset][depositor] -= debtUnits;

        // Add to the asset's total internal debt.
        // Cannot undeflow because the user balance will
        // never be greater than the total suuply.
        unchecked {
            totalInternalDebt[asset] -= debtUnits;
        }

        // Add to the available liquidity of the asset in the system (on Eth + on Flare).
        availableLiquidity[asset] += amount;

        // Accrue interest.
        // TODO: is this the right place to accrue interest?
        accrueInterest(asset);

        // Update the cached debt of the asset.
        cachedTotalBorrows[asset] -= amount;
    }

    // TODO: Periodicaly check the liquidity available on both chains and update the availableLiquidity storage variable

    /*///////////////////////////////////////////////////////////////
                          LIQUIDATION INTERFACE
    //////////////////////////////////////////////////////////////*/

    // TODO: Figure out and Test liquidatio Logic
    function liquidateUser(address borrowedAsset, address collateralAsset, address borrower, uint256 repayAmount)
        external
    {
        require(userLiquidatable(borrower), "CANNOT_LIQUIDATE_HEALTHY_USER");

        // Calculate the number of collateral asset to be seized
        uint256 seizedCollateralAmount = seizeCollateral(borrowedAsset, collateralAsset, repayAmount);

        // Assert user health factor is == MAX_HEALTH_FACTOR
        require(calculateHealthFactor(borrowedAsset, borrower, 0) == MAX_HEALTH_FACTOR, "NOT_HEALTHY");
    }
}
