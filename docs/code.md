# The Code

I will explain the contract part by part below. Find the full code [here](/rps.sol).

_Please be reminded that this code is not independently audited, use it at your own risk. However, I did try my best to avoid any common vulnerabilities and I will explain them below._

First, all solidity smart contracts are in this format:

```Solidity
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.0 <0.9.0;

contract rps {

    // code goes here

}

```

We will first define some global variables for the smart contract on top:

```Solidity
contract rps {
    uint256 public startBlock = block.number;

    address constant alice = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address constant bob = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;

    bytes32 aliceHash;
    bytes32 bobHash;

    enum Choice {
        Empty,
        Rock,
        Paper,
        Scissor
    }

    Choice public aliceChoice = Choice.Empty;
    Choice public bobChoice = Choice.Empty;

    bool gameEnded = false;

    mapping(address=>uint) public balances;
}
```

- `startBlock` is used to keep track of the starting block of this game. This is used to keep track of the time passed. The block number is the best thing to keep track of time because it cannot be manipulated by anyone.
- This smart contract hardcoded Alice’s and Bob’s addresses, you can set a function to accept anyone to participate.
- `aliceHash` and `bobHash` will store their hash. `aliceChoice` and `bobChoice` will stores their choices.
- `gameEnded` is to keep track of if the game has ended.
- `balances` is a mapping to keep track of how much money the smart contract owes a user. It can be used to avoid reentrancy attacks.

```Solidity
// commit the choice (Rock / Paper / Scissor)
function commitChoice(bytes32 hash) public payable {
    require(block.number < (startBlock + 100));
    require((msg.sender == alice && aliceHash == 0) || (msg.sender == bob && bobHash == 0), "not Alice or Bob");
    require(msg.value == 1 ether, "please pay to participate");

    if(msg.sender == alice) {
        aliceHash = hash;
    } else {
        bobHash = hash;
    }
}
```

The first function is `commitChoice`. It let Alice and Bob commit their hash. They have to commit their hash within the time frame `block.number < (startBlock+100)` and pay 1 ETH to the contract. The smart contract will store their hash.

```Solidity
// reveal the choice (Rock / Paper / Scissor)
function revealChoice(Choice choice, uint nonce) public {
    require(block.number >= (startBlock + 100) && block.number < (startBlock + 200));
    require(msg.sender == alice || msg.sender == bob, "not Alice or Bob");
    require(aliceHash != 0 && bobHash != 0, "someone did not submit hash");
    require(choice != Choice.Empty, "have to choose Rock/Paper/Scissor");

    if(msg.sender == alice) {
        if (aliceHash == sha256(abi.encodePacked(choice, nonce))) {
            aliceChoice = choice;
        }
    } else {
        if (bobHash == sha256(abi.encodePacked(choice, nonce))) {
            bobChoice = choice;
        }
    }
}
```

The second function is `revealChoice`. It let Alice and Bob reveal their choice. They have to submit their choice and nonce, the smart contract will check that if this combination is consistent with the submitted hash. If yes, the smart contract will store their choice.

Note that if someone did not submit their hash, this function cannot be called. By design, we should refund the deposit in another function.

```Solidity
// check the result
function findResult() public {
    require(block.number > (startBlock + 200));
    require(!gameEnded, "can only compute result once");
    require(aliceChoice != Choice.Empty && bobChoice != Choice.Empty, "someone did not reveal their choice");

    // draw
    if (aliceChoice == bobChoice) {
        balances[alice] += 1 ether;
        balances[bob] += 1 ether;
    } else if (aliceChoice == Choice.Rock) {
        if (bobChoice == Choice.Paper) {
            // alice: rock, bob: paper, bob win
            balances[bob] += 2 ether;
        } else {
            // alice: rock, bob: scissor, alice win
            balances[alice] += 2 ether;
        }
    } else if (aliceChoice == Choice.Paper) {
        if (bobChoice == Choice.Scissor) {
            // alice: paper, bob: scissor, bob win
            balances[bob] += 2 ether;
        } else {
            // alice: paper, bob: rock, alice win
            balances[alice] += 2 ether;
        }
    } else if (aliceChoice == Choice.Scissor) {
        if (bobChoice == Choice.Rock) {
            // alice: scissor, bob: rock, bob win
            balances[bob] += 2 ether;
        } else {
            // alice: scissor, bob: paper, alice win
            balances[alice] += 2 ether;
        }
    }

    gameEnded = true;
}
```

This function computes the result and adds the money to the users’ balance. This function can only be called when both players revealed their choice with `revealChoice`.

However, if Bob submitted a hash but did not reveal his choice, maybe because after Alice reveal her choice, he realise he lost. He might not reveal his choice so that the smart contract cannot determine who wins, hence the money is “locked” in the smart contract. Therefore, we should have a refund function to handle this situation.

```Solidity
// in case either party did not participate
function refundDeposit() public {
    bool didNotSubmitHash = block.number >= (startBlock + 100) && (aliceHash == 0 || bobHash == 0);
    bool didNotRevealChoice = block.number >= (startBlock + 200) && (aliceChoice == Choice.Empty || bobChoice == Choice.Empty);

    require(didNotSubmitHash || didNotRevealChoice);
    require(address(this).balance >= 1 ether);

    if (block.number >= (startBlock + 200)) {
        if (aliceChoice == Choice.Empty && bobChoice != Choice.Empty) {
            balances[bob] += 2 ether;
        } else if (aliceChoice != Choice.Empty && bobChoice == Choice.Empty) {
            balances[alice] += 2 ether;
        } else {
            balances[alice] += 1 ether;
            balances[bob] += 1 ether;
        }
    } else if (block.number >= (startBlock + 100)) {
        if (aliceHash == 0 && bobHash != 0) {
            balances[bob] += 1 ether;
        } else if (aliceHash != 0 && bobHash == 0) {
            balances[alice] += 1 ether;
        }
    }
}
```

There are two conditions that this function can be called:

- Someone did not submit a hash
- Someone did not reveal their choice

If someone did not submit a hash, the other person can refund their deposit, hence getting back 1 ETH.

If someone did not reveal their choice within the timeframe, the other person can refund their deposit and get the opponent’s deposit, hence getting 2 ETH.

Lastly, we need two more functions to make this game works. One is a function for people to claim their money from `balances` and a function to reset the game for the next round.

```Solidity
function claimMoney() public {
    require(msg.sender == alice || msg.sender == bob, "not Alice or Bob");
    require(balances[msg.sender] > 0);

    uint amount = balances[msg.sender];
    balances[msg.sender] = 0;
    bool transferred = payable(msg.sender).send(amount);
    if (transferred != true) {
        balances[msg.sender] = amount;
    }
}
```

This function uses the [send function](https://solidity-by-example.org/sending-ether) to send ETH to a player.

**Reentrancy attacks** mean a malicious player can trick the smart contract to call a malicious function when the smart contract is paying money to the player, and then this malicious function will call (reenter) the `claimMoney` function of this smart contract again.

If we directly send the amount of `balances[msg.sender]` to the user, without decrementing the balances before sending, the balances will still be positive and will still continue to send the money again and again, until the smart contract runs out of money.

This function handles reentrancy attacks by first saving the amount, clearing the balances, and then sending the amount. If the user reenters, its balances will be zero and hence cannot reenter the transfer process. If the transfer is unsuccessful, it set the balances back to the amount.

```Solidity
function resetAll() public {
    require(gameEnded || block.number > (startBlock + 300));
    startBlock = block.number;
    aliceHash = 0;
    bobHash = 0;
    aliceChoice = Choice.Empty;
    bobChoice = Choice.Empty;
    gameEnded = false;
}
```

This function reset the game and lets Alice or Bob can play the next round.

And that’s it! Let me know if you can find a bug and hope you learn something from this tutorial!
