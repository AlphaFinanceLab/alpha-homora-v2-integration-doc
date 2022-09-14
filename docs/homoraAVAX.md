# Interact with HomoraV2 on AVAX

Note: the following example scripts are Solidity langauge based on Foundry framework.

Recap from [here](../readme.md).

You can open/adjust with the position via the bank contract by calling `bank.execute(position_id, spell_address, data)` function.

- `position_id`: your position Id, set it to be 0 if you want to open a new position.
- `spell_address`: spell contract address that interacts with your target DEX.
- `data`: describes what parameters we uses and what function we call in the spell contract, encoded as bytes data.

After execution, it will return your `position_id`. (It must be equal to what you input or new `position_id` if you set it as 0).

Different DEXes require different inputs.

## DEXes & Interaction types

### TraderJoe

There are many types of wrapper contracts that support pools on traderJoe depending on TraderJoe's reward contract. Although, the method of calculating pending rewards may be different for each wrapper, we can use same spell interface. See Appendix A to know which pool use which wrapper contract.

Spell Address: See Appendix A

Example of how to integrate with Homora [here](../contracts/avax/TraderJoeSpellV3IntegrationAvax.sol)

Functions:

1. addLiquidityWMasterChef: Leverage, provide liquidity to the pool and stake LP to the staking contract.
2. removeLiquidityWMasterChef: unstake LP, remove liquidity from the pool and repay a loan.
3. harvestWMasterChef: collect masterchef rewards.

Decoding wrapper token ID on WMasterChefJoeV2
|parameters|description|
|---|---|
|pid|pool id in TraderJoe's masterchefV2|
|rewardPerShare|latest-updated accumulated reward per share <br> (being used for calculating pending reward)|

```solidity=
IBankAVAX bank = IBankAVAX(0x376d16C7dE138B01455a51dA79AD65806E9cd694);
uint256 positionId = 123; // change position id here
(
    ,
    address collateralTokenAddress,
    uint256 collateralId,
    uint256 collateralAmount
) = bank.getPositionInfo(positionId);

IWMasterChefJoeV2 wrapper = IWMasterChefJoeV2(collateralTokenAddress);
(uint256 pid, uint256 rewardPerShare) = wrapper.decodeId(
    collateralId
);
```

Decoding wrapper token ID on WMasterChefJoeV3
|parameters|description|
|---|---|
|pid|pool id in TraderJoe's masterchefV3|
|rewardPerShare|latest-updated accumulated reward per share <br> (being used for calculating pending reward)|

```solidity=
IBankAVAX bank = IBankAVAX(0x376d16C7dE138B01455a51dA79AD65806E9cd694);
uint256 positionId = 123; // change position id here
(
    ,
    address collateralTokenAddress,
    uint256 collateralId,
    uint256 collateralAmount
) = bank.getPositionInfo(positionId);

IWMasterChefJoeV3 wrapper = IWMasterChefJoeV3(collateralTokenAddress);
(uint256 pid, uint256 rewardPerShare) = wrapper.decodeId(
    collateralId
);
```

Decoding wrapper token ID on WBoostedMasterChefJoeV3
|parameters|description|
|---|---|
|pid|pool id in TraderJoe's boosted masterchefV3|
|rewardPerShare|latest-updated accumulated reward per share <br> (being used for calculating pending reward)|

```solidity=
IBankAVAX bank = IBankAVAX(0x376d16C7dE138B01455a51dA79AD65806E9cd694);
uint256 positionId = 123; // change position id here
(
    ,
    address collateralTokenAddress,
    uint256 collateralId,
    uint256 collateralAmount
) = bank.getPositionInfo(positionId);

IWBoostedMasterChefJoeWorker wrapper = IWBoostedMasterChefJoeWorker(collateralTokenAddress);
(uint256 pid, uint256 rewardPerShare) = wrapper.decodeId(
    collateralId
);
```

### Pangolin Exchange

Spell Address: See Appendix A

Example of how to integrate with Homora [here](https://github.com/AlphaFinanceLab/alpha-homora-v2-integration-doc/blob/master/contracts/avax/pangolin/PangolinSpellV2Integration.sol)

Functions:

1. addLiquidityWMiniChef: Leverage, provide liquidity to the pool and stake LP to the staking contract.
2. removeLiquidityWMiniChef: unstake LP, remove liquidity from the pool and repay a loan.
3. harvestWMiniChefRewards: collect minichef rewards.

Decoding wrapper token ID on WMiniChefV2PNG
|parameters|description|
|---|---|
|pid|pool id in Pangolin's minichef|
|rewardPerShare|latest-updated accumulated reward per share <br> (being used for calculating pending reward)|

```solidity=
IBankAVAX bank = IBankAVAX(0x376d16C7dE138B01455a51dA79AD65806E9cd694);
uint256 positionId = 123; // change position id here
(
    ,
    address collateralTokenAddress,
    uint256 collateralId,
    uint256 collateralAmount
) = bank.getPositionInfo(positionId);

IWMiniChefV2PNG wrapper = IWMiniChefV2PNG(collateralTokenAddress);
(uint256 pid, uint256 rewardPerShare) = wrapper.decodeId(
    collateralId
);
```

## Appendix A: Contract addresses

| Name                                                                                   | Contract address                                                                                                           |
| -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| HomoraBank                                                                             | [0x376d16C7dE138B01455a51dA79AD65806E9cd694](https://snowtrace.io/address/0x376d16C7dE138B01455a51dA79AD65806E9cd694#code) |
| TraderJoeSpellV1 <br> (For pool <br>WAVAX-DAI.e, <br>USDC.e-USDT.e, <br> USDC.e-DAI.e) | [0xdBc2Aa11Aa01bAa22892dE745C661Db9f204b2cd](https://snowtrace.io/address/0xdBc2Aa11Aa01bAa22892dE745C661Db9f204b2cd#code) |
| TraderJoeSpellV2 (WAVAX-ALPHA.e)                                                       | [0x011993c940a639EFaC34bD54F24D2CF3E3002214](https://snowtrace.io/address/0x011993c940a639EFaC34bD54F24D2CF3E3002214#code) |
| TraderJoeSpellV3 (WAVAX-USDC)                                                          | [0x28F1BdBc52Ad1aAab71660f4B33179335054BE6A](https://snowtrace.io/address/0x28F1BdBc52Ad1aAab71660f4B33179335054BE6A#code) |
| TraderJoeSpellV3 (WAVAX-WETH.e)                                                        | [0xEFF3168dcF49126d185EF561C793Fe6d95A049A3](https://snowtrace.io/address/0xEFF3168dcF49126d185EF561C793Fe6d95A049A3#code) |
| TraderJoeSpellV3 (WAVAX-USDT.e)                                                        | [0x05edD168030A821d6afDbd6b1134348870E08520](https://snowtrace.io/address/0x05edD168030A821d6afDbd6b1134348870E08520#code) |
| TraderJoeSpellV3 (WAVAX-USDC.e)                                                        | [0x7a5FF9C975C315174ECD431e9DaC80Adfac1e3b5](https://snowtrace.io/address/0x7a5FF9C975C315174ECD431e9DaC80Adfac1e3b5#code) |
| TraderJoeSpellV3 (WAVAX-MIM)                                                           | [0xb2dF53045CF398715a8B2c94F679B4Dcb11A0Bc8](https://snowtrace.io/address/0xb2dF53045CF398715a8B2c94F679B4Dcb11A0Bc8#code) |
| TraderJoeSpellV3 (WAVAX-WBTC.e)                                                        | [0x6ECB26F5c2d167f5E724F24edA63020b61c289Ed](https://snowtrace.io/address/0x6ECB26F5c2d167f5E724F24edA63020b61c289Ed#code) |
| TraderJoeSpellV3 (USDC-USDC.e)                                                         | [0x5842728aB97c8920C210FA88a2eDCcAE1C80d720](https://snowtrace.io/address/0x5842728aB97c8920C210FA88a2eDCcAE1C80d720#code) |
| TraderJoeSpellV3 (WAVAX-LINK.e)                                                        | [0xbc648e5f7BFd01306eD96476C34f25a7D28aC82b](https://snowtrace.io/address/0xbc648e5f7BFd01306eD96476C34f25a7D28aC82b#code) |
| PangolinSpellV2                                                                        | [0x966bbec3ac35452133B5c236b4139C07b1e2c9b1](https://snowtrace.io/address/0x966bbec3ac35452133B5c236b4139C07b1e2c9b1#code) |
| WMasterchefJoeV2 <br> (For pool <br>WAVAX-DAI.e, <br>USDC.e-USDT.e, <br> USDC.e-DAI.e) | [0xbc648e5f7BFd01306eD96476C34f25a7D28aC82b](https://snowtrace.io/address/0xbc648e5f7BFd01306eD96476C34f25a7D28aC82b#code) |
| WMasterchefJoeV3 (ALPHA.e-WAVAX)                                                       | [0x8bbAf67ceB8EED2D5afC5d7786dEeAbA8268FD4a](https://snowtrace.io/address/0x8bbAf67ceB8EED2D5afC5d7786dEeAbA8268FD4a#code) |
| WBoostedMasterchefJoeV3 (WAVAX-USDC)                                                   | [0xAb80758cEC0A69a49Ed1c9B3F114cF98118643f0](https://snowtrace.io/address/0xAb80758cEC0A69a49Ed1c9B3F114cF98118643f0#code) |
| WBoostedMasterchefJoeV3 (WETH.e-WAVAX)                                                 | [0xdA255a9126fcA3a2Db4BBb991816F3e6564c003c](https://snowtrace.io/address/0xdA255a9126fcA3a2Db4BBb991816F3e6564c003c#code) |
| WBoostedMasterchefJoeV3 (USDT.e-WAVAX)                                                 | [0xE2f6c8c5AE8F07D0A2E16a7e43Fbab476257B9ef](https://snowtrace.io/address/0xE2f6c8c5AE8F07D0A2E16a7e43Fbab476257B9ef#code) |
| WBoostedMasterchefJoeV3 (USDC.e-WAVAX)                                                 | [0x8DF47fc33DF77Ae0526cDAC4A0CA89739EF9f1Cc](https://snowtrace.io/address/0x8DF47fc33DF77Ae0526cDAC4A0CA89739EF9f1Cc#code) |
| WBoostedMasterchefJoeV3 (MIM-WAVAX)                                                    | [0xd885E488EaE40c9f9e4867e1DC7Ae26684083150](https://snowtrace.io/address/0xd885E488EaE40c9f9e4867e1DC7Ae26684083150#code) |
| WBoostedMasterchefJoeV3 (WBTC.e-WAVAX)                                                 | [0xc32CB9d28b257ce286F4A1C01222171F55a6F7f9](https://snowtrace.io/address/0xc32CB9d28b257ce286F4A1C01222171F55a6F7f9#code) |
| WBoostedMasterchefJoeV3 (USDC-USDC.e)                                                  | [0x652A76731A6Db7249A7AeB43F824ebFc022488D2](https://snowtrace.io/address/0x652A76731A6Db7249A7AeB43F824ebFc022488D2#code) |
| WBoostedMasterchefJoeV3 (LINK.e-WAVAX)                                                 | [0x74a750B929ffD9141262d1542381366d139fE234](https://snowtrace.io/address/0x74a750B929ffD9141262d1542381366d139fE234#code) |
| WMiniChefV2PNG                                                                         | [0xa67CF61b0b9BC39c6df04095A118e53BFb9303c7](https://snowtrace.io/address/0xa67CF61b0b9BC39c6df04095A118e53BFb9303c7#code) |

Many wrapper contracts are implemented to support different pools' reward contract. Even the pools are in the same DEX, the reward contract may be different, e.g. Masterchef contract, Minichef contract),

Following table describes what wrapper contract types use which spell contracts.

| Pool                                                                                                                                              | Wrapper contracts       | Spell contracts  |
| ------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- | ---------------- |
| TraderJoe pools:<br>WAVAX-DAI.e, <br>USDC.e-USDT.e, <br>USDC.e-DAI.e                                                                              | WMasterchefJoeV2        | TraderJoeSpellV1 |
| TraderJoe pools:<br>ALPHA.e-WAVAX                                                                                                                 | WMasterchefJoeV3        | TraderJoeSpellV2 |
| TraderJoe pools:<br>WAVAX-USDC,<br>WETH.e-WAVAX,<br>USDT.e-WAVAX,<br>USDC.e-WAVAX,<br>MIM-WAVAX,<br>WBTC.e-WAVAX,<br>USDC-USDC.e,<br>LINK.e-WAVAX | WBoostedMasterchefJoeV3 | TraderJoeSpellV3 |
| every pool in <br>Pangolin Exchange                                                                                                               | WMiniChefV2PNG          | PangolinSpellV2  |

## How to run tests

- make sure you have installed [Foundry](https://book.getfoundry.sh/getting-started/installation)
- compile project

```sh
forge build
```

- run tests

```sh
forge test --contracts tests/avax -vv --fork-url <AVAX_RPC_URL> --via-ir
```
