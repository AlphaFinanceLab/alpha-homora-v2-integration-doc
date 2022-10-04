# Interact with HomoraV2 on ETH

Note: the following example scripts are Solidity langauge based on Foundry framework.

Recap from [here](../readme.md).

You can open/adjust with the position via the bank contract by calling `bank.execute(position_id, spell_address, data)` function.

- `position_id`: your position Id, set it to be 0 if you want to open a new position.
- `spell_address`: spell contract address that interacts with your target DEX.
- `data`: describes what parameters we uses and what function we call in the spell contract, encoded as bytes data.

After execution, it will return your `position_id`. (It must be equal to what you input or new `position_id` if you set it as 0).

Different DEXes require different inputs.

## DEXes & Interaction types

### Uniswap V2 (ETH)

Spell Address: See Appendix A

Example of how to integrate with Homora [here](../contracts/eth/UniswapV2SpellV1IntegrationEth.sol)

Functions:

1. addLiquidityWERC20: Leverage & provide liquidity to the pool.
2. addLiquidityWStakingRewards: Leverage, provide liquidity to the pool and stake LP to the staking contract.
3. removeLiquidityWERC20: remove liquidity from the pool and repay a loan.
4. removeLiquidityWStakingRewards: unstake LP, remove liquidity from the pool and repay a loan.
5. harvestWStakingRewards: collect staking rewards.

Decoding wrapper token ID
|parameters|description|
|---|---|
|rewardPerShare|latest-updated accumulated reward per share <br> (being used for calculating pending reward)|

```solidity=
IBankETH bank = IBankETH(0xba5eBAf3fc1Fcca67147050Bf80462393814E54B);
uint256 positionId = 123; // change position id here
(
    ,
    address collateralTokenAddress,
    uint256 collateralId,
    uint256 collateralAmount
) = bank.getPositionInfo(positionId);

uint256 rewardPerShare = collateralId;
```

### Sushiswap (ETH)

Spell Address: See Appendix A

Example of how to integrate with Homora [here](../contracts/eth/SushiswapSpellV1IntegrationEth.sol)

Functions:

1. addLiquidityWERC20: Leverage & provide liquidity to the pool.
2. addLiquidityWMasterChef: Leverage, provide liquidity to the pool and stake LP to the staking contract.
3. removeLiquidityWERC20: remove liquidity from the pool and repay a loan.
4. removeLiquidityWMasterChef: unstake LP, remove liquidity from the pool and repay a loan.
5. harvestWMasterChef: collect masterchef rewards.

Decoding wrapper token ID
|parameters|description|
|---|---|
|pid|pool id in Sushiswap's masterchef|
|rewardPerShare|latest-updated accumulated reward per share <br> (being used for calculating pending reward)|

```solidity=
IBankETH bank = IBankETH(0xba5eBAf3fc1Fcca67147050Bf80462393814E54B);
uint256 positionId = 123; // change position id here
(
    ,
    address collateralTokenAddress,
    uint256 collateralId,
    uint256 collateralAmount
) = bank.getPositionInfo(positionId);

IWMasterChef wrapper = IWMasterChef(collateralTokenAddress);
(uint256 pid, uint256 rewardPerShare) = wrapper.decodeId(
    collateralId
);
```

### Curve (ETH)

Spell Address: [0x8b947D8448CFFb89EF07A6922b74fBAbac219795](https://etherscan.io/address/0x8b947D8448CFFb89EF07A6922b74fBAbac219795)

Example of how to integrate with Homora [here](../contracts/eth/CurveSpellV1IntegrationEth.sol)

Functions:

1. addLiquidity3: Leverage, provide liquidity to the pool and staking to the gauge contract.
2. removeLiquidity3: unstake LP, remove liquidity from the pool and repay a loan.
3. harvest: collect gauge rewards.

Decoding wrapper token ID
|parameters|description|
|---|---|
|pid|pool id in Curve's gauge (refer to lp token)|
|gid|gauge id in Curve's gauge (refer to gauge reward)|
|rewardPerShare|latest-updated accumulated reward per share <br> (being used for calculating pending reward)|

```solidity=
IBankETH bank = IBankETH(0xba5eBAf3fc1Fcca67147050Bf80462393814E54B);
uint256 positionId = 123; // change position id here
(
    ,
    address collateralTokenAddress,
    uint256 collateralId,
    uint256 collateralAmount
) = bank.getPositionInfo(positionId);

IWLiquidityGauge wrapper = IWLiquidityGauge(collateralTokenAddress);
(uint256 pid, uint256 gid, uint256 rewardPerShare) = wrapper.decodeId(
    collateralId
);
```

### Uniswap V3

Spell Address: See Appendix A

Example of how to integrate with Homora [here](../contracts/eth/UniswapV3SpellIntegrationETH.sol)

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
bank = HomoraBank.at(0xba5eBAf3fc1Fcca67147050Bf80462393814E54B);
uint256 positionId = 1234; // change position id here

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

| Name                    | Contract address                                                                                                      |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------- |
| HomoraBank              | [0xba5eBAf3fc1Fcca67147050Bf80462393814E54B](https://etherscan.io/address/0xba5eBAf3fc1Fcca67147050Bf80462393814E54B) |
| UniswapV2SpellV1        | [0x00b1a4E7F217380a7C9e6c12F327AC4a1D9B6A14](https://etherscan.io/address/0x00b1a4E7F217380a7C9e6c12F327AC4a1D9B6A14) |
| SushiswapSpellV1        | [0xDc9c7A2Bae15dD89271ae5701a6f4DB147BAa44C](https://etherscan.io/address/0xDc9c7A2Bae15dD89271ae5701a6f4DB147BAa44C) |
| CurveSpellV1            | [0x8b947D8448CFFb89EF07A6922b74fBAbac219795](https://etherscan.io/address/0x8b947D8448CFFb89EF07A6922b74fBAbac219795) |
| UniswapV3Spell          | [0x0B8F60Be035cc5B1982ED2145c6BFC05F863ddc1](https://etherscan.io/address/0x0B8F60Be035cc5B1982ED2145c6BFC05F863ddc1) |
| WERC20                  | [0x06799a1e4792001AA9114F0012b9650cA28059a3](https://etherscan.io/address/0x06799a1e4792001AA9114F0012b9650cA28059a3) |
| WStakingRewards (INDEX) | [0x011535FD795fD28c749363E080662D62fBB456a7](https://etherscan.io/address/0x011535FD795fD28c749363E080662D62fBB456a7) |
| WMasterChef             | [0xA2caEa05fF7B98f10Ad5ddc837F15905f33FEb60](https://etherscan.io/address/0xA2caEa05fF7B98f10Ad5ddc837F15905f33FEb60) |
| WLiquidityGauge         | [0xf1F32C8EEb06046d3cc3157B8F9f72B09D84ee5b](https://etherscan.io/address/0xf1F32C8EEb06046d3cc3157B8F9f72B09D84ee5b) |
| WUniswapV3Position      | [0x4fb70edDA7f67BdBE225df7C91483c45699293f5](https://etherscan.io/address/0x4fb70edDA7f67BdBE225df7C91483c45699293f5) |

Many wrapper contracts are implemented to support different pools' reward contract. Even the pools are in the same DEX, the reward contract may be different, e.g. Masterchef contract, Minichef contract),

Following table describes what wrapper contract types use which spell contracts.

| Pool type                               | Wrapper contracts  | Spell contracts  |
| --------------------------------------- | ------------------ | ---------------- |
| every pool in UniswapV2<br> (no reward) | WERC20             | UniswapSpellV1   |
| every pool in UniswapV2<br> (INDEX)     | WStakingRewards    | UniswapSpellV1   |
| every pool in Sushiswap<br> (no reward) | WERC20             | SushiswapSpellV1 |
| every pool in Sushiswap                 | WMasterChef        | SushiswapSpellV1 |
| every pools in Curve                    | WLiquidityGauge    | CurveSpellV1     |
| every pools in UniswapV3                | WUniswapV3Position | UniswapV3Spell   |
