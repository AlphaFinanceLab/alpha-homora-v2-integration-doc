pragma solidity 0.8.16;

interface IUniswapV3Pool {
  struct Slot0 {
    // the current price
    uint160 sqrtPriceX96;
    // the current tick
    int24 tick;
    // the most-recently updated index of the observations array
    uint16 observationIndex;
    // the current maximum number of observations that are being stored
    uint16 observationCardinality;
    // the next maximum number of observations to store, triggered in observations.write
    uint16 observationCardinalityNext;
    // the current protocol fee as a percentage of the swap fee taken on withdrawal
    // represented as an integer denominator (1/x)%
    uint8 feeProtocol;
    // whether the pool is locked
    bool unlocked;
  }

  function positions(bytes32)
    external
    view
    returns (
      uint128,
      uint256,
      uint256,
      uint128,
      uint128
    );

  function slot0()
    external
    view
    returns (
      uint160,
      int24,
      uint16,
      uint16,
      uint16,
      uint8,
      bool
    );

  function feeGrowthGlobal0X128() external view returns (uint256);

  function feeGrowthGlobal1X128() external view returns (uint256);

  function ticks(int24)
    external
    view
    returns (
      uint128,
      int128,
      uint256,
      uint256,
      int56,
      uint160,
      uint32,
      bool
    );
}
