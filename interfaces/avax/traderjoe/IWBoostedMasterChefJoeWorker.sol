// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC1155/IERC1155.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

import "../../IERC20Wrapper.sol";
import "./IBoostedMasterChefJoe.sol";

interface IWBoostedMasterChefJoeWorker is IERC1155, IERC20Wrapper {
    /// @dev Mint ERC1155 token for the given ERC20 token.
    function mint(uint256 pid, uint256 amount) external returns (uint256 id);

    /// @dev Burn ERC1155 token to redeem ERC20 token back.
    function burn(uint256 id, uint256 amount) external returns (uint256 pid);

    function joe() external view returns (IERC20);

    function accJoePerShare() external view returns (uint256);

    function decodeId(uint256 id) external pure returns (uint256, uint256);

    function chef() external view returns (IBoostedMasterChefJoe);

    function lpToken() external view returns (address);

    function chefPoolId() external view returns (uint256);

    function recover(address token, uint256 amount) external;

    function recoverETH(uint256 amount) external;

    function setPendingGovernor(address newOwner) external;

    function acceptGovernor() external;

    function governor() external view returns (address);
}
