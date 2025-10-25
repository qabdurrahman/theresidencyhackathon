//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EquiAsset
 * @dev ERC20 token contract for EquiNVDA synthetic asset
 * @author EquiNVDA Protocol
 */
contract EquiAsset is ERC20, Ownable {
    // The vault contract that can mint and burn tokens
    address public vault;

    // Events
    event VaultUpdated(address indexed oldVault, address indexed newVault);

    /**
     * @dev Constructor initializes the ERC20 token
     */
    constructor() ERC20("EquiNVDA", "eNVDA") Ownable(msg.sender) {
        // Initial supply is 0, tokens are minted by the vault
    }

    /**
     * @dev Modifier to restrict minting/burning to vault only
     */
    modifier onlyVault() {
        require(msg.sender == vault, "Only vault can call this function");
        _;
    }

    /**
     * @dev Set the vault contract address (owner only)
     * @param _vault Address of the EquiVault contract
     */
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Vault address cannot be zero");
        address oldVault = vault;
        vault = _vault;
        emit VaultUpdated(oldVault, _vault);
    }

    /**
     * @dev Mint tokens to a specific address (vault only)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens from a specific address (vault only)
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyVault {
        _burn(from, amount);
    }

    /**
     * @dev Burn tokens from caller's balance (vault only)
     * @param amount Amount of tokens to burn
     */
    function burnFromVault(address from, uint256 amount) external onlyVault {
        _burn(from, amount);
    }
}
