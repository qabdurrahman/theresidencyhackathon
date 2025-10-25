//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/EquiVault.sol";
import "../contracts/EquiAsset.sol";
import "../contracts/ChainlinkOracle.sol";
import "./MockAggregatorV3.sol";

/**
 * @title EquiVaultTest
 * @dev Comprehensive test suite for EquiNVDA Protocol
 * @author EquiNVDA Protocol
 */
contract EquiVaultTest is Test {
    // Contracts
    EquiVault public vault;
    EquiAsset public equiAsset;
    ChainlinkOracle public oracle;
    MockAggregatorV3 public mockEthUsdFeed;

    // Test addresses
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public liquidator = address(0x3);
    address public owner = address(0x4);

    // Test constants
    int256 public constant INITIAL_NVDA_PRICE = 450e8; // $450 with 8 decimals
    int256 public constant INITIAL_ETH_PRICE = 2000e8; // $2000 with 8 decimals

    function setUp() public {
        // Deploy contracts
        vm.startPrank(owner);

        mockEthUsdFeed = new MockAggregatorV3(INITIAL_ETH_PRICE);
        equiAsset = new EquiAsset();
        oracle = new ChainlinkOracle(
            address(mockEthUsdFeed),
            INITIAL_NVDA_PRICE
        );
        vault = new EquiVault(address(equiAsset), address(oracle));

        // Set vault in token contract
        equiAsset.setVault(address(vault));

        vm.stopPrank();

        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(liquidator, 10 ether);
    }

    function testInitialState() public {
        assertEq(vault.MIN_COLLATERAL_RATIO(), 500);
        assertEq(vault.LIQUIDATION_THRESHOLD(), 130);
        assertEq(vault.LIQUIDATION_PENALTY(), 10);
        assertEq(address(vault.equiAsset()), address(equiAsset));
        assertEq(address(vault.oracle()), address(oracle));
        assertEq(equiAsset.name(), "EquiNVDA");
        assertEq(equiAsset.symbol(), "eNVDA");
    }

    function testDepositCollateral() public {
        uint256 depositAmount = 1 ether;

        vm.prank(user1);
        vault.depositCollateral{value: depositAmount}();

        (
            uint256 collateralBalance,
            uint256 debtAmount,
            uint256 collateralRatio,
            bool exists
        ) = vault.getVaultData(user1);

        assertEq(collateralBalance, depositAmount);
        assertEq(debtAmount, 0);
        assertEq(collateralRatio, type(uint256).max); // Infinite ratio with no debt
        assertTrue(exists);
        assertEq(vault.totalCollateral(), depositAmount);
    }

    function testWithdrawCollateral() public {
        uint256 depositAmount = 2 ether;
        uint256 withdrawAmount = 1 ether;

        // Deposit collateral
        vm.prank(user1);
        vault.depositCollateral{value: depositAmount}();

        // Withdraw collateral
        vm.prank(user1);
        vault.withdrawCollateral(withdrawAmount);

        (uint256 collateralBalance, , , ) = vault.getVaultData(user1);
        assertEq(collateralBalance, depositAmount - withdrawAmount);
        assertEq(vault.totalCollateral(), depositAmount - withdrawAmount);
    }

    function testWithdrawCollateralWithDebt() public {
        uint256 depositAmount = 2 ether;
        uint256 mintAmount = 8e17; // 4 eNVDA tokens

        // Deposit and mint
        vm.prank(user1);
        vault.depositCollateral{value: depositAmount}();

        vm.prank(user1);
        vault.mintEquiNVDA(mintAmount);

        // Try to withdraw too much collateral (should fail)
        vm.prank(user1);
        vm.expectRevert("Would violate minimum collateral ratio");
        vault.withdrawCollateral(1.5 ether);

        // Withdraw small amount (should succeed)
        vm.prank(user1);
        vault.withdrawCollateral(0.1 ether);

        (uint256 collateralBalance, , , ) = vault.getVaultData(user1);
        assertEq(collateralBalance, depositAmount - 0.1 ether);
    }

    function testMintEquiNVDA() public {
        uint256 depositAmount = 1 ether;
        uint256 mintAmount = 8e17; // 0.8 eNVDA tokens (worth $360 at $450 each)

        // Deposit collateral
        vm.prank(user1);
        vault.depositCollateral{value: depositAmount}();

        // Mint tokens
        vm.prank(user1);
        vault.mintEquiNVDA(mintAmount);

        assertEq(equiAsset.balanceOf(user1), mintAmount);
        assertEq(vault.totalDebt(), mintAmount);

        (
            uint256 collateralBalance,
            uint256 debtAmount,
            uint256 collateralRatio,

        ) = vault.getVaultData(user1);
        assertEq(collateralBalance, depositAmount);
        assertEq(debtAmount, mintAmount);
        assertTrue(collateralRatio >= vault.MIN_COLLATERAL_RATIO());
    }

    function testMintEquiNVDAExceedsRatio() public {
        uint256 depositAmount = 1 ether;
        uint256 mintAmount = 9e17; // Too many tokens (would exceed 500% CR)

        // Deposit collateral
        vm.prank(user1);
        vault.depositCollateral{value: depositAmount}();

        // Try to mint too many tokens (should fail)
        vm.prank(user1);
        vm.expectRevert("Would violate minimum collateral ratio");
        vault.mintEquiNVDA(mintAmount);
    }

    function testRedeemCollateral() public {
        uint256 depositAmount = 1 ether;
        uint256 mintAmount = 8e17;
        uint256 redeemAmount = 4e17; // 0.4 eNVDA tokens

        // Deposit, mint, then redeem
        vm.prank(user1);
        vault.depositCollateral{value: depositAmount}();

        vm.prank(user1);
        vault.mintEquiNVDA(mintAmount);

        uint256 initialBalance = user1.balance;

        vm.prank(user1);
        vault.redeemCollateral(redeemAmount);

        assertEq(equiAsset.balanceOf(user1), mintAmount - redeemAmount);
        assertEq(vault.totalDebt(), mintAmount - redeemAmount);

        // Check that ETH was returned
        assertTrue(user1.balance > initialBalance);
    }

    function testLiquidation() public {
        uint256 depositAmount = 1 ether;
        uint256 mintAmount = 8e17;

        // User1 deposits and mints
        vm.prank(user1);
        vault.depositCollateral{value: depositAmount}();

        vm.prank(user1);
        vault.mintEquiNVDA(mintAmount);

        // Simulate price drop by updating mock NVDA price
        vm.prank(owner);
        oracle.updateMockPrice(2000e8); // Price drops to $2000 (4.4x increase)

        // Check that vault is now liquidatable
        uint256 collateralRatio = vault.getCollateralRatio(user1);
        assertTrue(collateralRatio < vault.LIQUIDATION_THRESHOLD());

        // Liquidator needs eNVDA tokens to liquidate
        vm.prank(user1);
        equiAsset.transfer(liquidator, mintAmount);

        uint256 liquidatorInitialBalance = liquidator.balance;

        // Execute liquidation
        vm.prank(liquidator);
        vault.liquidate(user1);

        // Check liquidation results
        assertTrue(liquidator.balance > liquidatorInitialBalance);
        assertEq(equiAsset.balanceOf(liquidator), 0); // Tokens burned
        assertEq(vault.totalDebt(), 0);

        (uint256 collateralBalance, uint256 debtAmount, , bool exists) = vault
            .getVaultData(user1);
        assertEq(debtAmount, 0);
        assertTrue(collateralBalance < depositAmount); // Some collateral taken as penalty
        assertTrue(exists); // Vault still exists with remaining collateral
    }

    function testLiquidationNotAllowed() public {
        uint256 depositAmount = 1 ether;
        uint256 mintAmount = 8e17;

        // User1 deposits and mints
        vm.prank(user1);
        vault.depositCollateral{value: depositAmount}();

        vm.prank(user1);
        vault.mintEquiNVDA(mintAmount);

        // Vault should not be liquidatable at current prices
        uint256 collateralRatio = vault.getCollateralRatio(user1);
        assertTrue(collateralRatio >= vault.LIQUIDATION_THRESHOLD());

        // Try to liquidate (should fail)
        vm.prank(liquidator);
        vm.expectRevert("Vault not liquidatable");
        vault.liquidate(user1);
    }

    function testSelfLiquidationNotAllowed() public {
        uint256 depositAmount = 1 ether;
        uint256 mintAmount = 8e17;

        // User1 deposits and mints
        vm.prank(user1);
        vault.depositCollateral{value: depositAmount}();

        vm.prank(user1);
        vault.mintEquiNVDA(mintAmount);

        // Simulate price drop
        vm.prank(owner);
        oracle.updateMockPrice(900e8);

        // Try to liquidate self (should fail)
        vm.prank(user1);
        vm.expectRevert("Cannot liquidate yourself");
        vault.liquidate(user1);
    }

    function testOraclePriceUpdates() public {
        int256 newPrice = 500e8;

        vm.prank(owner);
        oracle.updateMockPrice(newPrice);

        assertEq(oracle.getNvdaUsdPrice(), newPrice);
    }

    function testOraclePriceFluctuation() public {
        int256 initialPrice = oracle.getNvdaUsdPrice();

        vm.prank(owner);
        oracle.simulatePriceFluctuation(100); // Max 1% change

        int256 newPrice = oracle.getNvdaUsdPrice();
        assertTrue(newPrice != initialPrice);
        assertTrue(newPrice > 0);
    }

    function testEndToEndFlow() public {
        uint256 depositAmount = 1 ether;
        uint256 mintAmount = 8e17;

        // 1. Deposit collateral
        vm.prank(user1);
        vault.depositCollateral{value: depositAmount}();

        // 2. Mint synthetic tokens
        vm.prank(user1);
        vault.mintEquiNVDA(mintAmount);

        // 3. Simulate price drop
        vm.prank(owner);
        oracle.updateMockPrice(2000e8);

        // 4. Transfer tokens to liquidator
        vm.prank(user1);
        equiAsset.transfer(liquidator, mintAmount);

        // 5. Execute liquidation
        vm.prank(liquidator);
        vault.liquidate(user1);

        // 6. Verify final state
        assertEq(vault.totalDebt(), 0);
        assertTrue(vault.totalCollateral() < depositAmount); // Some taken as penalty
        assertEq(equiAsset.balanceOf(liquidator), 0);

        (uint256 collateralBalance, uint256 debtAmount, , bool exists) = vault
            .getVaultData(user1);
        assertEq(debtAmount, 0);
        assertTrue(collateralBalance > 0); // Some collateral remains
        assertTrue(exists);
    }

    function testMultipleUsers() public {
        uint256 depositAmount1 = 1 ether;
        uint256 depositAmount2 = 1.5 ether;
        uint256 mintAmount1 = 8e17;
        uint256 mintAmount2 = 12e17; // 1.2 eNVDA tokens

        // User1 operations
        vm.prank(user1);
        vault.depositCollateral{value: depositAmount1}();

        vm.prank(user1);
        vault.mintEquiNVDA(mintAmount1);

        // User2 operations
        vm.prank(user2);
        vault.depositCollateral{value: depositAmount2}();

        vm.prank(user2);
        vault.mintEquiNVDA(mintAmount2);

        // Check totals
        assertEq(vault.totalCollateral(), depositAmount1 + depositAmount2);
        assertEq(vault.totalDebt(), mintAmount1 + mintAmount2);

        // Check individual vaults
        (uint256 collateral1, uint256 debt1, , ) = vault.getVaultData(user1);
        (uint256 collateral2, uint256 debt2, , ) = vault.getVaultData(user2);

        assertEq(collateral1, depositAmount1);
        assertEq(debt1, mintAmount1);
        assertEq(collateral2, depositAmount2);
        assertEq(debt2, mintAmount2);
    }

    function testRevertCases() public {
        // Test deposit with zero amount
        vm.prank(user1);
        vm.expectRevert("Must deposit ETH");
        vault.depositCollateral{value: 0}();

        // Test withdraw with zero amount
        vm.prank(user1);
        vm.expectRevert("Amount must be positive");
        vault.withdrawCollateral(0);

        // Test mint with zero amount
        vm.prank(user1);
        vm.expectRevert("Amount must be positive");
        vault.mintEquiNVDA(0);

        // Test mint without collateral
        vm.prank(user1);
        vm.expectRevert("No collateral deposited");
        vault.mintEquiNVDA(1000e18);

        // Test redeem without debt
        vm.prank(user1);
        vault.depositCollateral{value: 1 ether}();

        vm.prank(user1);
        vm.expectRevert("Insufficient debt to redeem");
        vault.redeemCollateral(1000e18);
    }
}
