# Interact with HomoraV2 on ETH

Note: the following example scripts are Solidity langauge based on Foundry framework.

Recap from [here](https://hackmd.io/Exjnxbq4Tg6TAOlULziVhQ).

You can open/adjust with the position via the bank contract by calling `bank.execute(position_id, spell_address, data)` function.

- `position_id`: your position Id, set it to be 0 if you want to open a new position.
- `spell_address`: spell contract address that interacts with your target DEX.
- `data`: describes what parameters we uses and what function we call in the spell contract, encoded as bytes data.

After execution, it will return your `position_id`. (It must be equal to what you input or new `position_id` if you set it as 0).

Different DEXes require different inputs.

## DEXes & Interaction types

### Uniswap V2 (ETH)

Spell Address: See Appendix A

Example of how to integrate with Homora [here](https://github.com/AlphaFinanceLab/alpha-homora-v2-integration-doc/blob/master/contracts/eth/uniswapv2/UniswapV2SpellV1Integration.sol)

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

Example of how to integrate with Homora [here](https://github.com/AlphaFinanceLab/alpha-homora-v2-integration-doc/blob/master/contracts/eth/sushiswap/SushiswapSpellV1Integration.sol)

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

Example of how to integrate with Homora [here](https://github.com/AlphaFinanceLab/alpha-homora-v2-integration-doc/blob/master/contracts/eth/curve/CurveSpellV1Integration.sol)

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

## Appendix A: Contract addresses

| Name                    | Contract address                                                                                                      |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------- |
| HomoraBank              | [0xba5eBAf3fc1Fcca67147050Bf80462393814E54B](https://etherscan.io/address/0xba5eBAf3fc1Fcca67147050Bf80462393814E54B) |
| UniswapV2SpellV1        | [0x00b1a4E7F217380a7C9e6c12F327AC4a1D9B6A14](https://etherscan.io/address/0x00b1a4E7F217380a7C9e6c12F327AC4a1D9B6A14) |
| SushiswapSpellV1        | [0xDc9c7A2Bae15dD89271ae5701a6f4DB147BAa44C](https://etherscan.io/address/0xDc9c7A2Bae15dD89271ae5701a6f4DB147BAa44C) |
| CurveSpellV1            | [0x8b947D8448CFFb89EF07A6922b74fBAbac219795](https://etherscan.io/address/0x8b947D8448CFFb89EF07A6922b74fBAbac219795) |
| WERC20                  | [0x06799a1e4792001AA9114F0012b9650cA28059a3](https://etherscan.io/address/0x06799a1e4792001AA9114F0012b9650cA28059a3) |
| WStakingRewards (INDEX) | [0x011535FD795fD28c749363E080662D62fBB456a7](https://etherscan.io/address/0x011535FD795fD28c749363E080662D62fBB456a7) |
| WMasterChef             | [0xA2caEa05fF7B98f10Ad5ddc837F15905f33FEb60](https://etherscan.io/address/0xA2caEa05fF7B98f10Ad5ddc837F15905f33FEb60) |
| WLiquidityGauge         | [0xf1F32C8EEb06046d3cc3157B8F9f72B09D84ee5b](https://etherscan.io/address/0xf1F32C8EEb06046d3cc3157B8F9f72B09D84ee5b) |

Many wrapper contracts are implemented to support different pools' reward contract. Even the pools are in the same DEX, the reward contract may be different, e.g. Masterchef contract, Minichef contract),

Following table describes what wrapper contract types use which spell contracts.

| Pool type                               | Wrapper contracts | Spell contracts  |
| --------------------------------------- | ----------------- | ---------------- |
| every pool in UniswapV2<br> (no reward) | WERC20            | UniswapSpellV1   |
| every pool in UniswapV2<br> (INDEX)     | WStakingRewards   | UniswapSpellV1   |
| every pool in Sushiswap<br> (no reward) | WERC20            | SushiswapSpellV1 |
| every pool in Sushiswap                 | WMasterChef       | SushiswapSpellV1 |
| every pools in Curve                    | WLiquidityGauge   | CurveSpellV1     |
