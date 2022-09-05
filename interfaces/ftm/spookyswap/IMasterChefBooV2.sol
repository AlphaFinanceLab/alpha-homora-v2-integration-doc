// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IMasterChefBooV2 {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 factor;
    }

    function BOO() external view returns (address);

    function poolLength() external view returns (uint256);

    function poolInfo(uint256 pid)
        external
        view
        returns (
            uint128 accBooPerShare,
            uint64 lastRewardTime,
            uint64 allocPoint
        );

    function userInfo(uint256 pid, address user)
        external
        view
        returns (uint256 amount, uint256 rewardDebt);

    function rewarder(uint256 pid) external view returns (address);

    function lpToken(uint256 pid) external view returns (address);

    function deposit(uint256 pid, uint256 amount) external;

    function withdraw(uint256 pid, uint256 amount) external;

    function harvestFromMasterChef() external;

    /// @notice View function to see pending BOO on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending BOO reward for a given user.
    function pendingBOO(uint256 _pid, address _user)
        external
        view
        returns (uint256 pending);
}
