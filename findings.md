### [S-#] Looping through players array to check for duplicates in `PuppyRaffle::enterRaffle` is a potential denial of service (DoS) attack vector, incrementing gas costs for future entrants.

**Description:** The `PuppyRaffle::enterRaffle` function loops through the `players` array to check for duplicates. However, the longer the `PuppyRaffle::players` array is, the more checks a new player will haver to make. This means the gas costs for players who enter right when the raffle starts, will be dramatically lower than those who enter later. Every additional address in the `players` array is an additional check the loop will have to make.

```javascript
        // @audit DoS
@>      for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
```

**Impact:** The gas costs for raffle entrants will greatly increasse as more players enter the raffle, discouraging later users from entering, and causing a rush at the start to be one of the first entrants in the queue.

An attacker might make the `PuppyRaffle::enterRaffle` array so big that no one else enters, guaranteeing themselves the win.

**Proof of Concept:** If we have 2 sets of 100 players enter, the gas costs will be as such:
- 1st 100 players: ~6252039 gas
- 2nd 100 players: ~18068129 gas

This is more than 3 times more expensive for the second players.

<details>
<summary>PoC</summary>
Place the following test into `PuppyRaffleTest.t.sol`.

```javascript
    function testDosVulnerability() external {
        uint256 numPlayers = 100;
        address[] memory players = new address[](numPlayers);
        for (uint256 i = 0; i < numPlayers; i++) {
            players[i] = address(i);
        }
        uint256 gasStart = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * numPlayers}(players);
        uint256 gasEnd = gasleft();
        uint256 gasSpentFirst100 = gasStart - gasEnd;
        console.log("Gas cost to enter for the first 100 players", gasSpentFirst100);

        address[] memory playersTwo = new address[](numPlayers);
        for (uint256 i = 0; i < numPlayers; i++) {
            players[i] = address(numPlayers + i);
        }
        uint256 gasStartTwo = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * numPlayers}(players);
        uint256 gasEndTwo = gasleft();
        uint256 gasSpentSecond100 = gasStartTwo - gasEndTwo;
        console.log("Gas cost to enter for the first 100 players", gasSpentSecond100);

        assert(gasSpentSecond100 > gasSpentFirst100);
    }
```
</details>

**Recommended Mitigation:**

1. Consider allowing duplicates. Users can make new wallet addresses anyway, so a duplicate check doesn't prevent the same person from entering multiple times, only the same wallet addresses.
2. Consider using a mapping to check for duplicates. This would allow constant time lookup of whether a user has already entered.

```diff

```

**Proof of Code**

<details>
<summary>Code</summary>

Place the following into `PuppyRaffleTest.t.sol`

```javascript
    function testUint64Overflow() public playersEntered {
        // We finish a raffle of 4 to collect some fees
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);
        puppyRaffle.selectWinner();
        uint256 startingTotalFees = puppyRaffle.totalFees();
        // startingTotalFees = 800000000000000000

        // We then have 89 players enter a new raffle
        uint256 playersNum = 89;
        address[] memory players = new address[](playersNum);
        for (uint256 i = 0; i < playersNum; i++) {
            players[i] = address(i);
        }
        puppyRaffle.enterRaffle{value: entranceFee * playersNum}(players);
        // We end the raffle
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        // And here is where the issue occurs
        // We will now have fewer fees even though we just finished a second raffle
        puppyRaffle.selectWinner();

        uint256 endingTotalFees = puppyRaffle.totalFees();
        console.log("ending total fees", endingTotalFees);
        assert(endingTotalFees < startingTotalFees);

        // We are also unable to withdraw any fees because of the require check
        vm.prank(puppyRaffle.feeAddress());
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }
```
</details>

