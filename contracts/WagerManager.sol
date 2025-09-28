// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Address.sol";

interface IUserProfiles {
    function updateStats(
        address user,
        bool wasCorrect,
        int256 netChange,
        uint256 absAmount
    ) external;
}

contract WagerManager {
    using Address for address payable;

    enum Side { None, Yes, No }

    string constant bad_financial_position = "You're not in a good financial position to make this bet";
    string constant deadline_elapsed = "Deadline has elapsed";

    struct Wager {
        uint256 id;
        string topic;
        string category;
        address creator;
        uint256 deadline;
        uint256 yesStake;
        uint256 noStake;
        bool resolved;
        Side outcome;
        address[] yesParticipants;
        address[] noParticipants;
        mapping(address => uint256) yesBets;
        mapping(address => uint256) noBets;
        mapping(address => int8) reaction;
    }

    Wager[] public wagers;
    address public admin;
    IUserProfiles public profilesContract;

    // events
    event WagerCreated(uint256 indexed id, string topic, string category, address creator, uint256 deadline);
    event Staked(uint256 indexed id, address indexed user, Side side, uint256 amount, uint256 yesTotal, uint256 noTotal, uint256 timestamp);
    event StakeIncreased(uint256 indexed id, address indexed user, Side side, uint256 amount, uint256 yesTotal, uint256 noTotal);
    event ReactionUpdated(uint256 indexed id, address indexed user, int8 reaction);
    event WagerResolved(uint256 indexed id, Side outcome);
    event RewardClaimed(uint256 indexed id, address indexed user, uint256 amount);
    event OddsSnapshot(uint256 indexed id, uint256 yesTotal, uint256 noTotal, uint256 timestamp);
    event UserRegisteredOnWager(uint256 indexed id, address indexed user, Side side);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can perform this action");
        _;
    }

    constructor(address _profilesContract) {
        admin = msg.sender;
        profilesContract = IUserProfiles(_profilesContract);
    }

    function createWager(string calldata topic, string calldata category, uint256 deadline) external returns (uint256) {
        require(deadline > block.timestamp, deadline_elapsed);
        Wager storage w;
        uint256 id = wagers.length;
        wagers.push();
        w = wagers[id];
        w.id = id;
        w.topic = topic;
        w.category = category;
        w.creator = msg.sender;
        w.deadline = deadline;

        emit WagerCreated(id, topic, category, msg.sender, deadline);
        return id;
    }

    function stakeETH(uint256 id, bool isYes) external payable {
        require(msg.value > 0, bad_financial_position);
        _stake(id, msg.sender, isYes ? Side.Yes : Side.No, msg.value);
    }

    function _stake(uint256 id, address user, Side side, uint256 amount) internal {
        require(amount > 0, bad_financial_position);

        Wager storage w = wagers[id];
        require(block.timestamp < w.deadline, deadline_elapsed);

        if (side == Side.Yes) {
            if (w.yesBets[user] == 0) {
                w.yesParticipants.push(user);
                emit UserRegisteredOnWager(id, user, Side.Yes);
            }
            w.yesBets[user] += amount;
            w.yesStake += amount;
        } else {
            if (w.noBets[user] == 0) {
                w.noParticipants.push(user);
                emit UserRegisteredOnWager(id, user, Side.No);
            }
            w.noBets[user] += amount;
            w.noStake += amount;
        }

        emit Staked(id, user, side, amount, w.yesStake, w.noStake, block.timestamp);
        emit OddsSnapshot(id, w.yesStake, w.noStake, block.timestamp);
    }

    function increaseStakeETH(uint256 id, bool isYes) external payable {
        require(msg.value > 0, bad_financial_position);
        _increaseStake(id, msg.sender, isYes ? Side.Yes : Side.No, msg.value);
    }

    function _increaseStake(uint256 id, address user, Side side, uint256 amount) internal {
        require(amount > 0, bad_financial_position);
        Wager storage w = wagers[id];
        require(block.timestamp < w.deadline, deadline_elapsed);

        if (side == Side.Yes) {
            w.yesBets[user] += amount;
            w.yesStake += amount;
        } else {
            w.noBets[user] += amount;
            w.noStake += amount;
        }

        emit StakeIncreased(id, user, side, amount, w.yesStake, w.noStake);
        emit OddsSnapshot(id, w.yesStake, w.noStake, block.timestamp);
    }

    function react(uint256 id, int8 reactionValue) external {
        Wager storage w = wagers[id];
        w.reaction[msg.sender] = reactionValue;
        emit ReactionUpdated(id, msg.sender, reactionValue);
    }

    function resolveWager(uint256 id, bool yesOutcome) external {
        Wager storage w = wagers[id];
        require(msg.sender == w.creator || msg.sender == admin, "Only the admin can perform this action");

        w.resolved = true;
        w.outcome = yesOutcome ? Side.Yes : Side.No;

        emit WagerResolved(id, w.outcome);

        if (address(profilesContract) != address(0)) {
            if (w.outcome == Side.Yes) {
                for (uint256 i = 0; i < w.yesParticipants.length; i++) {
                    address user = w.yesParticipants[i];
                    profilesContract.updateStats(user, true, 0, w.yesBets[user]);
                }
                for (uint256 i = 0; i < w.noParticipants.length; i++) {
                    address user = w.noParticipants[i];
                    profilesContract.updateStats(user, false, 0, w.noBets[user]);
                }
            } else {
                for (uint256 i = 0; i < w.noParticipants.length; i++) {
                    address user = w.noParticipants[i];
                    profilesContract.updateStats(user, true, 0, w.noBets[user]);
                }
                for (uint256 i = 0; i < w.yesParticipants.length; i++) {
                    address user = w.yesParticipants[i];
                    profilesContract.updateStats(user, false, 0, w.yesBets[user]);
                }
            }
        }
    }

    function claim(uint256 id) external {
        Wager storage w = wagers[id];
        require(w.resolved, "not resolved");

        uint256 payout = 0;
        Side winning = w.outcome;

        if (winning == Side.Yes) {
            uint256 userBet = w.yesBets[msg.sender];
            require(userBet > 0, "no winning bet");
            uint256 losersPool = w.noStake;
            payout = userBet + (userBet * losersPool) / (w.yesStake == 0 ? 1 : w.yesStake);
            w.yesBets[msg.sender] = 0;
        } else {
            uint256 userBet = w.noBets[msg.sender];
            require(userBet > 0, "no winning bet");
            uint256 losersPool = w.yesStake;
            payout = userBet + (userBet * losersPool) / (w.noStake == 0 ? 1 : w.noStake);
            w.noBets[msg.sender] = 0;
        }

        payable(msg.sender).sendValue(payout);
        emit RewardClaimed(id, msg.sender, payout);
    }

    function getWagerBasic(uint256 id) external view returns (
        uint256 wagerId,
        string memory topic,
        string memory category,
        address creator,
        uint256 deadline,
        uint256 yesStake,
        uint256 noStake,
        bool resolved,
        Side outcome
    ) {
        Wager storage w = wagers[id];
        return (w.id, w.topic, w.category, w.creator, w.deadline, w.yesStake, w.noStake, w.resolved, w.outcome);
    }

    function getUserBetOnWager(uint256 id, address user) external view returns (uint256 yesAmount, uint256 noAmount, int8 reaction) {
        Wager storage w = wagers[id];
        return (w.yesBets[user], w.noBets[user], w.reaction[user]);
    }

    function totalWagers() external view returns (uint256) {
        return wagers.length;
    }

    function setProfilesContract(address _p) external onlyAdmin {
        profilesContract = IUserProfiles(_p);
    }

    function setAdmin(address _new) external onlyAdmin {
        admin = _new;
    }
}
