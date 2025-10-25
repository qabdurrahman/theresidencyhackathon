//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import "../contracts/EquiVault.sol";
import "../contracts/EquiAsset.sol";
import "../contracts/ChainlinkOracle.sol";

/**
 * @title DeployEquiNVDA
 * @dev Deployment script for EquiNVDA Protocol
 * @author EquiNVDA Protocol
 */
contract DeployEquiNVDA is Script {
    // Chainlink ETH/USD feed on Sepolia
    address public constant ETH_USD_FEED =
        0x694AA1769357215DE4FAC081bf1f309aDC325306;

    // Initial NVDA price: $450 with 8 decimals
    int256 public constant INITIAL_NVDA_PRICE = 450e8;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy ChainlinkOracle
        ChainlinkOracle oracle = new ChainlinkOracle(
            ETH_USD_FEED,
            INITIAL_NVDA_PRICE
        );
        console.log("ChainlinkOracle deployed at:", address(oracle));

        // Deploy EquiAsset
        EquiAsset equiAsset = new EquiAsset();
        console.log("EquiAsset deployed at:", address(equiAsset));

        // Deploy EquiVault
        EquiVault vault = new EquiVault(address(equiAsset), address(oracle));
        console.log("EquiVault deployed at:", address(vault));

        // Set vault in token contract
        equiAsset.setVault(address(vault));
        console.log("Vault set in EquiAsset contract");

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== EquiNVDA Protocol Deployment Summary ===");
        console.log("ChainlinkOracle:", address(oracle));
        console.log("EquiAsset:", address(equiAsset));
        console.log("EquiVault:", address(vault));
        console.log("ETH/USD Feed:", ETH_USD_FEED);
        console.log("Initial NVDA Price: $450");
        console.log("===========================================");
    }
}
