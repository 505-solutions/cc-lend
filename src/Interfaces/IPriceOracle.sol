// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/// @title Price Oracle Interface.
interface PriceOracle {
    /// @notice Get the price of an asset.
    /// @param asset The address of the underlying asset.
    /// @dev The underlying asset price is scaled by 1e18.
    function getUnderlyingPrice(address asset) external view returns (uint256);
}
