// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

interface IPriceOraclePlugin {
    function getAssetPrice(address asset) external view returns (uint256 assetPrice);
}
