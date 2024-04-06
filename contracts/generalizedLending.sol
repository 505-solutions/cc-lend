// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IERC20} from "./Interfaces/IERC20.sol";

import {Accounting} from "./utils/Accounting.sol";

import {InterestRateModel} from "./Interfaces/IIRM.sol";

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract LendingPool is Accounting {
    using SafeTransferLib for IERC20;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    // TODO: Add permissions (auth) to functions that require it.

    /*///////////////////////////////////////////////////////////////
                          INTEREST RATE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets a new Interest Rate Model for a specfic asset.
    /// @param asset The underlying asset.
    /// @param newInterestRateModel The new IRM address.
    function setInterestRateModel(
        address asset,
        InterestRateModel newInterestRateModel
    ) external {
        // Update the asset's Interest Rate Model.
        interestRateModels[asset] = newInterestRateModel;

        // Emit the event.
        emit InterestRateModelUpdated(msg.sender, asset, newInterestRateModel);
    }

    /// @notice Adds a new asset to the pool.
    /// @param asset The underlying asset.
    /// @param configuration The lend/borrow factors for the asset.
    function configureAsset(
        address asset,
        Configuration memory configuration
    ) external {
        // Ensure that this asset has not been configured.
        require(
            configurations[asset].borrowFactor == 0 &&
                configurations[asset].lendFactor == 0,
            "ASSET_ALREADY_CONFIGURED"
        );

        configurations[asset] = configuration;
        baseUnits[asset] = 10 ** IERC20(asset).decimals();

        // Emit the event.
        emit AssetConfigured(asset, configuration);
    }

    /// @notice Updates the lend/borrow factors of an asset.
    /// @param asset The underlying asset.
    /// @param newConfiguration The new lend/borrow factors for the asset.
    function updateConfiguration(
        address asset,
        Configuration memory newConfiguration
    ) external {
        // Update the asset configuration.
        configurations[asset] = newConfiguration;

        // Emit the event.
        emit AssetConfigurationUpdated(asset, newConfiguration);
    }

    /*///////////////////////////////////////////////////////////////
                       DEPOSIT/WITHDRAW INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit underlying tokens into the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to be deposited.
    /// @param enable A boolean indicating whether to enable the underlying asset as collateral.
    function deposit(address asset, uint256 amount, bool enable) external {
        // Ensure the amount is valid.
        require(amount > 0, "INVALID_AMOUNT");

        // Calculate the amount of internal balance units to be stored.
        uint256 shares = amount.mulDivDown(
            baseUnits[asset],
            internalBalanceExchangeRate(asset)
        );

        // Modify the internal balance of the sender.
        // Cannot overflow because the sum of all user
        // balances won't be greater than type(uint256).max
        unchecked {
            internalBalances[asset][msg.sender] += shares;
        }

        // Add to the asset's total internal supply.
        totalInternalBalances[asset] += shares;

        // Transfer underlying in from the user.
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        // If `enable` is set to true, enable the asset as collateral.
        if (enable) enableAsset(asset);

        // Emit the event.
        emit Deposit(msg.sender, asset, amount);
    }

    /// @notice Withdraw underlying tokens from the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to be withdrawn.
    /// @param disable A boolean indicating whether to disable the underlying asset as collateral.
    function withdraw(address asset, uint256 amount, bool disable) external {
        // Ensure the amount is valid.
        require(amount > 0, "AMOUNT_TOO_LOW");

        // Calculate the amount of internal balance units to be subtracted.
        uint256 shares = amount.mulDivDown(
            baseUnits[asset],
            internalBalanceExchangeRate(asset)
        );

        // Modify the internal balance of the sender.
        internalBalances[asset][msg.sender] -= shares;

        // Subtract from the asset's total internal supply.
        // Cannot undeflow because the user balance will
        // never be greater than the total suuply.
        unchecked {
            totalInternalBalances[asset] -= shares;
        }

        // Transfer underlying to the user.
        IERC20(asset).transfer(msg.sender, amount);

        // If `disable` is set to true, disable the asset as collateral.
        if (disable) disableAsset(asset);

        // Emit the event.
        emit Withdraw(msg.sender, asset, amount);
    }

    /*///////////////////////////////////////////////////////////////
                      BORROW/REPAYMENT INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice Borrow underlying tokens from the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to borrow.
    function borrow(address asset, uint256 amount) external {
        // Ensure the amount is valid.
        require(amount > 0, "AMOUNT_TOO_LOW");

        // Accrue interest.
        // TODO: is this the right place to accrue interest?
        accrueInterest(asset);

        // Enable the asset, if it is not already enabled.
        enableAsset(asset);

        // Ensure the caller is able to execute this borrow.
        require(canBorrow(asset, msg.sender, amount));

        // Calculate the amount of internal debt units to be stored.
        uint256 debtUnits = amount.mulDivDown(
            baseUnits[asset],
            internalDebtExchangeRate(asset)
        );

        // Update the internal borrow balance of the borrower.
        // Cannot overflow because the sum of all user
        // balances won't be greater than type(uint256).max
        unchecked {
            internalDebt[asset][msg.sender] += debtUnits;
        }

        // Add to the asset's total internal debt.
        totalInternalDebt[asset] += debtUnits;

        // Update the cached debt of the asset.
        cachedTotalBorrows[asset] += amount;

        // Transfer tokens to the borrower.
        IERC20(asset).transfer(msg.sender, amount);

        // Emit the event.
        emit Borrow(msg.sender, asset, amount);
    }

    /// @notice Repay underlying tokens to the pool.
    /// @param asset The underlying asset.
    /// @param amount The amount to repay.
    function repay(address asset, uint256 amount) public {
        // Ensure the amount is valid.
        require(amount > 0, "AMOUNT_TOO_LOW");

        // Calculate the amount of internal debt units to be stored.
        uint256 debtUnits = amount.mulDivDown(
            baseUnits[asset],
            internalDebtExchangeRate(asset)
        );

        // Update the internal borrow balance of the borrower.
        internalDebt[asset][msg.sender] -= debtUnits;

        // Add to the asset's total internal debt.
        // Cannot undeflow because the user balance will
        // never be greater than the total suuply.
        unchecked {
            totalInternalDebt[asset] -= debtUnits;
        }

        // Transfer tokens from the user.
        IERC20(asset).transferFrom(msg.sender, address(this), amount - 1);

        // Accrue interest.
        // TODO: is this the right place to accrue interest?
        accrueInterest(asset);

        // Emit the event.
        emit Repay(msg.sender, asset, amount);
    }

    /*///////////////////////////////////////////////////////////////
                          LIQUIDATION INTERFACE
    //////////////////////////////////////////////////////////////*/

    function liquidateUser(
        address borrowedAsset,
        address collateralAsset,
        address borrower,
        uint256 repayAmount
    ) external {
        require(userLiquidatable(borrower), "CANNOT_LIQUIDATE_HEALTHY_USER");

        // Calculate the number of collateral asset to be seized
        uint256 seizedCollateralAmount = seizeCollateral(
            borrowedAsset,
            collateralAsset,
            repayAmount
        );

        // Assert user health factor is == MAX_HEALTH_FACTOR
        require(
            calculateHealthFactor(borrowedAsset, borrower, 0) ==
                MAX_HEALTH_FACTOR,
            "NOT_HEALTHY"
        );
    }

    /// @dev Returns a boolean indicating whether a user is liquidatable.
    /// @param user The user to check.
    function userLiquidatable(address user) public view returns (bool) {
        // Call canBorrow(), passing in a non-existant asset and a borrow amount of 0.
        // This will just check the contract's current state.
        return !canBorrow(address(address(0)), user, 0);
    }

    /// @dev Calculates the total amount of collateral tokens to be seized on liquidation.
    /// @param borrowedAsset The asset borrowed.
    /// @param collateralAsset The asset used as collateral.
    /// @param repayAmount The amount being repaid.
    function seizeCollateral(
        address borrowedAsset,
        address collateralAsset,
        uint256 repayAmount
    ) public view returns (uint256) {
        return 0;
    }
}
