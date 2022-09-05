// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IMasterChefSpirit {
    function spirit() external view returns (address);

    function poolLength() external view returns (uint256);

    function poolInfo(uint256 pid)
        external
        view
        returns (
            address lpToken,
            uint256 allocPoint,
            uint256 lastRewardTime,
            uint256 accSpiritPerShare,
            uint256 depositFeeBP
        );

    function deposit(uint256 pid, uint256 amount) external;

    function withdraw(uint256 pid, uint256 amount) external;

    function userInfo(uint256 pid, address user)
        external
        view
        returns (uint256, int256);
}
