# The Protocol

## Background: Hash functions

One of the key features of a smart contract is trustless. Neither Alice nor Bob can cheat in the process, and no third party can tamper with the result. In addition, we should incentive all parties to act accordingly and punish actions that are not expected.

This means there are a few criteria:

1. Alice and Bob don’t know the other party’s choice before their submission.
2. Alice and Bob cannot change their choice after their submission.
3. Third parties cannot tamper with Alice’s and Bob’s choices.
4. The smart contract can determine who won and distribute the money.
5. If either party cheats, they will lose their deposit to the other party.

To achieve this, we can use a kind of cryptographic function called [hash functions](https://en.wikipedia.org/wiki/Hash_function). **Hash functions** are one-way functions that map any data to a fixed-size number. This means a few things:

- Given the same data, it will always generate the same hash.
- Given a different set of data, it will always generate a different hash.
- When given a hash, it’s impossible to guess or know what is the data that generated this hash.

## Implementing the Protocol

1. Alice and Bob pick their own choice and generate a nonce (a large random number) on their own. Concatenate their choice with the nonce into a string. Compute the hash of the concatenated string and submit it to the smart contract.
2. After both parties submitted their hash, they can reveal their choice and the nonce. The smart contract verifies that this choice and nonce is consistent with the submitted hash, and then stores the choice.
3. After both parties revealed their choice, the program computes the result and distributes the price.

## Handling Edge Cases

We need to handle edge cases in a smart contract to avoid one party “locking” the other party's money by not acting as expected. This mechanism assumes both players are **rational**, meaning they will try to maximize their gain even if they have to cheat, but they will not try to hurt others if it also hurt themselves.

- If either party did not submit their hash, the other party can refund their deposit.
- If either party did not reveal their choice after submitting their hash, they will lose their bet and the other party will get all the money.
- If both parties did not reveal their choice after submitting their hash, the deposit is redistributed.

## Why does this protocol prevent Alice or Bob from cheating?

Neither party can cheat in this contract because they must commit their choice with the hash.

First, they cannot change their hash after the submission. As hashes are unique, changing the choice will result in a different hash. The hash is stored in the contract, and everyone can verify that the choice and nonce provided is the one specified by the hash.

Second, the other party will not know others’ choices because hashes are hiding. Adding a random nonce to the submission means the other party cannot brute force or revert the hash to find the other’s choice.

## Why does this protocol prevent third parties from tampering?

No third party can tamper with the game because of the hash.

First, Alice and Bob publish their hash or choice to the network. In a decentralized network, assuming half of the mining power is honest, sending the transaction to multiple nodes around the world guarantee no one can censor their choice. Everyone can verify that what is executed in the blockchain is what the two players published.

Second, the hash can only be submitted by the two players as required in the code. The message sender must be the two addresses hardcoded. (You can modify the contract to accept anyone to play the game by allowing anyone to participate in the commit hash phase.)

Third, with the hash submitted, no one can change the choice selected by the two players as explained above, changing their choice or nonce will not produce the same hash.
