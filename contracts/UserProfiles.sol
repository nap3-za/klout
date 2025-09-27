// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UserProfiles {
    struct UserStats {
        // self-explanatory attributes
        uint totalWagers;
        uint correctWagers;
        int netWinsLosses;
        uint biggestWin;
        uint biggestLoss;
        uint accuracy; // 0-100
    }

    mapping(address => UserStats) private _stats;
    mapping(address => uint256[]) private _timeline;

    event UserUpdated(address indexed user, uint totalWagers, uint correctWagers, int netWinsLosses);

    // called by WagerManager
    function updateStats(
        address user,
        bool wasCorrect,
        int256 netChange,
        uint256 absAmount
    ) external {
        UserStats storage s = _stats[user];

        s.totalWagers++;
        if (wasCorrect) {
            s.correctWagers++;
            s.netWinsLosses += netChange;
            if (absAmount > s.biggestWin) s.biggestWin = absAmount;
        } else {
            s.netWinsLosses -= netChange;
            if (absAmount > s.biggestLoss) s.biggestLoss = absAmount;
        }

        s.accuracy = s.totalWagers > 0 ? (s.correctWagers * 100) / s.totalWagers : 0;

        _timeline[user].push(absAmount);

        emit UserUpdated(user, s.totalWagers, s.correctWagers, s.netWinsLosses);
    }

    // read functions
    function getStats(address user) external view returns (UserStats memory) {
        return _stats[user];
    }

    function getTimeline(address user) external view returns (uint256[] memory) {
        return _timeline[user];
    }
}
