// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IMiniChefV2PNG {
    function REWARD() external view returns (address);

    function poolInfo(uint256 pid)
        external
        view
        returns (
            uint128 accRewardPerShare,
            uint64 lastRewardTime,
            uint64 allocPoint
        );

    function lpToken(uint256 pid) external view returns (address);

    function lpTokens() external view returns (address[] memory);

    function rewarder(uint256 pid) external view returns (address);

    function deposit(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function withdraw(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function userInfo(uint256 pid, address user)
        external
        view
        returns (uint256, int256);

    function withdrawAndHarvest(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function harvest(uint256 pid, address to) external;

    function poolLength() external view returns (uint256);

    function updatePool(uint256 pid)
        external
        returns (
            uint128 accRewardPerShare,
            uint64 lastRewardTime,
            uint64 allocPoint
        );

    /// @notice View function to see pending reward on frontend.
    /// @param _pid The index of the pool.
    /// @param _user Address of user.
    /// @return pending reward for a given user.
    function pendingReward(uint256 _pid, address _user)
        external
        view
        returns (uint256 pending);
}
