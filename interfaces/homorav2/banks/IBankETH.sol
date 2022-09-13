// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import './IBank.sol';

interface IBankETH is IBank {
  struct CreditLimit {
    address user; // The whitelisted user address to set credit limit.
    address token; // The token address to set credit limit.
    uint limit; // The maximum token amount that can be borrowed (interest included).
    address origin; // The tx origin of whitelisted user (using for whitelistContractWithTxOrigin).
  }

  /// @dev Return whether `msgSender` can call HomoraBank by `origin` address
  function whitelistedContractWithTxOrigin(address msgSender, address origin)
    external
    returns (bool);

  /// @dev Set whether `contract` can call HomoraBank by `origin` address
  /// @param _contracts list of contracts to set whitelist
  /// @param _origins list of tx origins to whitelist for their corresponding contract addresses
  /// @param _statuses list of statuses to change to
  function setWhitelistContractWithTxOrigin(
    address[] calldata _contracts,
    address[] calldata _origins,
    bool[] calldata _statuses
  ) external;

  /// @dev Set credit limits for users and tokens. Must be call by the governor.
  /// @param _creditLimits The credit Limits to set (including user, token, address).
  function setCreditLimits(CreditLimit[] calldata _creditLimits) external;
}
