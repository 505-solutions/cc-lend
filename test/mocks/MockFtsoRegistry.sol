// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/// @title Mock Price Oracle
/// @dev This contract is used to replicate a Price Oracle contract
/// for unit tests.
contract MockFtsoRegistry {
    mapping(uint256 => uint256) public prices;
    mapping(uint256 => uint256) public assetDecimals;

    function updatePrice(uint256 assetIndex, uint256 price, uint256 decimals) external {
        prices[assetIndex] = price;
        assetDecimals[assetIndex] = decimals;
    }

    function getCurrentPriceWithDecimals(uint256 _assetIndex)
        public
        view
        returns (uint256 _price, uint256 _timestamp, uint256 _assetPriceUsdDecimals)
    {
        return (prices[_assetIndex], block.timestamp, assetDecimals[_assetIndex]);
    }
}

// function getCurrentPriceWithDecimals(uint256 _assetIndex)
//         external
//         view
//         returns (uint256 _price, uint256 _timestamp, uint256 _assetPriceUsdDecimals);
