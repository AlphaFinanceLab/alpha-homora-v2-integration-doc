// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC1155/IERC1155.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

import "../../IERC20Wrapper.sol";
import "./IMiniChefV2PNG.sol";

interface IWMiniChefV2PNG is IERC1155, IERC20Wrapper {
    /// @dev Mint ERC1155 token for the given ERC20 token.
    function mint(uint256 pid, uint256 amount) external returns (uint256 id);

    /// @dev Burn ERC1155 token to redeem ERC20 token back.
    function burn(uint256 id, uint256 amount) external returns (uint256 pid);

    function png() external returns (IERC20);

    function decodeId(uint256 id) external pure returns (uint256, uint256);

    function chef() external view returns (IMiniChefV2PNG);
}
