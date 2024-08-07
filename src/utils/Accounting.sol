// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IERC20} from "../Interfaces/IERC20.sol";
import {InterestRateModel} from "../Interfaces/IIRM.sol";

import {Configuration} from "./Configuration.sol";
import {InternalPriceOracle} from "./InternalPriceOracle.sol";

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

abstract contract Accounting is Configuration, InternalPriceOracle {
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                        LIQUIDITY ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of underlying tokens held by and owed to the pool.
    /// @param asset The underlying asset.
    function totalUnderlying(address asset) public view returns (uint256) {
        // Return the total amount of underlying tokens in the pool.
        // This includes the LendingPool's currently held assets and all of the assets being borrowed.

        return availableLiquidity[asset] + totalBorrows(asset);
    }

    // /// @notice Returns the amount of underlying tokens held in this contract.
    // /// @param asset The underlying asset.
    // function availableLiquidity(address asset) public view returns (uint256) {
    //     // TODO: Return the LendingPool's underlying balance in the designated ERC4626 vault.
    //     // ERC4626 vault = vaults[asset];
    //     // return vault.convertToAssets(vault.balanceOf(address(this)));
    //     // return IERC20(asset).balanceOf(address(this));
    // }

    /*///////////////////////////////////////////////////////////////
                        BALANCE ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the underlying balance of an address.
    /// @param asset The underlying asset.
    /// @param user The user to get the underlying balance of.
    function balanceOf(address asset, address user) public view returns (uint256) {
        // Multiply the user's internal balance units by the internal exchange rate of the asset.

        if (internalBalances[asset][user] == 0) return 0;

        return internalBalances[asset][user].mulDivDown(internalBalanceExchangeRate(asset), baseUnits[asset]);
    }

    /// @dev Returns the exchange rate between underlying tokens and internal balance units.
    /// In other words, this function returns the value of one internal balance unit, denominated in underlying.
    function internalBalanceExchangeRate(address asset) internal view returns (uint256) {
        // Retrieve the total internal balance supply.
        uint256 totalInternalBalance = totalInternalBalances[asset];

        // If it is 0, return an exchange rate of 1.
        if (totalInternalBalance == 0) return baseUnits[asset];

        // Otherwise, divide the total supplied underlying by the total internal balance units.
        return totalUnderlying(asset).mulDivDown(baseUnits[asset], totalInternalBalance);
    }

    /*///////////////////////////////////////////////////////////////
                          DEBT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the underlying borrow balance of an address.
    /// @param asset The underlying asset.
    /// @param user The user to get the underlying borrow balance of.
    function borrowBalance(address asset, address user) public view returns (uint256) {
        if (internalDebt[asset][user] == 0) return 0;

        // Multiply the user's internal debt units by the internal debt exchange rate of the asset.
        return internalDebt[asset][user].mulDivDown(internalDebtExchangeRate(asset), baseUnits[asset]);
    }

    /// @dev Returns the exchange rate between underlying tokens and internal debt units.
    /// In other words, this function returns the value of one internal debt unit, denominated in underlying.
    function internalDebtExchangeRate(address asset) internal view returns (uint256) {
        // Retrieve the total debt balance supply.
        uint256 totalInternalDebtUnits = totalInternalDebt[asset];

        // If it is 0, return an exchange rate of 1.
        if (totalInternalDebtUnits == 0) return baseUnits[asset];

        // Otherwise, divide the total borrowed underlying by the total amount of internal debt units.
        return totalBorrows(asset).mulDivDown(baseUnits[asset], totalInternalDebtUnits);
    }

    /*///////////////////////////////////////////////////////////////
                        INTEREST ACCRUAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the total amount of underlying tokens being loaned out to borrowers.
    /// @param asset The underlying asset.
    function totalBorrows(address asset) public view returns (uint256) {
        // Retrieve the Interest Rate Model for this asset.
        InterestRateModel interestRateModel = InterestRateModel(interestRateModels[asset]);

        // Ensure the IRM has been set.
        require(address(interestRateModel) != address(0), "INTEREST_RATE_MODEL_NOT_SET");

        // Calculate the LendingPool's current underlying balance.
        // We cannot use totalUnderlying() here, as it calls this function,
        // leading to an infinite loop.
        uint256 underlying = availableLiquidity[asset] + cachedTotalBorrows[asset];

        // Retrieve the per-block interest rate from the IRM.
        uint256 interestRate = interestRateModel.getBorrowRate(underlying, cachedTotalBorrows[asset], 0);

        // Calculate the block number delta between the last accrual and the current block.
        uint256 blockDelta = block.number - lastInterestAccrual[asset];

        // If the delta is equal to the block number (a borrow/repayment has never occured)
        // return a value of 0.
        if (blockDelta == block.number) return cachedTotalBorrows[asset];

        // Calculate the interest accumulator.
        uint256 interestAccumulator = interestRate.rpow(blockDelta, 1e18);

        // Accrue interest.
        return cachedTotalBorrows[asset].mulWadDown(interestAccumulator);
    }

    /// @dev Update the cached total borrow amount for a given asset.
    /// @param asset The underlying asset.
    function accrueInterest(address asset) internal {
        // Set the cachedTotalBorrows to the total borrow amount.
        cachedTotalBorrows[asset] = totalBorrows(asset);

        // Update the block number of the last interest accrual.
        lastInterestAccrual[asset] = block.number;
    }

    /*///////////////////////////////////////////////////////////////
                      BORROW ALLOWANCE CHECKS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calculate the health factor of a user after a borrow occurs.
    /// @param asset The underlying asset.
    /// @param user The user to check.
    /// @param amount The amount of underlying to borrow.
    function calculateHealthFactor(address asset, address user, uint256 amount) public view returns (uint256) {
        // Allocate memory to store the user's account liquidity.
        AccountLiquidity memory liquidity;

        // Retrieve the user's utilized assets.
        address[] memory utilized = userCollateral[user];

        // User's hyptothetical borrow balance.
        uint256 hypotheticalBorrowBalance;

        address currentAsset;

        // Iterate through the user's utilized assets.
        for (uint256 i = 0; i < utilized.length; i++) {
            // Current user utilized asset.
            currentAsset = utilized[i];

            uint256 assetPrice = getAssetPrice(currentAsset);

            // Calculate the user's maximum borrowable value for this asset.
            // balanceOfUnderlying(asset,user) * ethPrice * collateralFactor.
            liquidity.maximumBorrowable += balanceOf(currentAsset, user).mulDivDown(assetPrice, baseUnits[currentAsset])
                .mulDivDown(configurations[currentAsset].lendFactor, 1e18);

            // Check if current asset == underlying asset.
            hypotheticalBorrowBalance = currentAsset == asset ? amount : 0;

            // Calculate the user's hypothetical borrow balance for this asset.
            if (internalDebt[currentAsset][msg.sender] > 0) {
                hypotheticalBorrowBalance += borrowBalance(currentAsset, user);
            }

            // Add the user's borrow balance in this asset to their total borrow balance.
            liquidity.borrowBalance += hypotheticalBorrowBalance.mulDivDown(assetPrice, baseUnits[currentAsset]);

            // Multiply the user's borrow balance in this asset by the borrow factor.
            liquidity.borrowBalancesTimesBorrowFactors += hypotheticalBorrowBalance.mulDivDown(
                assetPrice, baseUnits[currentAsset]
            ).mulWadDown(configurations[currentAsset].borrowFactor);
        }

        // Calculate the user's actual borrowable value.
        uint256 actualBorrowable = liquidity.borrowBalancesTimesBorrowFactors.divWadDown(liquidity.borrowBalance)
            .mulWadDown(liquidity.maximumBorrowable);

        // Return whether the user's hypothetical borrow value is
        // less than or equal to their borrowable value.
        return actualBorrowable.divWadDown(liquidity.borrowBalance);
    }

    /// @dev Identify whether a user is able to execute a borrow.
    /// @param asset The underlying asset.
    /// @param user The user to check.
    /// @param amount The amount of underlying to borrow.
    function canBorrow(address asset, address user, uint256 amount) public view returns (bool) {
        // Ensure the user's health factor will be greater than 1.

        return calculateHealthFactor(asset, user, amount) >= 1e18;
    }

    /// @dev Given user's collaterals, calculate the maximum user can borrow.
    function maxBorrowable() external view returns (uint256 maximumBorrowable) {
        // Retrieve the user's utilized assets.
        address[] memory utilized = userCollateral[msg.sender];

        address currentAsset;

        // Iterate through the user's utilized assets.
        for (uint256 i = 0; i < utilized.length; i++) {
            // Current user utilized asset.
            currentAsset = utilized[i];

            uint256 assetPrice = getAssetPrice(currentAsset);

            // Calculate the user's maximum borrowable value for this asset.
            // balanceOfUnderlying(asset,user) * ethPrice * lendFactor.
            maximumBorrowable += balanceOf(currentAsset, msg.sender).mulDivDown(assetPrice, baseUnits[currentAsset])
                .mulDivDown(configurations[currentAsset].lendFactor, 1e18);
        }
    }

    /// @dev Get all user collateral assets.
    /// @param user The user.
    function getCollateral(address user) external view returns (address[] memory) {
        return userCollateral[user];
    }

    /*///////////////////////////////////////////////////////////////
                          LIQUIDATION INTERFACE
    //////////////////////////////////////////////////////////////*/

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
    function seizeCollateral(address borrowedAsset, address collateralAsset, uint256 repayAmount)
        public
        view
        returns (uint256)
    {
        // TODO: Implement desired liquidation logic.

        return 0;
    }
}
