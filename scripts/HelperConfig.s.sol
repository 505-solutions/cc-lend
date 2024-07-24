// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address lendingPool;
        address messageRelay;
        address sourceOracle;
        address interesRateModel;
        address weth;
        address usdc;
        uint256 deployerKey;
    }

    struct CounterAssets {
        address counterWeth;
        address counterUsdc;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;
    CounterAssets public activeCounterAssets;

    address sepoliaWeth = 0x65d6a4ee7b2a807993b7014247428451aE11a471;
    address sepoliaUsdc = 0x47d8BAC6C022CaC838f814A67e2d7A0344580D6D;

    address flareWeth = 0xc89b59096964e48c6A1456c08a94D6b2A0f6Fa5B;
    address flareUsdc = 0x013bbC069FdD066009e0701Fe9969d4dDf3c7e4E;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
            activeCounterAssets = CounterAssets({counterWeth: flareWeth, counterUsdc: flareUsdc});
        } else if (block.chainid == 16) {
            activeNetworkConfig = getFlareConfig();
            activeCounterAssets = CounterAssets({counterWeth: sepoliaWeth, counterUsdc: sepoliaUsdc});
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            lendingPool: 0x8e43fB9eF1075D0d93674943A5F81273c77FF5D5,
            messageRelay: 0x7e9E04C1D3209e62F3950F135Af474B1D3210d3d,
            sourceOracle: 0xc106b5332b9A5b964eE3F6fED6F857C8675dc8e9,
            interesRateModel: 0xD06A506eFB54bbFE13f7fc0De1e86717902EB59A,
            weth: sepoliaWeth,
            usdc: sepoliaUsdc,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getFlareConfig() public view returns (NetworkConfig memory flareNetworkConfig) {
        flareNetworkConfig = NetworkConfig({
            lendingPool: 0x6B88EA6C6A9aad3a0E1119af1B098B9630a875CE,
            messageRelay: 0xa80ea62d1f5bBD985d20e18FA0bb46EE75A8a8d8,
            sourceOracle: 0xf7Bbf40145C82Fca13011C783AaeCa6bD95fd652,
            interesRateModel: 0x950474a968e62133423494b9Ee5A96b27843D4cA,
            weth: flareWeth,
            usdc: flareUsdc,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getEvmTxVerifier() public view returns (address) {
        if (block.chainid == 11155111) {
            return address(0);
        } else if (block.chainid == 16) {
            return 0xf37AD1278917c04fb291C75a42e61710964Cb57c;
        }

        return address(0);
    }

    function getCounterPartAssetAddresses() public view returns (address) {
        if (block.chainid == 11155111) {
            return address(0);
        } else if (block.chainid == 16) {
            return 0xf37AD1278917c04fb291C75a42e61710964Cb57c;
        }

        return address(0);
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {}
}
