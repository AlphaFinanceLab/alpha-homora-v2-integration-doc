// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol';

import '../interfaces/avax/IBankAVAX.sol';

contract BaseIntegration {
  using SafeERC20 for IERC20;

  mapping(address => mapping(address => bool)) public approved; // Mapping from token to (mapping from spender to approve status)

  /// @dev Ensure that the spell has approved the given spender to spend all of its tokens.
  /// @param token The token to approve.
  /// @param spender The spender to allow spending.
  /// NOTE: This is safe because spell is never built to hold fund custody.
  function ensureApprove(address token, address spender) internal {
    if (!approved[token][spender]) {
      IERC20(token).safeApprove(spender, type(uint).max);
      approved[token][spender] = true;
    }
  }

  /// @dev Internal call to refund tokens.
  /// @param token The token to perform the refund action.
  function doRefund(address token) internal {
    uint balance = IERC20(token).balanceOf(address(this));
    if (balance > 0) {
      IERC20(token).safeTransfer(msg.sender, balance);
    }
  }

  /// @dev Internal call to refund all AVAX.
  function doRefundETH() internal {
    uint balance = address(this).balance;
    if (balance > 0) {
      (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
      require(success, 'refund ETH failed');
    }
  }

  /// @dev Fallback function
  receive() external payable {}
}
