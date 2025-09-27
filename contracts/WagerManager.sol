// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/utils/Address.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

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
    string constant token_expected = "Token betting expected";
    string constant eth_disabled = "Etherium disabled";
    string constant deadline_elapsed = "Deadline has elapsed";

    struct Wager {
        uint256 id;
        string topic;
        string category; // for feed filters
        address creator;
        uint256 deadline; // timestamp
        uint256 yesStake; // total yes stakes in token units
        uint256 noStake;  // total no stakes in token units
        bool resolved;
        Side outcome; // side.Yes or Side.No on resolution
        address[] yesParticipants;
        address[] noParticipants;
        mapping(address => uint256) yesBets;
        mapping(address => uint256) noBets;
        mapping(address => int8) reaction; // -1 dislike, 0 neutral, 1 like
    }

    Wager[] public wagers;
    // mapping(uint256 => Wager) private wagersMap;

    // betting currency: if address is 0 means native ETH, otherwise ERC20 token
    address public bettingToken;
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

    constructor(address _nfxToken, address _profilesContract) {
        admin = msg.sender;
        bettingToken = _nfxToken; // NFX token
        profilesContract = IUserProfiles(_profilesContract);
    }


    // create a wager
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

        // defaults handled
        emit WagerCreated(id, topic, category, msg.sender, deadline);
        return id;
    }

    // stake/join, for eth: send value, for ERC20: approve then call stake
    function stakeETH(uint256 id, bool isYes) external payable {
        _stake(id, msg.sender, isYes ? Side.Yes : Side.No, msg.value);
    }

    function stake(uint256 id, bool isYes, uint256 amount) external {
        require(amount > 0, bad_financial_position);
        
        IERC20(bettingToken).transferFrom(msg.sender, address(this), amount);
        _stake(id, msg.sender, isYes ? Side.Yes : Side.No, amount);
    }

    // internal staking logic
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

    // increase an existing users stake, 1up the stake
    function increaseStakeETH(uint256 id, bool isYes) external payable {
        _increaseStake(id, msg.sender, isYes ? Side.Yes : Side.No, msg.value);
    }

    function increaseStakeWithToken(uint256 id, bool isYes, uint256 amount) external {
        IERC20(bettingToken).transferFrom(msg.sender, address(this), amount);
        _increaseStake(id, msg.sender, isYes ? Side.Yes : Side.No, amount);
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

    // react: -1 dislike, 0 neutral, 1 like
    function react(uint256 id, int8 reactionValue) external {
        Wager storage w = wagers[id];
        w.reaction[msg.sender] = reactionValue;
        emit ReactionUpdated(id, msg.sender, reactionValue);
    }

    // resolve the wager
    function resolveWager(uint256 id, bool yesOutcome) external {
        Wager storage w = wagers[id];
        require(msg.sender == w.creator || msg.sender == admin, "Only the admin can perform this action");

        w.resolved = true;
        w.outcome = yesOutcome ? Side.Yes : Side.No;

        emit WagerResolved(id, w.outcome);

        // compute and update profiles and leave payout bookkeeping to claimRewards
        // later to emit events per participant so indexer and UserProfiles can update accuracy off-chain
        // call profilesContract.updateStats for each participant (gas heavy but functional)
        if (address(profilesContract) != address(0)) {
            if (w.outcome == Side.Yes) {
                // yes winners
                for (uint256 i = 0; i < w.yesParticipants.length; i++) {
                    address user = w.yesParticipants[i];
                    uint256 betAmt = w.yesBets[user];
                    // netChange computed later when claimed; we pass placeholder 0 for now
                    profilesContract.updateStats(user, true, int256(0), betAmt);
                }
                for (uint256 i = 0; i < w.noParticipants.length; i++) {
                    address user = w.noParticipants[i];
                    uint256 betAmt = w.noBets[user];
                    profilesContract.updateStats(user, false, int256(0), betAmt);
                }
            } else {
                for (uint256 i = 0; i < w.noParticipants.length; i++) {
                    address user = w.noParticipants[i];
                    uint256 betAmt = w.noBets[user];
                    profilesContract.updateStats(user, true, int256(0), betAmt);
                }
                for (uint256 i = 0; i < w.yesParticipants.length; i++) {
                    address user = w.yesParticipants[i];
                    uint256 betAmt = w.yesBets[user];
                    profilesContract.updateStats(user, false, int256(0), betAmt);
                }
            }
        }
    }

    // claim rewards after resolution
    function claim(uint256 id) external {
        Wager storage w = wagers[id];
        require(w.resolved, "not resolved");
        uint256 payout = 0;
        Side winning = w.outcome;
        if (winning == Side.Yes) {
            uint256 userBet = w.yesBets[msg.sender];
            require(userBet > 0, "no winning bet");
            // winners split the losing pool proportionally
            uint256 losersPool = w.noStake;
            // payout = userBet + userBet * losersPool / yesStake
            payout = userBet + (userBet * losersPool) / (w.yesStake == 0 ? 1 : w.yesStake);
            // zero out to prevent double claim
            w.yesBets[msg.sender] = 0;
        } else {
            uint256 userBet = w.noBets[msg.sender];
            require(userBet > 0, "no winning bet");
            uint256 losersPool = w.yesStake;
            payout = userBet + (userBet * losersPool) / (w.noStake == 0 ? 1 : w.noStake);
            w.noBets[msg.sender] = 0;
        }

        // transfer payout
        if (bettingToken == address(0)) {
            payable(msg.sender).sendValue(payout);
        } else {
            IERC20(bettingToken).transfer(msg.sender, payout);
        }

        emit RewardClaimed(id, msg.sender, payout);

    }

    // views for the frontend indexing
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

    function getWagerCounts(uint256 id) external view returns (uint256 yesCount, uint256 noCount) {
        Wager storage w = wagers[id];
        yesCount = w.yesParticipants.length;
        noCount = w.noParticipants.length;
    }

    function getUserBetOnWager(uint256 id, address user) external view returns (uint256 yesAmount, uint256 noAmount, int8 reaction) {
        Wager storage w = wagers[id];
        return (w.yesBets[user], w.noBets[user], w.reaction[user]);
    }

    function totalWagers() external view returns (uint256) {
        return wagers.length;
    }

    // admin stuff
    function setProfilesContract(address _p) external onlyAdmin {
        profilesContract = IUserProfiles(_p);
    }

    function setAdmin(address _new) external onlyAdmin {
        admin = _new;
    }
}
