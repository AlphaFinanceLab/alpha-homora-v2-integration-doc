// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IMasterChefBooV2 {
  struct UserInfo {
    uint amount;
    uint rewardDebt;
    uint factor;
  }

  function BOO() external view returns (address);

  function poolLength() external view returns (uint);

  function poolInfo(uint pid)
    external
    view
    returns (
      uint128 accBooPerShare,
      uint64 lastRewardTime,
      uint64 allocPoint
    );

  function userInfo(uint pid, address user) external view returns (uint amount, uint rewardDebt);

  function rewarder(uint pid) external view returns (address);

  function lpToken(uint pid) external view returns (address);

  function deposit(uint pid, uint amount) external;

  function withdraw(uint pid, uint amount) external;

  function harvestFromMasterChef() external;

  /// @notice View function to see pending BOO on frontend.
  /// @param _pid The index of the pool. See `poolInfo`.
  /// @param _user Address of user.
  /// @return pending BOO reward for a given user.
  function pendingBOO(uint _pid, address _user) external view returns (uint pending);
}
