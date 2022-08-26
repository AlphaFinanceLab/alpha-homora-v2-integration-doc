// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IBoostedMasterChefJoe {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 factor;
    }

    struct PoolInfo {
        address lpToken;
        uint96 allocPoint;
        uint256 accJoePerShare;
        uint256 accJoePerFactorPerShare;
        uint64 lastRewardTimestamp;
        address rewarder;
        uint32 veJoeShareBp;
        uint256 totalFactor;
        uint256 totalLpSupply;
    }

    /// @notice Address of MCJV2 contract
    function MASTER_CHEF_V2() external view returns (address);

    /// @notice Address of JOE contract
    function JOE() external view returns (address);

    /// @notice Address of veJOE contract
    function VEJOE() external view returns (address);

    /// @notice The index of BMCJ master pool in MCJV2
    function MASTER_PID() external view returns (uint256);

    /// @notice Info of each BMCJ pool
    function poolInfo(uint256 pid) external view returns (PoolInfo memory);

    /// @notice Info of each user that stakes LP tokens
    function userInfo(uint256, address) external view returns (UserInfo memory);

    /// @dev Total allocation points. Must be the sum of all allocation points in all pools
    function totalAllocPoint() external view returns (uint256);

    function claimableJoe(uint256, address) external returns (uint256);

    function init(address _dummyToken) external;

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// @param _allocPoint AP of the new pool.
    /// @param _veJoeShareBp Share of rewards allocated in proportion to user's liquidity
    /// and veJoe balance
    /// @param _lpToken Address of the LP ERC-20 token.
    /// @param _rewarder Address of the rewarder delegate.
    function add(
        uint96 _allocPoint,
        uint32 _veJoeShareBp,
        address _lpToken,
        address _rewarder
    ) external;

    /// @notice Update the given pool's JOE allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _allocPoint New AP of the pool
    /// @param _veJoeShareBp Share of rewards allocated in proportion to user's liquidity
    /// and veJoe balance
    /// @param _rewarder Address of the rewarder delegate
    /// @param _overwrite True if _rewarder should be `set`. Otherwise `_rewarder` is ignored
    function set(
        uint256 _pid,
        uint96 _allocPoint,
        uint32 _veJoeShareBp,
        address _rewarder,
        bool _overwrite
    ) external;

    /// @notice Deposit LP tokens to BMCJ for JOE allocation
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _amount LP token amount to deposit
    function deposit(uint256 _pid, uint256 _amount) external;

    /// @notice Withdraw LP tokens from BMCJ
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _amount LP token amount to withdraw
    function withdraw(uint256 _pid, uint256 _amount) external;

    /// @notice Updates factor after after a veJoe token operation.
    /// This function needs to be called by the veJoe contract after
    /// every mint / burn.
    /// @param _user The users address we are updating
    /// @param _newVeJoeBalance The new balance of the users veJoe
    function updateFactor(address _user, uint256 _newVeJoeBalance) external;

    /// @notice Withdraw without caring about rewards (EMERGENCY ONLY)
    /// @param _pid The index of the pool. See `poolInfo`
    function emergencyWithdraw(uint256 _pid) external;

    /// @notice Calculates and returns the `amount` of JOE per second
    /// @return amount The amount of JOE emitted per second
    function joePerSec() external view returns (uint256 amount);

    /// @notice View function to see pending JOE on frontend
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _user Address of user
    /// @return pendingJoe JOE reward for a given user.
    /// @return bonusTokenAddress The address of the bonus reward.
    /// @return bonusTokenSymbol The symbol of the bonus token.
    /// @return pendingBonusToken The amount of bonus rewards pending.
    function pendingTokens(uint256 _pid, address _user)
        external
        view
        returns (
            uint256 pendingJoe,
            address bonusTokenAddress,
            string memory bonusTokenSymbol,
            uint256 pendingBonusToken
        );

    /// @notice Returns the number of BMCJ pools.
    /// @return pools The amount of pools in this farm
    function poolLength() external view returns (uint256 pools);

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() external;

    /// @notice Update reward variables of the given pool
    /// @param _pid The index of the pool. See `poolInfo`
    function updatePool(uint256 _pid) external;

    /// @notice Harvests JOE from `MASTER_CHEF_V2` MCJV2 and pool `MASTER_PID` to this BMCJ contract
    function harvestFromMasterChef() external;
}
