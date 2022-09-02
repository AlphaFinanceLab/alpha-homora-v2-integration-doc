// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IMasterChefBeets {
    function beets() external view returns (address);

    function lpTokens(uint256 pid) external view returns (address);

    function poolLength() external view returns (uint256);

    function rewarder(uint256 pid) external view returns (address);

    function poolInfo(uint256 pid)
        external
        view
        returns (
            uint256 allocPoint,
            uint256 lastRewardTime,
            uint256 accBeetsPerShare
        );

    function deposit(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function withdrawAndHarvest(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function harvest(uint256 pid, address to) external;

    function userInfo(uint256 pid, address user)
        external
        view
        returns (uint256, int256);
}
