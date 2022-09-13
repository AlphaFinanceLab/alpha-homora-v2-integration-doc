// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import './IBank.sol';

interface IBankFTM is IBank {
  struct CreditLimit {
    address user; // The whitelisted user address to set credit limit.
    address token; // The token address to set credit limit.
    uint limit; // The maximum token amount that can be borrowed (interest included).
  }

  /// @dev Set credit limits for users and tokens. Must be call by the governor.
  /// @param _creditLimits The credit Limits to set (including user, token, address).
  function setCreditLimits(CreditLimit[] calldata _creditLimits) external;
}
