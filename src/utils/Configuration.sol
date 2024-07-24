// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./MainStorage.sol";

import {PriceOraclePlugin} from "../PriceOraclePlugin.sol";

import {IERC20} from "../Interfaces/IERC20.sol";
import {InterestRateModel} from "../Interfaces/IIRM.sol";

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract Configuration is MainStorage, OwnableUpgradeable {
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    function setMessageRelay(address relay) public onlyOwner {
        s_messageRelay = relay;
    }

    function setPriceOraclePlugin(address _plugin) public onlyOwner {
        priceOraclePlugin = _plugin;
    }

    /*///////////////////////////////////////////////////////////////
                          INTEREST RATE CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets a new Interest Rate Model for a specfic asset.
    /// @param asset The underlying asset.
    /// @param newInterestRateModel The new IRM address.
    function setInterestRateModel(address asset, address newInterestRateModel) external onlyOwner {
        // Update the asset's Interest Rate Model.
        interestRateModels[asset] = newInterestRateModel;

        // Emit the event.
        emit InterestRateModelUpdated(msg.sender, asset, newInterestRateModel);
    }

    /// @notice Adds a new asset to the pool.
    /// @param asset The underlying asset.
    /// @param counterpart The address of the asset on the other chain.
    /// @param lendFactor The lend factor for the asset.
    /// @param borrowFactor The borrow factor for the asset.
    /// @param ftsoIndex The ftso index used to get the price of the asset.
    /// @param isWeth If the asset is WETH.
    function configureAsset(
        address asset,
        address counterpart,
        uint256 lendFactor,
        uint256 borrowFactor,
        uint256 ftsoIndex,
        address isWeth
    ) external onlyOwner {
        // Ensure that this asset has not been configured.
        require(
            configurations[asset].borrowFactor == 0 && configurations[asset].lendFactor == 0, "ASSET_ALREADY_CONFIGURED"
        );

        Configuration memory configuration = Configuration(lendFactor, borrowFactor);

        configurations[asset] = configuration;
        baseUnits[asset] = 10 ** IERC20(asset).decimals();

        fromAssetCounterpart[counterpart] = asset;

        s_assetFtsoIndex[asset] = _ftsoIndex;

        if (isWeth) {
            s_wethAddress = asset;
        }

        // Emit the event.
        emit AssetConfigured(asset, configuration);
    }

    /// @notice Updates the lend/borrow factors of an asset.
    /// @param asset The underlying asset.
    /// @param newConfiguration The new lend/borrow factors for the asset.
    function updateConfiguration(address asset, Configuration memory newConfiguration) external onlyOwner {
        // Update the asset configuration.
        configurations[asset] = newConfiguration;

        // Emit the event.
        emit AssetConfigurationUpdated(asset, newConfiguration);
    }

    /*///////////////////////////////////////////////////////////////
                      COLLATERALIZATION INTERFACE
    //////////////////////////////////////////////////////////////*/

    /// @notice Enable an asset as collateral.
    function enableAsset(address asset) public {
        _enableAsset(asset, msg.sender);
    }

    function _enableAsset(address asset, address depositor) internal {
        // Ensure the user has not enabled this asset as collateral.
        if (enabledCollateral[depositor][asset]) {
            return;
        }

        // Enable the asset as collateral.
        userCollateral[depositor].push(asset);
        enabledCollateral[depositor][asset] = true;

        // Emit the event.
        emit AssetEnabled(depositor, asset);
    }

    /// @notice Disable an asset as collateral.
    function disableAsset(address asset) public {
        _disableAsset(asset, msg.sender);
    }

    function _disableAsset(address asset, address depositor) internal {
        // Ensure that the user is not borrowing this asset.
        if (internalDebt[asset][depositor] > 0) return;

        // Ensure the user has already enabled this asset as collateral.
        if (!enabledCollateral[depositor][asset]) return;

        // Remove the asset from the user's list of collateral.
        for (uint256 i = 0; i < userCollateral[depositor].length; i++) {
            if (userCollateral[depositor][i] == asset) {
                // Copy the value of the last element in the array.
                address last = userCollateral[depositor][userCollateral[depositor].length - 1];

                // Remove the last element from the array.
                delete userCollateral[depositor][
                    userCollateral[depositor].length - 1
                ];

                // Replace the disabled asset with the new asset.
                userCollateral[depositor][i] = last;
            }
        }

        // Disable the asset as collateral.
        enabledCollateral[depositor][asset] = false;

        // Emit the event.
        emit AssetDisabled(depositor, asset);
    }
}
