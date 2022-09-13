# Interact with HomoraV2 on Optimism

Note: the following example scripts are Solidity langauge based on Foundry framework.

Recap from [here](../readme.md).

You can open/adjust with the position via the bank contract by calling `bank.execute(position_id, spell_address, data)` function.

- `position_id`: your position Id, set it to be 0 if you want to open a new position.
- `spell_address`: spell contract address that interacts with your target DEX.
- `data`: describes what parameters we uses and what function we call in the spell contract, encoded as bytes data.

After execution, it will return your `position_id`. (It must be equal to what you input or new `position_id` if you set it as 0).

Different DEXes require different inputs.

## DEXes & Interaction types

### Uniswap V3

Spell Address: See Appendix A

Example of how to integrate with Homora [here](../contracts/op/UniswapV3SpellIntegrationOp.sol)

Functions:

1. openPosition: Open a new position and provide liquidity to the pool.
2. increasePosition: Increase position and provide liquidity to the pool.
3. removeLiquidity: Remove liquidity from the pool and repay a loan.
4. harvest: Collect fee from the position.
5. closePosition: Close the position (collect Fee, remove all liquidity, and repay).
6. reinvest: Collect fee and increase liquidity into the position.

Decoding wrapper token ID
|parameters|description|
|---|---|
|posInfo|uniswapV3 position info|

```solidity=
bank = HomoraBank.at(0xFFa51a5EC855f8e38Dd867Ba503c454d8BBC5aB9);
uint256 positionId = 123; // change position id here

// query position info from position id
(, collateralTokenAddress, collateralTokenId, collateralAmount) = bank.getPositionInfo(
_positionId
);

IWUniswapV3Position wrapper = IWUniswapV3Position(collateralTokenAddress);

(, , , , , , , , feeGrowthInside0LastX128, feeGrowthInside1LastX128, , ) = npm.positions(
collateralTokenId
);

posInfo = wrapper.getPositionInfoFromTokenId(collateralTokenId);
```

Since leverage yield farming on UniswapV3 requires optimal swap input from OptimalSwap contract so we provide an example of how to open a new position on HomoraBank [here](https://github.com/AlphaFinanceLab/alpha-homora-v2-integration-doc/blob/master/tests/op/UniswapV3SpellTest.sol#L286-L342)

```solidity=
function testOpenPositionWithOptimalSwap() internal {
    uint multiplier0 = 100;
    uint multiplier1 = 100;
    (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
    int24 currentTick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    uint absTick = currentTick < 0 ? uint(-int(currentTick)) : uint(int(currentTick));
    absTick -= absTick % tickSpacing;
    currentTick = currentTick < 0 ? -int24(int(absTick)) : int24(int(absTick));
    int24 tickLower = int24(currentTick - int24(int(multiplier0 * tickSpacing)));
    int24 tickUpper = int24(currentTick + int24(int(multiplier1 * tickSpacing)));
    uint amt0User = 10 * 10**IERC20Metadata(token0).decimals();
    uint amt1User = 10 * 10**IERC20Metadata(token1).decimals();
    uint amt0Borrow = amt0User / 10;
    uint amt1Borrow = amt1User / 10;
    (uint amtSwap, uint amtOut, bool isZeroForOne) = optimalSwap.getOptimalSwapAmt(
      IUniswapV3Pool(pool),
      amt0User + amt0Borrow,
      amt1User + amt1Borrow,
      tickLower,
      tickUpper
    );

    // user info before
    uint userBalanceToken0_before = balanceOf(token0, alice);
    uint userBalanceToken1_before = balanceOf(token1, alice);

    // call contract
    vm.startPrank(alice, alice);
    integration.openPosition(
      address(spell),
      IUniswapV3Spell.OpenPositionParams(
        token0,
        token1,
        fee,
        tickLower,
        tickUpper,
        amt0User,
        amt1User,
        amt0Borrow,
        amt1Borrow,
        0,
        0,
        amtSwap,
        amtOut,
        isZeroForOne,
        type(uint).max
      )
    );
    vm.stopPrank();

    // user info after
    uint userBalanceToken0_after = balanceOf(token0, alice);
    uint userBalanceToken1_after = balanceOf(token1, alice);

    require(userBalanceToken0_before > userBalanceToken0_after, 'incorrect user balance of token0');
    require(userBalanceToken1_before > userBalanceToken1_after, 'incorrect user balance of token1');
}
```

## Appendix A: Contract addresses

| Name               | Contract address                                                                                                                 |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| HomoraBank         | [0xFFa51a5EC855f8e38Dd867Ba503c454d8BBC5aB9](https://optimistic.etherscan.io/address/0xFFa51a5EC855f8e38Dd867Ba503c454d8BBC5aB9) |
| UniswapV3Spell     | [0xBF956ECDbd08d9aeA6Ef0Cdd305d054859EBc130](https://optimistic.etherscan.io/address/0xBF956ECDbd08d9aeA6Ef0Cdd305d054859EBc130) |
| WUniswapV3Position | [0xAf8C59De82f10d21749952b3d44CcF6Ab97Ca0c7](https://optimistic.etherscan.io/address/0xAf8C59De82f10d21749952b3d44CcF6Ab97Ca0c7) |
| OptimalSwap        | [0xC781Cf972AB97601efeCFfA53202A410f52FEF92](https://optimistic.etherscan.io/address/0xC781Cf972AB97601efeCFfA53202A410f52FEF92) |

Many wrapper contracts are implemented to support different pools' reward contract. Even the pools are in the same DEX, the reward contract may be different, e.g. Masterchef contract, Minichef contract),

Following table describes what wrapper contract types use which spell contracts.

| Pool type                               | Wrapper contracts  | Spell contracts |
| --------------------------------------- | ------------------ | --------------- |
| every pool in UniswapV3<br> (no reward) | WUniswapV3Position | UniswapV3Spell  |
