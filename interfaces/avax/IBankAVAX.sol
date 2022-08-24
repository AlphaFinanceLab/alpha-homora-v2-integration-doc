// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IBankAVAX {
    /// @dev Return the current position while under execution.
    function oracle() external view returns (address);

    /// @dev Return the current position while under execution.
    function POSITION_ID() external view returns (uint256);

    /// @dev Return the current target while under execution.
    function SPELL() external view returns (address);

    /// @dev Return the current executor (the owner of the current position).
    function EXECUTOR() external view returns (address);

    function setWhitelistTokens(
        address[] calldata tokens,
        bool[] calldata statuses
    ) external;

    function setWhitelistSpells(
        address[] calldata spells,
        bool[] calldata statuses
    ) external;

    /// @dev Return bank information for the given token.
    function getBankInfo(address token)
        external
        view
        returns (
            bool isListed,
            address cToken,
            uint256 reserve,
            uint256 totalDebt,
            uint256 totalShare
        );

    /// @dev Return position information for the given position id.
    function getPositionInfo(uint256 positionId)
        external
        view
        returns (
            address owner,
            address collToken,
            uint256 collId,
            uint256 collateralSize
        );

    function getPositionDebtShareOf(uint256 positionId, address token)
        external
        view
        returns (uint256);

    /// @dev Return the list of all debts for the given position id.
    function getPositionDebts(uint256 positionId)
        external
        view
        returns (address[] memory tokens, uint256[] memory debts);

    /// @dev Return the borrow balance for given positon and token without trigger interest accrual.
    function borrowBalanceStored(uint256 positionId, address token)
        external
        view
        returns (uint256);

    /// @dev Trigger interest accrual and return the current borrow balance.
    function borrowBalanceCurrent(uint256 positionId, address token)
        external
        returns (uint256);

    /// @dev Execute the action via HomoraCaster, calling its function with the supplied data.
    /// @param positionId The position ID to execute the action, or zero for new position.
    /// @param spell The target spell to invoke the execution via HomoraCaster.
    /// @param data Extra data to pass to the target for the execution.
    function execute(
        uint256 positionId,
        address spell,
        bytes memory data
    ) external returns (uint256);

    /// @dev Borrow tokens from the bank.
    function borrow(address token, uint256 amount) external;

    /// @dev Repays tokens to the bank.
    function repay(address token, uint256 amountCall) external;

    /// @dev Transmit user assets to the spell.
    function transmit(address token, uint256 amount) external;

    /// @dev Put more collateral for users.
    function putCollateral(
        address collToken,
        uint256 collId,
        uint256 amountCall
    ) external;

    /// @dev Take some collateral back.
    function takeCollateral(
        address collToken,
        uint256 collId,
        uint256 amount
    ) external;

    /// @dev Liquidate a position.
    function liquidate(
        uint256 positionId,
        address debtToken,
        uint256 amountCall
    ) external;

    function getCollateralETHValue(uint256 positionId)
        external
        view
        returns (uint256);

    function getBorrowETHValue(uint256 positionId)
        external
        view
        returns (uint256);

    function accrue(address token) external;

    function nextPositionId() external view returns (uint256);

    /// @dev Return current position information.
    function getCurrentPositionInfo()
        external
        view
        returns (
            address owner,
            address collToken,
            uint256 collId,
            uint256 collateralSize
        );

    function support(address token) external view returns (bool);

    function addBank(address token, address cToken) external;

    function whitelistedTokens(address token) external view returns (bool);
}
