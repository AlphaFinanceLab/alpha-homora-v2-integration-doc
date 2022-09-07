// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IMasterChef {
  function sushi() external view returns (address);

  function poolLength() external view returns (uint);

  function userInfo(uint pid, address user) external view returns (uint, int);

  function pendingSushi(uint _pid, address _user) external view returns (uint pending);

  function poolInfo(uint pid)
    external
    view
    returns (
      address lpToken,
      uint allocPoint,
      uint lastRewardBlock,
      uint accSushiPerShare
    );

  function deposit(uint pid, uint amount) external;

  function withdraw(uint pid, uint amount) external;

  function getMultiplier(uint _from, uint _to) external view returns (uint);

  function totalAllocPoint() external view returns (uint);

  function sushiPerBlock() external view returns (uint);
}
