# Interact with HomoraV2 on Fantom

Note: the following example scripts are Solidity langauge based on Foundry framework.

Recap from [here](https://hackmd.io/Exjnxbq4Tg6TAOlULziVhQ).

You can open/adjust with the position via the bank contract by calling `bank.execute(position_id, spell_address, data)` function.

- `position_id`: your position Id, set it to be 0 if you want to open a new position.
- `spell_address`: spell contract address that interacts with your target DEX.
- `data`: describes what parameters we uses and what function we call in the spell contract, encoded as bytes data.

After execution, it will return your `position_id`. (It must be equal to what you input or new `position_id` if you set it as 0).

Different DEXes require different inputs.

## DEXes & Interaction types

### SpookySwapV2 (Masterchef V2)

Spell Address: See appendix A

Example of how to integrate with Homora [here](https://github.com/AlphaFinanceLab/alpha-homora-v2-integration-doc/blob/master/contracts/ftm/spookyswap/SpookySwapSpellV2Integration.sol)

Functions:

1. addLiquidityWMasterChef: Leverage, provide liquidity to the pool and stake LP to the staking contract.
2. removeLiquidityWMasterChef: unstake LP, remove liquidity from the pool and repay a loan.
3. harvestWMasterChef: collect masterchef rewards.
4. migrate: migrate position from SpookyswapV1 to SpookyswapV2

Decoding wrapper token ID
|parameters|description|
|---|---|
|pid|pool id in SpookySwap's masterchefV2|
|rewardPerShare|latest-updated accumulated reward per share <br> (being used for calculating pending reward)|

```solidity=
IBankFTM bank = IBankFTM(0x060E91A44f16DFcc1e2c427A0383596e1D2e886f);
uint256 positionId = 123; // change position id here
(
    ,
    address collateralTokenAddress,
    uint256 collateralId,
    uint256 collateralAmount
) = bank.getPositionInfo(positionId);

IWMasterChefBooV2 wrapper = IWMasterChefBooV2(collateralTokenAddress);
(uint256 pid, uint256 rewardPerShare) = wrapper.decodeId(
    collateralId
);
```

### SpiritSwap

Spell Address: See appendix A

Example of how to integrate with Homora [here](https://github.com/AlphaFinanceLab/alpha-homora-v2-integration-doc/blob/master/contracts/ftm/spiritswap/SpiritSwapSpellV1Integration.sol)

Functions:

1. addLiquidityWMasterChef: Leverage, provide liquidity to the pool and stake LP to the staking contract.
2. removeLiquidityWMasterChef: unstake LP, remove liquidity from the pool and repay a loan.
3. harvestWMasterChef: collect masterchef rewards.

Decoding wrapper token ID
|parameters|description|
|---|---|
|pid|pool id in SpiritSwap's masterchef|
|rewardPerShare|latest-updated accumulated reward per share <br> (being used for calculating pending reward)|

```solidity=
IBankFTM bank = IBankFTM(0x060E91A44f16DFcc1e2c427A0383596e1D2e886f);
uint256 positionId = 123; // change position id here
(
    ,
    address collateralTokenAddress,
    uint256 collateralId,
    uint256 collateralAmount
) = bank.getPositionInfo(positionId);

IWMasterChefSpirit wrapper = IWMasterChefSpirit(collateralTokenAddress);
(uint256 pid, uint256 rewardPerShare) = wrapper.decodeId(
    collateralId
);
```

### Beethoven X

Spell Address: See Appendix A

Example of how to integrate with Homora [here](https://github.com/AlphaFinanceLab/alpha-homora-v2-integration-doc/blob/master/contracts/ftm/beets/BeetsSpellV1Integration.sol)

Functions:

1. addLiquidityWMasterChef: Leverage, provide liquidity to the pool and stake LP to the staking contract.
2. removeLiquidityWMasterChef: unstake LP, remove liquidity from the pool and repay a loan.
3. harvestWMasterChef: collect masterchef rewards.

Decoding wrapper token ID
|parameters|description|
|---|---|
|pid|pool id in Beet's masterchef|
|rewardPerShare|latest-updated accumulated reward per share <br> (being used for calculating pending reward)|

```solidity=
IBankFTM bank = IBankFTM(0x060E91A44f16DFcc1e2c427A0383596e1D2e886f);
uint256 positionId = 123; // change position id here
(
    ,
    address collateralTokenAddress,
    uint256 collateralId,
    uint256 collateralAmount
) = bank.getPositionInfo(positionId);

IWMasterChefBeetsWorker wrapper = IWMasterChefBeetsWorker(collateralTokenAddress);
(uint256 pid, uint256 rewardPerShare) = wrapper.decodeId(
    collateralId
);
```

# Summary

Many wrapper contracts are implemented to support different pools' reward contract. Even the pools are in the same DEX, the reward contract may be different, e.g. Masterchef contract, Minichef contract),

Following table describes what wrapper contract types use which spell contracts.

| Pool type  | Wrapper contracts      | Spell contracts   |
| ---------- | ---------------------- | ----------------- |
| SpookySwap | WMasterChefBOOV2       | SpookySwapSpellV2 |
| SpiritSwap | WMasterChefSpiritV1    | SpiritSwapSpellV1 |
| Beethoven  | WMasterChefBeetsWorker | BeetsSpellV1      |

## Contract addresses

| Name                                      | Contract address                                                                                                     |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| HomoraBank                                | [0x060E91A44f16DFcc1e2c427A0383596e1D2e886f](https://ftmscan.com/address/0x060E91A44f16DFcc1e2c427A0383596e1D2e886f) |
| SpookySwapSpellV2 (FTM/fUSDT)             | [0x188daa19208b369Ce74A5959661dB003431f011c](https://ftmscan.com/address/0x188daa19208b369Ce74A5959661dB003431f011c) |
| SpookySwapSpellV2 (FTM/USDC)              | [0x04A65eaae1C6005a6522f5fd886F53Fce9F8a895](https://ftmscan.com/address/0x04A65eaae1C6005a6522f5fd886F53Fce9F8a895) |
| SpookySwapSpellV2 (FTM/DAI)               | [0xF8311a422da44f4b98b87Eaff02EcDEA506d608c](https://ftmscan.com/address/0xF8311a422da44f4b98b87Eaff02EcDEA506d608c) |
| SpookySwapSpellV2 (FTM/BTC)               | [0x31634294a0532347d6e543449436B2aB4d20C48C](https://ftmscan.com/address/0x31634294a0532347d6e543449436B2aB4d20C48C) |
| SpookySwapSpellV2 (FTM/ETH)               | [0xBF956ECDbd08d9aeA6Ef0Cdd305d054859EBc130](https://ftmscan.com/address/0xBF956ECDbd08d9aeA6Ef0Cdd305d054859EBc130) |
| SpookySwapSpellV2 (FTM/LINK)              | [0x2FcB7D1157057da794bf0694c40948Ce4DC1fB90](https://ftmscan.com/address/0x2FcB7D1157057da794bf0694c40948Ce4DC1fB90) |
| SpookySwapSpellV2 (ETH/BTC)               | [0x14bC6Cf95a8BEFD4B07e0f824c60bC1401fE9D23](https://ftmscan.com/address/0x14bC6Cf95a8BEFD4B07e0f824c60bC1401fE9D23) |
| SpiritSwapSpellV1                         | [0x928f13D14FBDD933d812FCF777D9e18397D425de](https://ftmscan.com/address/0x928f13D14FBDD933d812FCF777D9e18397D425de) |
| BeetsSpellV1 (USDC/FTM)                   | [0x977791A64ae5B96090403Ee8f529934DFf7fb662](https://ftmscan.com/address/0x977791A64ae5B96090403Ee8f529934DFf7fb662) |
| BeetsSpellV1 (USDC/FTM/BTC/ETH)           | [0xEeb9b7C60749fEC168ABE7382981428D6ac00C2F](https://ftmscan.com/address/0xEeb9b7C60749fEC168ABE7382981428D6ac00C2F) |
| WMasterChefBOOV2 (FTM/fUSDT)              | [0xCfd1ACd468112317a04844a445106B23169C38d4](https://ftmscan.com/address/0xCfd1ACd468112317a04844a445106B23169C38d4) |
| WMasterChefBOOV2 (FTM/USDC)               | [0xD4159936FaDf8c8F28Db68dBB67bC5afE978A82c](https://ftmscan.com/address/0xD4159936FaDf8c8F28Db68dBB67bC5afE978A82c) |
| WMasterChefBOOV2 (FTM/DAI)                | [0xeCA630046220E1284D89188dBb4f17328E83fA7a](https://ftmscan.com/address/0xeCA630046220E1284D89188dBb4f17328E83fA7a) |
| WMasterChefBOOV2 (FTM/BTC)                | [0x0e4cb26058c2049827Dce451CD4170F55031adAE](https://ftmscan.com/address/0x0e4cb26058c2049827Dce451CD4170F55031adAE) |
| WMasterChefBOOV2 (FTM/ETH)                | [0x900e2AA94A2176A84D45962132f7898861aaCa26](https://ftmscan.com/address/0x900e2AA94A2176A84D45962132f7898861aaCa26) |
| WMasterChefBOOV2 (FTM/LINK)               | [0x755294a6093aaBE389c59E9c9937Cf7D614e7D0a](https://ftmscan.com/address/0x755294a6093aaBE389c59E9c9937Cf7D614e7D0a) |
| WMasterChefBOOV2 (ETH/BTC)                | [0xc2640445eb49d7b1973F92FdcCb1188a29ad1C7F](https://ftmscan.com/address/0xc2640445eb49d7b1973F92FdcCb1188a29ad1C7F) |
| WMasterChefSpiritV1                       | [0xba514D50C4Abb55a632999F14F71F9a189B22C7d](https://ftmscan.com/address/0xba514D50C4Abb55a632999F14F71F9a189B22C7d) |
| WMasterChefBeetsWorker (USDC/FTM)         | [0x8fD641A26c373f0B9BaAFe5aEaFCC977458b6153](https://ftmscan.com/address/0x8fD641A26c373f0B9BaAFe5aEaFCC977458b6153) |
| WMasterChefBeetsWorker (USDC/FTM/BTC/ETH) | [0xEd0dCeC4d50B6374971AD7c7180f80775eAFf1eF](https://ftmscan.com/address/0xEd0dCeC4d50B6374971AD7c7180f80775eAFf1eF) |
