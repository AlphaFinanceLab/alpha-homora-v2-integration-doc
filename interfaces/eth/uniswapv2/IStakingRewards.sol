// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IStakingRewards {
  function rewardPerToken() external view returns (uint);

  function stake(uint amount) external;

  function withdraw(uint amount) external;

  function getReward() external;

  function earned(address account) external view returns (uint);

  function balanceOf(address account) external view returns (uint);
}
