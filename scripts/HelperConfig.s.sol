// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address lendingPool;
        address messageRelay;
        address priceOracle;
        address interesRateModel;
        address weth;
        address usdc;
        uint256 deployerKey;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 16) {
            activeNetworkConfig = getFlareConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            lendingPool: 0x84bcB82A356d45D5c6BD91857aA6a3E933Fa82a5,
            messageRelay: 0x7e9E04C1D3209e62F3950F135Af474B1D3210d3d,
            priceOracle: 0xA60654A5569a89630b270A581D81645417764682, // ETH / USD
            interesRateModel: 0xD06A506eFB54bbFE13f7fc0De1e86717902EB59A,
            weth: 0x65d6a4ee7b2a807993b7014247428451aE11a471,
            usdc: 0x47d8BAC6C022CaC838f814A67e2d7A0344580D6D,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getFlareConfig() public view returns (NetworkConfig memory flareNetworkConfig) {
        flareNetworkConfig = NetworkConfig({
            lendingPool: 0x453EEbe51c3A91dbdE0DAc2858A7BFe97dC09027,
            messageRelay: 0x6e32F10eae10687f0A278A9E20e3802E0bB0943a,
            priceOracle: 0x9bc96047C57154B455d68aFbc0c5e6Fed573184B, // ETH / USD
            interesRateModel: 0x4FbFF7A75A97E02a168526464968A591e5Ec77c1,
            weth: 0xc89b59096964e48c6A1456c08a94D6b2A0f6Fa5B,
            usdc: 0x013bbC069FdD066009e0701Fe9969d4dDf3c7e4E,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {}
}
