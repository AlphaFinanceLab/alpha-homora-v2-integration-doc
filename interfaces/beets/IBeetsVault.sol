// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol';

interface IAsset {
  // solhint-disable-previous-line no-empty-blocks
}

interface IBeetsVault {
  enum PoolSpecialization {
    GENERAL,
    MINIMAL_SWAP_INFO,
    TWO_TOKEN
  }

  enum SwapKind {
    GIVEN_IN,
    GIVEN_OUT
  }

  enum JoinKind {
    INIT,
    EXACT_TOKENS_IN_FOR_BPT_OUT,
    TOKEN_IN_FOR_EXACT_BPT_OUT,
    ALL_TOKENS_IN_FOR_EXACT_BPT_OUT
  }
  enum ExitKind {
    EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
    EXACT_BPT_IN_FOR_TOKENS_OUT,
    BPT_IN_FOR_EXACT_TOKENS_OUT,
    MANAGEMENT_FEE_TOKENS_OUT // for ManagedPool
  }

  enum UserBalanceOpKind {
    DEPOSIT_INTERNAL,
    WITHDRAW_INTERNAL,
    TRANSFER_INTERNAL,
    TRANSFER_EXTERNAL
  }

  struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;
    address assetIn;
    address assetOut;
    uint amount;
    bytes userData;
  }

  struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address payable recipient;
    bool toInternalBalance;
  }

  struct JoinPoolRequest {
    address[] assets;
    uint[] maxAmountsIn;
    bytes userData;
    bool fromInternalBalance;
  }

  struct ExitPoolRequest {
    address[] assets;
    uint[] minAmountsOut;
    bytes userData;
    bool toInternalBalance;
  }

  struct UserBalanceOp {
    UserBalanceOpKind kind;
    IAsset asset;
    uint amount;
    address sender;
    address payable recipient;
  }

  function WETH() external view returns (address);

  function getPool(bytes32 poolId) external view returns (address, PoolSpecialization);

  function getPoolTokenInfo(bytes32 poolId, IERC20 token)
    external
    view
    returns (
      uint cash,
      uint managed,
      uint lastChangeBlock,
      address assetManager
    );

  function getPoolTokens(bytes32 poolId)
    external
    view
    returns (
      address[] memory tokens,
      uint[] memory balances,
      uint lastChangeBlock
    );

  function swap(
    SingleSwap memory singleSwap,
    FundManagement memory funds,
    uint limit,
    uint deadline
  ) external payable returns (uint);

  function joinPool(
    bytes32 poolId,
    address sender,
    address recipient,
    JoinPoolRequest memory request
  ) external payable;

  function exitPool(
    bytes32 poolId,
    address sender,
    address payable recipient,
    ExitPoolRequest memory request
  ) external;

  function manageUserBalance(UserBalanceOp[] memory ops) external payable;
}
