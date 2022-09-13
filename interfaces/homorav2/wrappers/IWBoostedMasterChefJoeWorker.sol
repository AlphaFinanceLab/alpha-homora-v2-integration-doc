// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC1155/IERC1155.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';

import '../../traderjoe/IBoostedMasterChefJoe.sol';
import '../IERC20Wrapper.sol';
import '../IGovernable.sol';

interface IWBoostedMasterChefJoeWorker is IERC1155, IERC20Wrapper, IGovernable {
  /// @dev Return TraderJoe masterChef
  function chef() external view returns (IBoostedMasterChefJoe);

  /// @dev Return TraderJoe token
  function joe() external view returns (IERC20);

  /// @dev Return the current accrue joe per share in this contract
  function accJoePerShare() external view returns (uint);

  /// @dev Return pool id supported in this contract
  function chefPoolId() external view returns (uint);

  /// @dev Return lp token of `chefPoolId`
  function lpToken() external view returns (address);

  /// @dev Encode pid, joePerShare to ERC1155 token id
  /// @param pid Pool id (16-bit)
  /// @param joePerShare Joe amount per share, multiplied by 1e18 (240-bit)
  function encodeId(uint pid, uint joePerShare) external pure returns (uint id);

  /// @dev Decode ERC1155 token id to pid, joePerShare
  /// @param id Token id
  function decodeId(uint id) external pure returns (uint pid, uint joePerShare);

  /// @dev Return the underlying ERC-20 for the given ERC-1155 token id.
  function getUnderlyingToken(uint) external view override returns (address);

  /// @dev Return the conversion rate from ERC-1155 to ERC-20, multiplied by 2**112.
  function getUnderlyingRate(uint) external pure override returns (uint);

  /// @dev Mint ERC1155 token for the given ERC20 token.
  /// @param _pid Pool id
  /// @param _amount Token amount to wrap
  function mint(uint _pid, uint _amount) external returns (uint id);

  /// @dev Burn ERC1155 token to redeem ERC20 token back.
  /// @param _id Token id
  /// @param _amount Token amount to burn
  function burn(uint _id, uint _amount) external returns (uint pid);

  function recover(address token, uint amount) external;

  function recoverETH(uint amount) external;
}
