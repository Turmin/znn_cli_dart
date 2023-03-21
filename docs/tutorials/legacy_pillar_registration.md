# Registering a legacy Pillar

Once you have obtained a valid public key and signature needed to register a legacy Pillar, follow these instructions.\
If you are using a remote node, add the node's URL to the end the commands: `-u ws://127.0.0.1:35998`

## Step 1
Fuse 150 QSR as Plasma to the address you will be using for the Pillar.

## Step 2
Verify that the address you will be using for the Pillar has the required ZNN (15,000) and QSR (150,000).\
Add the `-i` flag to the end of the command and specify the index of the address you will be using for the Pillar.\
If you are using Syrius, you can view the address list to get the index of the address. The index of the first address is 0, the second one is 1, the third one is 2 etc.

**Windows**
```
.\znn-cli.exe balance -i 0
```

**macOS**
```
./znn-cli balance -i 0
```

## Step 3
Deposit the 150,000 QSR needed to register the Pillar. The QSR will be burned when the Pillar is registered.\
Again, add the `-i` flag to the end of the command to specify the index of the address.

**Windows**
```
.\znn-cli.exe pillar.depositQsr 150000 -i 0
```

**macOS**
```
./znn-cli pillar.depositQsr 150000 -i 0
```

## Step 4
Wait a short while and verify the QSR was deposited successfully.

**Windows**
```
.\znn-cli.exe pillar.getDepositedQsr -i 0
```

**macOS**
```
./znn-cli pillar.getDepositedQsr -i 0
```

## Step 5
Everything is now set up and the pillar can be registered. You should have obtained the `legacyPillarPubKey` and `legacyPillarSignature` from the seller of the legacy Pillar slot.\
Register the pillar with the following command. Replace the arguments with your own values and remember to add the `-i` flag to the end of the command to specify the index of the address you are using.\
**Double check that there are no typos in the name, since it cannot be changed once the Pillar has been registered.**

**Windows**
```
.\znn-cli.exe pillar.registerLegacy name producerAddress rewardAddress giveBlockRewardPercentage giveDelegateRewardPercentage legacyPillarPubKey legacyPillarSignature -i 0
```

**macOS**
```
./znn-cli pillar.registerLegacy name producerAddress rewardAddress giveBlockRewardPercentage giveDelegateRewardPercentage legacyPillarPubKey legacyPillarSignature -i 0
```

**Example command with real arguments:**
```
.\znn-cli.exe pillar.registerLegacy Anvil z1qzkd8urw7c4wg6x0cvd2nrzr4ke9d4zh0tvd8s z1qptjd99906x57ej6n55zvmsdm234lngrsreyc2 0 0 BGAjJAT6H2LkTDe3I1Iwoh2XGr+17u8gXI6k1bESJALhW/pInYwN8FEi8zCVUqQc55Tb+GpyP6MpiwCglm2M/Po= H0+k3lo/QvW+myeQ2GzKKjUWyJh96xERkiuyXStNNTocL+5NaCiTjC/b+E2NEHcT1jt/B3gf5L5T1rbXlCfA7VA= -i 0
```

## Step 6
Wait a short while and verify the Pillar was registered successfully by checking the Pillar list.

**Windows**
```
.\znn-cli.exe pillar.list
```

**macOS**
```
./znn-cli pillar.list
```
