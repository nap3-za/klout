// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UserProfiles {
    struct UserStats {
        // self explanatory attributes
        uint totalWagers;
        uint correctWagers;
        int netWinsLosses;
        uint biggestWin;
        uint biggestLoss;
    }

    mapping(address => UserStats) public stats;

    event UserUpdated(address indexed user, uint totalWagers, uint correctWagers);

    function recordWagerResult(
        address user,
        bool won,
        uint amount
    ) external {
        UserStats storage s = stats[user];
        s.totalWagers++;

        if (won) {
            s.correctWagers++;
            s.netWinsLosses += int(amount);
            if (amount > s.biggestWin) {
                s.biggestWin = amount;
            }
        } else {
            s.netWinsLosses -= int(amount);
            if (amount > s.biggestLoss) {
                s.biggestLoss = amount;
            }
        }

        emit UserUpdated(user, s.totalWagers, s.correctWagers);
    }

    function getAccuracy(address user) external view returns (uint) {
        UserStats memory s = stats[user];
        if (s.totalWagers == 0) return 0;
        return (s.correctWagers * 100) / s.totalWagers;
    }
}
