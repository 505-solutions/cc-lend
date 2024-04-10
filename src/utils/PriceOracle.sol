// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// import {IERC20} from "../Interfaces/IERC20.sol";

import {PriceOracle} from "../Interfaces/IPriceOracle.sol";

abstract contract InternalPriceOracle {
    /// @notice Address of the price oracle contract.
    address public oracle;

    /// @notice Emitted when the price oracle is changed.
    /// @param user The authorized user who triggered the change.
    /// @param newOracle The new price oracle address.
    event OracleUpdated(address indexed user, address indexed newOracle);

    /// @notice Sets a new oracle contract.
    /// @param newOracle The address of the new oracle.
    function setOracle(address newOracle) external {
        // Update the oracle.
        oracle = newOracle;

        // Emit the event.
        emit OracleUpdated(msg.sender, newOracle);
    }

    /// @notice Gets the price of an asset.
    /// @param asset The underlying asset.
    function getAssetPrice(address asset) internal view returns (uint256) {
        return PriceOracle(oracle).getUnderlyingPrice(asset);
    }
}
