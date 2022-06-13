// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.0 <0.9.0;

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

    function resetAll() public {
        require(gameEnded);
        startBlock = block.number;
        aliceHash = 0;
        bobHash = 0;
        aliceChoice = Choice.Empty;
        bobChoice = Choice.Empty;
        gameEnded = false;
    }

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
}