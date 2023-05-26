pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/comparators.circom";
include "./lib/account_leaf/sliding_bounded_congestion_account_leaf.circom";
include "./base/base_state_update.circom";

// Processes the base state update of 2**n accounts as a result of 2**m update transactions
template SlidingBoundedCongestionStateUpdate(n, m) {
    // The block number for the last verification that was recorded on chain
    // Starts at 0 on deployment block
    signal input lastBlock;

    // Transaction tree root
    signal input txRoot;
    // Paths for transaction inclusion Merkle proofs
    signal input txRootSiblings[2**m][n];
    signal input txRootPathIndices[2**m][n];

    // Current state of the accounts tree
    signal input accountsRoot;
    // Intermediate states of the accounts tree after every update tx
    signal input intermediateAccountsRoots[2**(m + 1) + 1];

    // Paths for from account inclusion Merkle proofs
    signal input fromTreeSiblings[2**m][n];
    signal input fromTreePathIndices[2**m][n];

    // Paths for to account inclusion Merkle proofs
    signal input toTreeSiblings[2**m][n];
    signal input toTreePathIndices[2**m][n];

    // Transaction information
    signal input fromX[2**m];  // sender account x coordinate
    signal input fromY[2**m];  // sender account y coordinate
    signal input toX[2**m];  // reciever account x coordinate
    signal input toY[2**m];  // receiver account y coordinate
    signal input fromNonce[2**m];  // sender account nonce
    signal input amount[2**m];  // amount being transferred

    // Transaction signature validation
    signal input R8x[2**m];
    signal input R8y[2**m];
    signal input S[2**m];

    // Additional info not included in signed transaction
    signal input fromBalance[2**m];  // sender account balance

    // SIMPLE STATE UPDATE -- ACCOUNT LEAF ADDITIONAL VALUES
    signal input toBalance[2**m];  // receiver account balance
    signal input toNonce[2**m];  // receiver account nonce

    // Congestion control values
    signal input fromCurrentPlan[2**m][2];
    signal input fromLastOnline[2**m];
    signal input fromCredits[2**m];
    signal input fromBlockTransactions[2**m];
    signal input toCurrentPlan[2**m][2];
    signal input toLastOnline[2**m];
    signal input toCredits[2**m];
    signal input toBlockTransactions[2**m];

    signal output newAccountsRoot;

    // COMPUTING THE SENDER AND RECEIVER LEAVES -- SLIDING BOUNDED CONGESTION
    component senderLeaves[2**m][2];
    component receiverLeaves[2**m][2];
    
    // Components for verifying spam prevention
    component comparators[2**m][2];
    component sameBlock[2**m];

    for (var i = 0; i < 2**m; i++) {
        // Initial state
        senderLeaves[i][0] = SlidingBoundedCongestionAccountLeaf();
        senderLeaves[i][0].X <== fromX[i];
        senderLeaves[i][0].Y <== fromY[i];
        senderLeaves[i][0].balance <== fromBalance[i];
        senderLeaves[i][0].nonce <== fromNonce[i];
        senderLeaves[i][0].currentPlan[0] <== fromCurrentPlan[i][0];
        senderLeaves[i][0].currentPlan[1] <== fromCurrentPlan[i][1];
        senderLeaves[i][0].lastOnline <== fromLastOnline[i];
        senderLeaves[i][0].credits <== fromCredits[i];
        senderLeaves[i][0].blockTransactions <== fromBlockTransactions[i];

        // SLIDING BOUNDED CONGESTION SPAM PREVENTION
        sameBlock[i] = IsZero();
        sameBlock[i].in <== lastBlock - fromLastOnline[i];

        // Here we enforce that fromCurrentPlan >= fromBlockTransactions[i] * sameBlock + 1, as the number of `fromBlockTransactions` can only increase one by one
        comparators[i][0] = IsEqual();
        comparators[i][0].in[0] <== fromCurrentPlan[i][1] + 1; 
        comparators[i][0].in[1] <== fromBlockTransactions[i] * sameBlock[i].out + 1;

        comparators[i][0].out === 0;

        // After debiting amount
        senderLeaves[i][1] = SlidingBoundedCongestionAccountLeaf();
        senderLeaves[i][1].X <== fromX[i];
        senderLeaves[i][1].Y <== fromY[i];
        senderLeaves[i][1].balance <== fromBalance[i] - amount[i];
        senderLeaves[i][1].nonce <== fromNonce[i] + 1;
        senderLeaves[i][1].currentPlan[0] <== fromCurrentPlan[i][0];
        senderLeaves[i][1].currentPlan[1] <== fromCurrentPlan[i][1];
        senderLeaves[i][1].lastOnline <== lastBlock;
        senderLeaves[i][1].credits <== fromCredits[i] + fromCurrentPlan[i][1] * (lastBlock - fromLastOnline[i]) - 1;
        senderLeaves[i][1].blockTransactions <== fromBlockTransactions[i] * sameBlock[i].out + 1;
        
        // Initial state
        receiverLeaves[i][0] = SlidingBoundedCongestionAccountLeaf();
        receiverLeaves[i][0].X <== toX[i];
        receiverLeaves[i][0].Y <== toY[i];
        receiverLeaves[i][0].balance <== toBalance[i];
        receiverLeaves[i][0].nonce <== toNonce[i];
        receiverLeaves[i][0].currentPlan[0] <== toCurrentPlan[i][0];
        receiverLeaves[i][0].currentPlan[1] <== toCurrentPlan[i][1];
        receiverLeaves[i][0].lastOnline <== toLastOnline[i];
        receiverLeaves[i][0].credits <== toCredits[i];
        receiverLeaves[i][0].blockTransactions <== toBlockTransactions[i];

        // After crediting amount
        receiverLeaves[i][1] = SlidingBoundedCongestionAccountLeaf();
        receiverLeaves[i][1].X <== toX[i];
        receiverLeaves[i][1].Y <== toY[i];
        receiverLeaves[i][1].balance <== toBalance[i] + amount[i];
        receiverLeaves[i][1].nonce <== toNonce[i];
        receiverLeaves[i][1].currentPlan[0] <== toCurrentPlan[i][0];
        receiverLeaves[i][1].currentPlan[1] <== toCurrentPlan[i][1];
        receiverLeaves[i][1].lastOnline <== toLastOnline[i];
        receiverLeaves[i][1].credits <== toCredits[i];
        receiverLeaves[i][1].blockTransactions <== toBlockTransactions[i];
    }

    component baseStateUpdate = BaseStateUpdate(n, m);

    baseStateUpdate.txRoot <== txRoot;
    baseStateUpdate.accountsRoot <== accountsRoot;
        
    // FILLING UP ALL THE BASE STATE UPDATE VALUES
    for (var i = 0; i < 2**m; i++) {
        for (var j = 0; j < n; j++) {
            baseStateUpdate.txRootSiblings[i][j] <== txRootSiblings[i][j];
            baseStateUpdate.txRootPathIndices[i][j] <== txRootPathIndices[i][j];

            baseStateUpdate.fromTreeSiblings[i][j] <== fromTreeSiblings[i][j];
            baseStateUpdate.fromTreePathIndices[i][j] <== fromTreePathIndices[i][j];

            baseStateUpdate.toTreeSiblings[i][j] <== toTreeSiblings[i][j];
            baseStateUpdate.toTreePathIndices[i][j] <== toTreePathIndices[i][j];
        }

        baseStateUpdate.fromX[i] <== fromX[i];
        baseStateUpdate.fromY[i] <== fromY[i];
        baseStateUpdate.toX[i] <== toX[i];
        baseStateUpdate.toY[i] <== toY[i];
        baseStateUpdate.fromNonce[i] <== fromNonce[i];
        baseStateUpdate.amount[i] <== amount[i];

        baseStateUpdate.R8x[i] <== R8x[i];
        baseStateUpdate.R8y[i] <== R8y[i];
        baseStateUpdate.S[i] <== S[i];

        baseStateUpdate.fromBalance[i] <== fromBalance[i];

        baseStateUpdate.senderLeaves[i][0] <== senderLeaves[i][0].out;
        baseStateUpdate.senderLeaves[i][1] <== senderLeaves[i][1].out;

        baseStateUpdate.receiverLeaves[i][0] <== receiverLeaves[i][0].out;
        baseStateUpdate.receiverLeaves[i][1] <== receiverLeaves[i][1].out;
    }

    for (var k = 0; k < 2**(m + 1) + 1; k++) {
        baseStateUpdate.intermediateAccountsRoots[k] <== intermediateAccountsRoots[k];
    }

    newAccountsRoot <== baseStateUpdate.out;
}

component main {public [
    lastBlock,
    txRoot, 
    accountsRoot
]} = SlidingBoundedCongestionStateUpdate(4, 2);
