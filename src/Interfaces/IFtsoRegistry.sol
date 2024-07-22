// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;
pragma abicoder v2;

interface IFtsoRegistry {
    struct PriceInfo {
        uint256 ftsoIndex;
        uint256 price;
        uint256 decimals;
        uint256 timestamp;
    }

    function getSupportedIndices() external view returns (uint256[] memory _supportedIndices);
    function getSupportedSymbols() external view returns (string[] memory _supportedSymbols);
    function getFtsoIndex(string memory _symbol) external view returns (uint256 _assetIndex);
    function getFtsoSymbol(uint256 _ftsoIndex) external view returns (string memory _symbol);
    function getCurrentPrice(uint256 _ftsoIndex) external view returns (uint256 _price, uint256 _timestamp); // ! This is the function that we need to call
    function getCurrentPrice(string memory _symbol) external view returns (uint256 _price, uint256 _timestamp);
    function getCurrentPriceWithDecimals(uint256 _assetIndex)
        external
        view
        returns (uint256 _price, uint256 _timestamp, uint256 _assetPriceUsdDecimals);
    function getCurrentPriceWithDecimals(string memory _symbol)
        external
        view
        returns (uint256 _price, uint256 _timestamp, uint256 _assetPriceUsdDecimals);

    function getAllCurrentPrices() external view returns (PriceInfo[] memory);
    function getCurrentPricesByIndices(uint256[] memory _indices) external view returns (PriceInfo[] memory);
    function getCurrentPricesBySymbols(string[] memory _symbols) external view returns (PriceInfo[] memory);
}
