//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EquiAsset
 * @dev ERC20 token contract representing synthetic NVDA tokens (EquiNVDA)
 * This token tracks NVIDIA's real-world stock price and can only be minted/burned by the EquiVault
 * @author EquiNVDA Protocol
 */
contract EquiAsset is ERC20, Ownable {
    /// @notice Address of the EquiVault contract that can mint/burn tokens
    address public vault;

    /// @notice Maximum total supply of EquiNVDA tokens (1 billion tokens)
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    /// @notice Event emitted when tokens are minted by the vault
    event TokensMinted(address indexed to, uint256 amount);

    /// @notice Event emitted when tokens are burned by the vault
    event TokensBurned(address indexed from, uint256 amount);

    /**
     * @dev Constructor sets up the ERC20 token with name "EquiNVDA" and symbol "eNVDA"
     * @param _vault Address of the EquiVault contract that will control minting/burning
     */
    constructor(address _vault) ERC20("EquiNVDA", "eNVDA") Ownable(msg.sender) {
        require(_vault != address(0), "EquiAsset: Invalid vault address");
        vault = _vault;
    }

    /**
     * @dev Modifier to restrict minting/burning to only the vault contract
     */
    modifier onlyVault() {
        require(
            msg.sender == vault,
            "EquiAsset: Only vault can call this function"
        );
        _;
    }

    /**
     * @dev Updates the vault address (only owner)
     * @param _newVault New vault address
     */
    function updateVault(address _newVault) external onlyOwner {
        require(_newVault != address(0), "EquiAsset: Invalid vault address");
        vault = _newVault;
    }

    /**
     * @dev Mints EquiNVDA tokens to a specified address
     * Can only be called by the vault contract
     * @param to Address to receive the minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyVault {
        require(to != address(0), "EquiAsset: Cannot mint to zero address");
        require(
            totalSupply() + amount <= MAX_SUPPLY,
            "EquiAsset: Would exceed max supply"
        );

        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Burns EquiNVDA tokens from a specified address
     * Can only be called by the vault contract
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyVault {
        require(from != address(0), "EquiAsset: Cannot burn from zero address");
        require(
            balanceOf(from) >= amount,
            "EquiAsset: Insufficient balance to burn"
        );

        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    /**
     * @dev Override transfer function to add additional checks if needed
     * Currently allows normal ERC20 transfers
     */
    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        return super.transfer(to, amount);
    }

    /**
     * @dev Override transferFrom function to add additional checks if needed
     * Currently allows normal ERC20 transfers
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Returns the number of decimals for the token (18 decimals)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
