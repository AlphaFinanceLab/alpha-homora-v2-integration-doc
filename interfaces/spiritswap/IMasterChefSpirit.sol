// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IMasterChefSpirit {
  function spirit() external view returns (address);

  function poolLength() external view returns (uint);

  function poolInfo(uint pid)
    external
    view
    returns (
      address lpToken,
      uint allocPoint,
      uint lastRewardTime,
      uint accSpiritPerShare,
      uint depositFeeBP
    );

  function deposit(uint pid, uint amount) external;

  function withdraw(uint pid, uint amount) external;

  function userInfo(uint pid, address user) external view returns (uint, int);

  function pendingSpirit(uint _pid, address _user) external view returns (uint);
}
