// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IMasterChefBeets {
  function beets() external view returns (address);

  function lpTokens(uint pid) external view returns (address);

  function poolLength() external view returns (uint);

  function rewarder(uint pid) external view returns (address);

  function poolInfo(uint pid)
    external
    view
    returns (
      uint allocPoint,
      uint lastRewardTime,
      uint accBeetsPerShare
    );

  function deposit(
    uint pid,
    uint amount,
    address to
  ) external;

  function withdrawAndHarvest(
    uint pid,
    uint amount,
    address to
  ) external;

  function harvest(uint pid, address to) external;

  function userInfo(uint pid, address user) external view returns (uint, int);

  function pendingBeets(uint _pid, address _user) external view returns (uint pending);
}
