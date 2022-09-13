// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC1155/IERC1155.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';

import '../../pangolin/IMiniChefV2PNG.sol';
import '../IERC20Wrapper.sol';
import '../IGovernable.sol';

interface IWMiniChefV2PNG is IERC1155, IERC20Wrapper, IGovernable {
  /// @dev Return Pangolin minichef
  function chef() external view returns (IMiniChefV2PNG);

  /// @dev Return Pangolin token
  function png() external view returns (IERC20);

  /// @dev Encode pid, pngPerShare to ERC1155 token id
  /// @param pid Pool id (16-bit)
  /// @param pngPerShare PNG amount per share, multiplied by 1e18 (240-bit)
  function encodeId(uint pid, uint pngPerShare) external pure returns (uint id);

  /// @dev Decode ERC1155 token id to pid, pngPerShare
  /// @param id Token id
  function decodeId(uint id) external pure returns (uint pid, uint pngPerShare);

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
