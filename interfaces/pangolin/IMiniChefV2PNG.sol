// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IMiniChefV2PNG {
  function REWARD() external view returns (address);

  function poolInfo(uint pid)
    external
    view
    returns (
      uint128 accRewardPerShare,
      uint64 lastRewardTime,
      uint64 allocPoint
    );

  function lpToken(uint pid) external view returns (address);

  function lpTokens() external view returns (address[] memory);

  function rewarder(uint pid) external view returns (address);

  function deposit(
    uint pid,
    uint amount,
    address to
  ) external;

  function withdraw(
    uint pid,
    uint amount,
    address to
  ) external;

  function userInfo(uint pid, address user) external view returns (uint, int);

  function withdrawAndHarvest(
    uint pid,
    uint amount,
    address to
  ) external;

  function harvest(uint pid, address to) external;

  function poolLength() external view returns (uint);

  function updatePool(uint pid)
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
  function pendingReward(uint _pid, address _user) external view returns (uint pending);

  function rewardsExpiration() external view returns (uint);

  function totalAllocPoint() external view returns (uint);

  function rewardPerSecond() external view returns (uint);
}
