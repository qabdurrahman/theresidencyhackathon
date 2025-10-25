"use client";

import { useState } from "react";
import { useEquiNVDA } from "../hooks/scaffold-eth/useEquiNVDA";

export default function EquiNVDAInterface() {
  const [depositAmount, setDepositAmount] = useState("");
  const [mintAmount, setMintAmount] = useState("");
  const [redeemAmount, setRedeemAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [liquidateAddress, setLiquidateAddress] = useState("");
  const [newPrice, setNewPrice] = useState("");

  const {
    vaultData,
    prices,
    ethBalance,
    tokenBalance,
    maxMintable,
    isDepositing,
    isMinting,
    isRedeeming,
    isWithdrawing,
    isLiquidating,
    isUpdatingPrice,
    depositSuccess,
    mintSuccess,
    redeemSuccess,
    withdrawSuccess,
    liquidationSuccess,
    priceUpdateSuccess,
    depositError,
    mintError,
    redeemError,
    withdrawError,
    liquidationError,
    priceUpdateError,
    deposit,
    mint,
    redeem,
    withdraw,
    liquidateUser,
    updatePrice,
    calculateMaxMintable,
  } = useEquiNVDA();

  const handleDeposit = async () => {
    if (!depositAmount) return;
    try {
      await deposit(depositAmount);
      setDepositAmount("");
    } catch (error) {
      console.error("Deposit error:", error);
    }
  };

  const handleMint = async () => {
    if (!mintAmount) return;
    try {
      await mint(mintAmount);
      setMintAmount("");
    } catch (error) {
      console.error("Mint error:", error);
    }
  };

  const handleRedeem = async () => {
    if (!redeemAmount) return;
    try {
      await redeem(redeemAmount);
      setRedeemAmount("");
    } catch (error) {
      console.error("Redeem error:", error);
    }
  };

  const handleWithdraw = async () => {
    if (!withdrawAmount) return;
    try {
      await withdraw(withdrawAmount);
      setWithdrawAmount("");
    } catch (error) {
      console.error("Withdraw error:", error);
    }
  };

  const handleLiquidate = async () => {
    if (!liquidateAddress) return;
    try {
      await liquidateUser(liquidateAddress);
      setLiquidateAddress("");
    } catch (error) {
      console.error("Liquidation error:", error);
    }
  };

  const handleUpdatePrice = async () => {
    if (!newPrice) return;
    try {
      await updatePrice(Number(newPrice));
      setNewPrice("");
    } catch (error) {
      console.error("Price update error:", error);
    }
  };

  return (
    <div className="container mx-auto p-6 max-w-6xl">
      <div className="text-center mb-8">
        <h1 className="text-4xl font-bold text-primary mb-2">EquiNVDA Protocol</h1>
        <p className="text-lg text-gray-600">Synthetic NVDA tokens backed by ETH collateral</p>
      </div>

      {/* Price Feed Section */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title text-success">ETH/USD Price</h3>
            <p className="text-2xl font-bold">${prices.ethUsdPrice.toFixed(2)}</p>
            <p className="text-sm text-gray-500">Live Chainlink Feed</p>
          </div>
        </div>
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h3 className="card-title text-warning">NVDA/USD Price</h3>
            <p className="text-2xl font-bold">${prices.nvdaUsdPrice.toFixed(2)}</p>
            <p className="text-sm text-gray-500">Mock Oracle</p>
          </div>
        </div>
      </div>

      {/* Vault Status */}
      {vaultData?.exists && (
        <div className="card bg-base-100 shadow-xl mb-8">
          <div className="card-body">
            <h2 className="card-title text-primary">Your Vault Status</h2>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div className="stat">
                <div className="stat-title">Collateral</div>
                <div className="stat-value text-primary">{vaultData.collateralBalance} ETH</div>
                <div className="stat-desc">${(parseFloat(vaultData.collateralBalance) * prices.ethUsdPrice).toFixed(2)}</div>
              </div>
              <div className="stat">
                <div className="stat-title">Debt</div>
                <div className="stat-value text-secondary">{vaultData.debtAmount} eNVDA</div>
                <div className="stat-desc">${(parseFloat(vaultData.debtAmount) * prices.nvdaUsdPrice).toFixed(2)}</div>
              </div>
              <div className="stat">
                <div className="stat-title">Collateral Ratio</div>
                <div className={`stat-value ${
                  vaultData.isLiquidatable ? "text-error" : 
                  vaultData.collateralRatio < 500 ? "text-warning" : 
                  "text-success"
                }`}>
                  {vaultData.collateralRatio.toFixed(1)}%
                </div>
                <div className="stat-desc">
                  {vaultData.isLiquidatable ? "Liquidatable" : 
                   vaultData.collateralRatio < 500 ? "Below 500%" : "Healthy"}
                </div>
              </div>
              <div className="stat">
                <div className="stat-title">Max Mintable</div>
                <div className="stat-value text-info">{maxMintable} eNVDA</div>
                <div className="stat-desc">At 500% ratio</div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Main Actions */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Deposit & Mint */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title text-primary">Deposit & Mint</h2>
            
            {/* Deposit Section */}
            <div className="form-control mb-6">
              <label className="label">
                <span className="label-text">Deposit ETH as Collateral</span>
              </label>
              <div className="flex gap-2">
                <input
                  type="number"
                  placeholder="0.0"
                  className="input input-bordered flex-1"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(e.target.value)}
                />
                <button
                  className="btn btn-primary"
                  onClick={handleDeposit}
                  disabled={isDepositing || !depositAmount}
                >
                  {isDepositing ? "Depositing..." : "Deposit"}
                </button>
              </div>
              {depositError && (
                <p className="text-error text-sm mt-1">Error: {depositError.message}</p>
              )}
              {depositSuccess && (
                <p className="text-success text-sm mt-1">Deposit successful!</p>
              )}
            </div>

            {/* Mint Section */}
            <div className="form-control">
              <label className="label">
                <span className="label-text">Mint eNVDA Tokens</span>
              </label>
              <div className="flex gap-2">
                <input
                  type="number"
                  placeholder="0.0"
                  className="input input-bordered flex-1"
                  value={mintAmount}
                  onChange={(e) => setMintAmount(e.target.value)}
                />
                <button
                  className="btn btn-outline btn-sm"
                  onClick={() => setMintAmount(vaultData?.exists ? maxMintable : (depositAmount ? calculateMaxMintable(depositAmount) : "0"))}
                  disabled={!vaultData?.exists && !depositAmount}
                >
                  Max
                </button>
                <button
                  className="btn btn-secondary"
                  onClick={handleMint}
                  disabled={isMinting || !mintAmount}
                >
                  {isMinting ? "Minting..." : "Mint"}
                </button>
              </div>
              
              {/* Max Mintable Info */}
              {vaultData?.exists && (
                <div className="mt-2 p-3 bg-info/10 rounded-lg">
                  <p className="text-sm">
                    <strong>Max Mintable:</strong> {maxMintable} eNVDA
                  </p>
                  <p className="text-xs text-gray-600">
                    Based on {vaultData.collateralBalance} ETH collateral (500% ratio)
                  </p>
                </div>
              )}
              {!vaultData?.exists && depositAmount && (
                <div className="mt-2 p-3 bg-warning/10 rounded-lg">
                  <p className="text-sm">
                    <strong>If you deposit {depositAmount} ETH:</strong> You could mint up to {calculateMaxMintable(depositAmount)} eNVDA
                  </p>
                  <p className="text-xs text-gray-600">
                    Collateral value: ${(parseFloat(depositAmount) * prices.ethUsdPrice).toFixed(2)} | Max debt: ${(parseFloat(depositAmount) * prices.ethUsdPrice / 5).toFixed(2)}
                  </p>
                </div>
              )}
              
              {mintError && (
                <p className="text-error text-sm mt-1">Error: {mintError.message}</p>
              )}
              {mintSuccess && (
                <p className="text-success text-sm mt-1">Mint successful!</p>
              )}
            </div>
          </div>
        </div>

        {/* Redeem & Withdraw */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title text-secondary">Redeem & Withdraw</h2>
            
            {/* Redeem Section */}
            <div className="form-control mb-6">
              <label className="label">
                <span className="label-text">Redeem eNVDA for ETH</span>
              </label>
              <div className="flex gap-2">
                <input
                  type="number"
                  placeholder="0.0"
                  className="input input-bordered flex-1"
                  value={redeemAmount}
                  onChange={(e) => setRedeemAmount(e.target.value)}
                />
                <button
                  className="btn btn-secondary"
                  onClick={handleRedeem}
                  disabled={isRedeeming || !redeemAmount}
                >
                  {isRedeeming ? "Redeeming..." : "Redeem"}
                </button>
              </div>
              {redeemError && (
                <p className="text-error text-sm mt-1">Error: {redeemError.message}</p>
              )}
              {redeemSuccess && (
                <p className="text-success text-sm mt-1">Redeem successful!</p>
              )}
            </div>

            {/* Withdraw Section */}
            <div className="form-control">
              <label className="label">
                <span className="label-text">Withdraw ETH Collateral</span>
              </label>
              <div className="flex gap-2">
                <input
                  type="number"
                  placeholder="0.0"
                  className="input input-bordered flex-1"
                  value={withdrawAmount}
                  onChange={(e) => setWithdrawAmount(e.target.value)}
                />
                <button
                  className="btn btn-primary"
                  onClick={handleWithdraw}
                  disabled={isWithdrawing || !withdrawAmount}
                >
                  {isWithdrawing ? "Withdrawing..." : "Withdraw"}
                </button>
              </div>
              {withdrawError && (
                <p className="text-error text-sm mt-1">Error: {withdrawError.message}</p>
              )}
              {withdrawSuccess && (
                <p className="text-success text-sm mt-1">Withdraw successful!</p>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Advanced Features */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mt-8">
        {/* Liquidation */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title text-error">Liquidation</h2>
            <p className="text-sm text-gray-600 mb-4">
              Liquidate under-collateralized vaults (CR &lt; 130%)
            </p>
            <div className="form-control">
              <label className="label">
                <span className="label-text">User Address to Liquidate</span>
              </label>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="0x..."
                  className="input input-bordered flex-1"
                  value={liquidateAddress}
                  onChange={(e) => setLiquidateAddress(e.target.value)}
                />
                <button
                  className="btn btn-error"
                  onClick={handleLiquidate}
                  disabled={isLiquidating || !liquidateAddress}
                >
                  {isLiquidating ? "Liquidating..." : "Liquidate"}
                </button>
              </div>
              {liquidationError && (
                <p className="text-error text-sm mt-1">Error: {liquidationError.message}</p>
              )}
              {liquidationSuccess && (
                <p className="text-success text-sm mt-1">Liquidation successful!</p>
              )}
            </div>
          </div>
        </div>

        {/* Price Management */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title text-warning">Price Management</h2>
            <p className="text-sm text-gray-600 mb-4">
              Update mock NVDA price (Owner only)
            </p>
            <div className="form-control">
              <label className="label">
                <span className="label-text">New NVDA Price ($)</span>
              </label>
              <div className="flex gap-2">
                <input
                  type="number"
                  placeholder="450"
                  className="input input-bordered flex-1"
                  value={newPrice}
                  onChange={(e) => setNewPrice(e.target.value)}
                />
                <button
                  className="btn btn-warning"
                  onClick={handleUpdatePrice}
                  disabled={isUpdatingPrice || !newPrice}
                >
                  {isUpdatingPrice ? "Updating..." : "Update"}
                </button>
              </div>
              {priceUpdateError && (
                <p className="text-error text-sm mt-1">Error: {priceUpdateError.message}</p>
              )}
              {priceUpdateSuccess && (
                <p className="text-success text-sm mt-1">Price updated successfully!</p>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* User Balances */}
      <div className="card bg-base-100 shadow-xl mt-8">
        <div className="card-body">
          <h2 className="card-title text-info">Your Balances</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="stat">
              <div className="stat-title">ETH Balance</div>
              <div className="stat-value text-primary">{ethBalance} ETH</div>
            </div>
            <div className="stat">
              <div className="stat-title">eNVDA Balance</div>
              <div className="stat-value text-secondary">{tokenBalance} eNVDA</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}