// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IGovernable {
  function governor() external view returns (address);

  function pendingGovernor() external view returns (address);

  function setPendingGovernor(address _pendingGovernor) external;

  function acceptGovernor() external;
}
