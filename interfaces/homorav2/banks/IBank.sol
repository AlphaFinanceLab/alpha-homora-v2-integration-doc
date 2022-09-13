// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import '../IGovernable.sol';
import '../IOracle.sol';

interface IBank is IGovernable {
  struct Bank {
    bool isListed; // Whether this market exists.
    uint8 index; // Reverse look up index for this bank.
    address cToken; // The CToken to draw liquidity from.
    uint reserve; // The reserve portion allocated to Homora protocol.
    uint totalDebt; // The last recorded total debt since last action.
    uint totalShare; // The total debt share count across all open positions.
  }

  struct Position {
    address owner; // The owner of this position.
    address collToken; // The ERC1155 token used as collateral for this position.
    uint collId; // The token id used as collateral.
    uint collateralSize; // The size of collateral token for this position.
    uint debtMap; // Bitmap of nonzero debt. i^th bit is set iff debt share of i^th bank is nonzero.
    mapping(address => uint) debtShareOf; // The debt share for each token.
  }

  /// @dev Return the current position while under execution.
  function POSITION_ID() external view returns (uint);

  /// @dev Return the current target while under execution.
  function SPELL() external view returns (address);

  /// @dev Return the current position while under execution.
  function oracle() external view returns (address);

  /// @dev Return next available position, starting from 1.
  function nextPositionId() external view returns (address);

  /// @dev Return a listed bank.
  function allBanks(uint index) external view returns (address);

  /// @dev Return bank data from token.
  function banks(address token) external view returns (Bank memory);

  /// @dev Return whether cToken is existence in bank.
  function cTokenInBank(address cToken) external view returns (bool);

  /// @dev Return the boolean status whether to allow call from contract (false = onlyEOA)
  function allowContractCalls() external view returns (bool);

  /// @dev Return whitelist status from token
  function whitelistedTokens(address token) external view returns (bool);

  /// @dev Return whitelist status from spell
  function whitelistedSpells(address spell) external view returns (bool);

  /// @dev Return whitelist status from user
  function whitelistedUsers(address user) external view returns (bool);

  /// @dev Return number which each bit stores certain bank status, e.g. borrow allowed, repay allowed
  function bankStatus() external view returns (uint);

  /// @dev Return credit limit from user address and token.
  /// NOTE: Credit limits are only applied specifically for whitelisted users.
  function whitelistedUserCreditLimits(address user, address token) external returns (uint);

  /// @dev Return borrow share from user address and token.
  function whitelistedUserBorrowShares(address user, address token) external returns (uint);

  /// @dev Return whether the user was ever whitelisted
  function everWhitelistedUsers(address user) external returns (address);

  /// @dev Return worker address to withdraw reserve.
  function worker() external returns (address);

  /// @dev Return exec address.
  function exec() external returns (address);

  /// @dev Return the current executor (the owner of the current position).
  function EXECUTOR() external view returns (address);

  /// @dev Set allowContractCalls
  function setAllowContractCalls(bool ok) external;

  /// @dev Set exec
  /// @param _exec exec address
  function setExec(address _exec) external;

  /// @dev Set whitelist spell status
  /// @param spells list of spells to change status
  /// @param statuses list of statuses to change to
  function setWhitelistSpells(address[] calldata spells, bool[] calldata statuses) external;

  /// @dev Set whitelist token status
  /// @param tokens list of tokens to change status
  /// @param statuses list of statuses to change to
  function setWhitelistTokens(address[] calldata tokens, bool[] calldata statuses) external;

  /// @dev Set whitelist user status
  /// @param users list of users to change status
  /// @param statuses list of statuses to change to
  function setWhitelistUsers(address[] calldata users, bool[] calldata statuses) external;

  /// @dev Set worker
  /// @param _worker worker address for withdrawing reserve
  function setWorker(address _worker) external;

  /// @dev Check whether the oracle supports the token
  /// @param token ERC-20 token to check for support
  function support(address token) external view returns (bool);

  /// @dev Set bank status
  /// @param _bankStatus new bank status to change to
  function setBankStatus(uint _bankStatus) external;

  /// @dev Bank borrow status allowed or not
  function allowBorrowStatus() external view returns (bool);

  /// @dev Bank repay status allowed or not
  function allowRepayStatus() external view returns (bool);

  /// @dev Trigger interest accrual for the given bank.
  /// @param token The underlying token to trigger the interest accrual.
  function accrue(address token) external;

  /// @dev Convenient function to trigger interest accrual for a list of banks.
  /// @param tokens The list of banks to trigger interest accrual.
  function accrueAll(address[] memory tokens) external;

  /// @dev Return the borrow balance for given position and token without triggering interest accrual.
  /// @param positionId The position to query for borrow balance.
  /// @param token The token to query for borrow balance.
  function borrowBalanceStored(uint positionId, address token) external view returns (uint);

  /// @dev Trigger interest accrual and return the current borrow balance.
  /// @param positionId The position to query for borrow balance.
  /// @param token The token to query for borrow balance.
  function borrowBalanceCurrent(uint positionId, address token) external returns (uint);

  /// @dev Return bank information for the given token.
  /// @param token The token address to query for bank information.
  function getBankInfo(address token)
    external
    view
    returns (
      bool isListed,
      address cToken,
      uint reserve,
      uint totalDebt,
      uint totalShare
    );

  /// @dev Return position information for the given position id.
  /// @param positionId The position id to query for position information.
  function getPositionInfo(uint positionId)
    external
    view
    returns (
      address owner,
      address collToken,
      uint collId,
      uint collateralSize
    );

  /// @dev Return current position information
  function getCurrentPositionInfo()
    external
    view
    returns (
      address owner,
      address collToken,
      uint collId,
      uint collateralSize
    );

  /// @dev Return the debt share of the given bank token for the given position id.
  /// @param positionId position id to get debt of
  /// @param token ERC20 debt token to query
  function getPositionDebtShareOf(uint positionId, address token) external view returns (uint);

  /// @dev Return the list of all debts for the given position id.
  /// @param positionId position id to get debts of
  function getPositionDebts(uint positionId)
    external
    view
    returns (address[] memory tokens, uint[] memory debts);

  /// @dev Return the total collateral value of the given position in ETH.
  /// @param positionId The position ID to query for the collateral value.
  function getCollateralETHValue(uint positionId) external view returns (uint);

  /// @dev Return the total borrow value of the given position in ETH.
  /// @param positionId The position ID to query for the borrow value.
  function getBorrowETHValue(uint positionId) external view returns (uint);

  /// @dev Add a new bank to the ecosystem.
  /// @param token The underlying token for the bank.
  /// @param cToken The address of the cToken smart contract.
  function addBank(address token, address cToken) external;

  /// @dev Set the oracle smart contract address.
  /// @param _oracle The new oracle smart contract address.
  function setOracle(IOracle _oracle) external;

  /// @dev Set the fee bps value that Homora bank charges.
  /// @param _feeBps The new fee bps value.
  function setFeeBps(uint _feeBps) external;

  /// @dev Withdraw the reserve portion of the bank. (only for worker)
  /// @param token The token to withdraw.
  /// @param amount The amount to withdraw.
  function withdrawReserve(address token, uint amount) external;

  /// @dev Liquidate a position. Pay debt for its owner and take the collateral.
  /// @param positionId The position ID to liquidate.
  /// @param debtToken The debt token to repay.
  /// @param amountCall The amount to repay when doing transferFrom call.
  function liquidate(
    uint positionId,
    address debtToken,
    uint amountCall
  ) external;

  /// @dev Execute the action via HomoraCaster, calling its function with the supplied data.
  /// @param positionId The position ID to execute the action, or zero for new position.
  /// @param spell The target spell to invoke the execution via HomoraCaster.
  /// @param data Extra data to pass to the target for the execution.
  function execute(
    uint positionId,
    address spell,
    bytes memory data
  ) external returns (uint);

  /// @dev Borrow tokens from that bank. Must only be called while under execution.
  /// @param token The token to borrow from the bank.
  /// @param amount The amount of tokens to borrow.
  function borrow(address token, uint amount) external;

  /// @dev Repay tokens to the bank. Must only be called while under execution.
  /// @param token The token to repay to the bank.
  /// @param amountCall The amount of tokens to repay via transferFrom.
  function repay(address token, uint amountCall) external;

  /// @dev Transmit user assets to the caller, so users only need to approve Bank for spending.
  /// @param token The token to transfer from user to the caller.
  /// @param amount The amount to transfer.
  function transmit(address token, uint amount) external;

  /// @dev Put more collateral for users. Must only be called during execution.
  /// @param collToken The ERC1155 token to collateral.
  /// @param collId The token id to collateral.
  /// @param amountCall The amount of tokens to put via transferFrom.
  function putCollateral(
    address collToken,
    uint collId,
    uint amountCall
  ) external;

  /// @dev Take some collateral back. Must only be called during execution.
  /// @param collToken The ERC1155 token to take back.
  /// @param collId The token id to take back.
  /// @param amount The amount of tokens to take back via transfer.
  function takeCollateral(
    address collToken,
    uint collId,
    uint amount
  ) external;
}
