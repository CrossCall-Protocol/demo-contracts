Smart contracts relevant for the MVP of Lamina Finance DEX.

Simulations include the operations that need to interface with Luban. For brevity of this demo it is acknowledged that there will not be searchers but rather a centralized relayer.

Basic bridge request will be, for now, a two part request:
1. lock funds
2. submit signed userop that sends funds from SCW to another address (this can be EOA or the SCW itself)

Tx bytecode for Simple Account Wallet (default wallet):
```
0xb61d27f6000000000000000000000000[target][amount]0000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000
```

We require to complete the tx circuit and refund the executor (bundler/ solver) of the bridge, the transaction must execute through account abstraction with the Luban paymaster


## Deployments:
| Chain             | EntryPoint                                 | SimpleAccountFactory                         | Singleton                                  |
|-------------------|--------------------------------------------|----------------------------------------------|--------------------------------------------|
| Botanix Testnet   | 0xd9bea83c659a3d8317a8f1fecdc6fe5b3298aecc | 0x262e2a64864d00E69F1c4455a34391Ae62577716 | 0xfF376454E984Bb12b969221d85fB05eC8e02C168 |
| Ethereum Sepolia | 0xA01F675b2839e4104ca5deAb898e49fFa4a8f7d3 | 0x8d123E05cc7d2Eb0d411Ef727160E726F73Da3D2 | 0x321F7bD506D273C9b37E1535aF2BE1787d2cdCE1 |


Flow:
Frontend makes request to Lamina API
Lamina API creates the transactions calldata to be executed, min assets required, min assets out
Lamina API sends calldata, and data to Luban to create userup and lock request data
Luban will return the userop with nessicary changes and lock request
both transaction requests will be signed and returned to Luban
Luban will execute the signed lock request, and then validate the userop
Userop is (skipping uopool) will get executed by Luban's solver

Lamina API needs to return the spot exchange ETH-BTC

## Chores

- [x] create the calldata for the exection of a basic native token transfer
- [x] log native execution gas cost
- [x] create userop for user calldata
- [x] log native execution gas cost
- [ ] create userop for funding the paymaster, probably will actually be a preop hook within a forced custom multicall
- [x] create userop for funding the wallet
- [ ] validate calldata for propergas estimation rather than winging it (silius-mod bundler)
- [x] execute handleOps for tx in canonical order
- [x] create simulation of txs to execute the calldata
- [x] make escrow logic also upgradeable

| Chain            | EntryPoint                                 | SimpleAccountFactory                       | Singleton                                  |
|------------------|--------------------------------------------|--------------------------------------------|--------------------------------------------|
| Ethereum Sepolia | 0xA01F675b2839e4104ca5deAb898e49fFa4a8f7d3 | 0x8d123E05cc7d2Eb0d411Ef727160E726F73Da3D2 | 0x321F7bD506D273C9b37E1535aF2BE1787d2cdCE1 |
| Bitlayer Testnet | 0x91fd3b4b985ad802f273482876379c98a8810f0c | 0xaf3CfE0635B21B395CeC0F8E21761b764e73B568 |                                            |

| Chain                    | Domain   | Mailbox Address (Test)                     | IGP Address (Test)                         |
|--------------------------|----------|--------------------------------------------|--------------------------------------------|
| Ethereum Sepolia         | 11155111 | 0x18efAF9709E122c1fdbdA7fcb3259840CfbE1550 | 0xD564C44672330B42f806Fc9820e15B7663C13EAD |
| Bitlayer Testnet         | 200810   | 0xFe471C7A8a63875709Af4840BD5E2F00B7C0b82d | 0x6DEead0c7d78CbFd2Aed52B8ac5e430453e3580b |

| Chain             | Multicall3                                 |
|-------------------|--------------------------------------------|
| Ethereum Sepolia  | 0xcA11bde05977b3631167028862bE2a173976CA11 |
| Bitlayer Testnet  | 0x9A3F2C7aB045a3A4De4784Ec02234e87b589b1aC |

| Chain             | Escrow                                     | Escrow Factory                             | Paymaster                                  |
|-------------------|--------------------------------------------|--------------------------------------------|--------------------------------------------|
| Ethereum Sepolia  | 0x69dE29032d6C4BE013e13ed4a9dB90a11b1CdE94 | 0xE2FDD64ce12142c7FE4BAa2Eb98760A46D2Fab40 | 0xA12d0ed7F1e3718B2e64382Dc191B3b7B1dE2238 |
| Bitlayer Testnet  | 0xF93bBF2F6fe9e346811C4B63D2D3c4b6587204e1 | 0xF1e8B4d5987f3906B206F587C94812Df0dd65995 | 0xfd3147bEA6681D828359e6EF79442164CFE576c4 |

| Chain             | Multicall                                  |
|-------------------|--------------------------------------------|
| Ethereum Sepolia  | 0x829fA38396f38b1619acE91fE4b0D880FD8e9f98 |
| Bitlayer Testnet  | 0x8cb36953c0c41795585043f195d7ba3ba4d82ce3 |

Only test relay authority
0x74989DF6077Ddc4da81a640b514E6a372ff7217E


200810
  EntryPoint deployed:  0x317bBdFbAe7845648864348A0C304392d0F2925F
  EntryPointSimulations: 0x6960fA06d5119258533B5d715c8696EE66ca4042
  SimpleAccountFactory deployed:  0xCF730748FcDc78A5AB854B898aC24b6d6001AbF7
  SimpleAccount: 0xfaAe830bA56C40d17b7e23bfe092f23503464114
  Multicall deployed:  0x66e4f2437c5F612Ae25e94C1C549cb9f151E0cB3
  HyperlaneMailbox deployed:  0x2EaAd60F982f7B99b42f30e98B3b3f8ff89C0A46
  HyperlaneIGP deployed:  0x16e81e1973939bD166FDc61651F731e1658060F3
  Paymaster deployed:  0xdAE5e7CEBe4872BF0776477EcCCD2A0eFdF54f0e
  Escrow deployed:  0x9925D4a40ea432A25B91ab424b16c8FC6e0Eec5A
  EscrowFactory deployed:  0xC531388B2C2511FDFD16cD48f1087A747DC34b33

17000
  EntryPoint deployed:  0xc5Ff094002cdaF36d6a766799eB63Ec82B8C79F1
  EntryPointSimulations: 0x67B9841e9864D394FDc02e787A0Ac37f32B49eC7
  SimpleAccountFactory deployed:  0x39351b719D044CF6E91DEC75E78e5d128c582bE7
  SimpleAccount: 0x0983a4e9D9aB03134945BFc9Ec9EF31338AB7465
  Multicall deployed:  0x98876409cc48507f8Ee8A0CCdd642469DBfB3E21
  HyperlaneMailbox deployed:  0x913A6477496eeb054C9773843a64c8621Fc46e8C
  HyperlaneIGP deployed:  0x2Fb9F9bd9034B6A5CAF3eCDB30db818619EbE9f1
  Paymaster deployed:  0xA5bcda4aA740C02093Ba57A750a8f424BC8B4B13
  Escrow deployed:  0x686130A96724734F0B6f99C6D32213BC62C1830A
  EscrowFactory deployed:  0x45d5D46B097870223fDDBcA9a9eDe35A7D37e2A1

11155111
  EntryPoint deployed:  0xA6eBc93dA2C99654e7D6BC12ed24362061805C82
  EntryPointSimulations: 0x0d17dE0436b65279c8D7A75847F84626687A1647
  SimpleAccount: 0x8156549F50de1A88329839C4679fc62626e2B5c6
  SimpleAccountFactory deployed:  0x54bed3E354cbF23C2CADaB1dF43399473e38a358
  Multicall deployed:  0x6958206f218D8f889ECBb76B89eE9bF1CAe37715
  HyperlaneMailbox deployed:  0xAc165ff97Dc42d87D858ba8BC4AA27429a8C48e8
  HyperlaneIGP deployed:  0x00eb6D45afac57E708eC3FA6214BFe900aFDb95D
  Paymaster deployed:  0x31aCA626faBd9df61d24A537ecb9D646994b4d4d
  Escrow deployed:  0xea8D264dF67c9476cA80A24067c2F3CF7726aC4d
  EscrowFactory deployed:  0xd9842E241B7015ea1E1B5A90Ae20b6453ADF2723

3636
  EntryPoint deployed:  0xF7B12fFBC58dd654aeA52f1c863bf3f4731f848F
  EntryPointSimulations: 0x1db7F1263FbfBe5d91548B3422563179f6bE8d99
  SimpleAccountFactory deployed:  0xFB23dB8098Faf2dB307110905dC3698Fe27E136d
  SimpleAccount: 0x15aA997cC02e103a7570a1C26F09996f6FBc1829
  Multicall deployed:  0x6cB50ee0241C7AE6Ebc30A34a9F3C23A96098bBf
  HyperlaneMailbox deployed:  0xd2DB8440B7dC1d05aC2366b353f1cF205Cf875EA
  HyperlaneIGP deployed:  0x8439DBdca66C9F72725f1B2d50dFCdc7c6CBBbEb
  Paymaster deployed:  0xbbfb649f42Baf44729a150464CBf6B89349A634a
  Escrow deployed:  0xCD77545cA802c4B05ff359f7b10355EC220E7476
  EscrowFactory deployed:  0xA6eBc93dA2C99654e7D6BC12ed24362061805C82