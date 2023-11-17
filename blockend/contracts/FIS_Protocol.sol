//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface MintingInterface {
    function mint(address account, uint256 amount) external;
}

contract SavingsContract {
    uint256 public groupCount;
    address private immutable i_owner;

    IERC20 public piggyToken;
    MintingInterface public minter;
    uint256 private rate = 1;
    uint256 private percentageRewardPerDay = 2;
    uint256 private investmentCount;

    enum GroupVisibility {
        CIRCLE,
        PUBLIC
    }

    enum Status {
        IN_PROGRESS,
        SUCCESS,
        FAILED
    }

    struct TokenSavingsData {
        address tokenAddress;
        uint256 tokenBalance;
        uint256 saveDuration;
        uint256 timeSaved;
        uint256 tokenRewards;
    }

    struct User {
        address walletAddress;
        uint256 telosBalance;
        uint256 telosDuration;
        uint256 timeSaved;
        address[] tokens;
        uint256 rewardsEarned; // tracking (total)
        uint256[] groups; // Store groups that we are part of
        address[] circle; // add the People to his circle so that they will want to save when he creates a group
        uint256 Goal;
        uint256 investmentCollateral;
        uint256[] investments;
    }

    struct Group {
        uint256 id;
        uint256 duration;
        uint256 targetAmount;
        GroupVisibility visibility;
        string title;
        string description;
        uint category;
        address[] groupMembers;
        address creator;
        uint timeCreated;
    }

    struct Investment {
        uint256 id;
        string title;
        string description;
        uint256 depositPrice;
        uint256 duration;
        uint256 percentInterest;
        address[] investmentParticipants;
        bool open;
        Status status;
    }

    mapping(uint => Group) public groupById;

    mapping(address => mapping(address => TokenSavingsData))
        public userAddressToTokenToData;

    mapping(address => User) public userAddressToUserData;

    mapping(address => Investment) public userInvestments;

    mapping(uint256 => Investment) public hashInvestment;

    mapping(address => uint256) public Owner;

    // Array

    Group[] public allGroups;
    Investment[] public allInvestments;

    event SaveToken(
        address indexed tokenAddress,
        uint256 saveDuration,
        uint256 timeSaved,
        uint256 tokenBalance
    );
    event SaveTelos(
        uint256 telosDuration,
        uint256 timeSaved,
        uint256 tokenBalance
    );
    event Goal(uint256 setGoal);
    event GroupCreated(Group groupDetails);
    event GroupVisibilityStatus(
        uint256 indexed id,
        GroupVisibility _visibility
    );
    event CircleAdded(bool circleMemberAdded);
    event GroupJoined(Group groupDetails);
    event TelosWithdrawn(uint256 amount);
    event LeftGroup(Group groupDetails);

    constructor(address tokenAddress) {
        minter = MintingInterface(tokenAddress);
        i_owner = msg.sender;
    }

    // set admin to change investment goals
    // Delete investments

    function saveTokens(
        address tokenAddress,
        uint256 amount,
        uint duration
    ) external {
        require(amount > 0, "Include amount!");
        IERC20 allTokens = IERC20(tokenAddress);
        uint allowance = allTokens.allowance(msg.sender, address(this));
        require(allowance >= amount, "Token transfer not approved");

        userAddressToTokenToData[msg.sender][tokenAddress].saveDuration =
            block.timestamp +
            (duration * 1 days);
        userAddressToTokenToData[msg.sender][tokenAddress].timeSaved = 0;
        userAddressToTokenToData[msg.sender][tokenAddress]
            .tokenBalance += amount;

        allTokens.transferFrom(msg.sender, address(this), amount);

        emit SaveToken(
            tokenAddress,
            userAddressToTokenToData[msg.sender][tokenAddress].saveDuration,
            duration,
            userAddressToTokenToData[msg.sender][tokenAddress].tokenBalance
        );
    }

    function saveTelos(uint256 duration) external payable {
        require(msg.value > 0, "No money sent");
        userAddressToUserData[msg.sender].telosBalance += msg.value;
        userAddressToUserData[msg.sender].telosDuration = duration;
        userAddressToUserData[msg.sender].timeSaved = block.timestamp;

        emit SaveTelos(
            duration,
            block.timestamp,
            userAddressToUserData[msg.sender].telosBalance
        );
    }

    function setGoal(uint256 goalAmount) external {
        userAddressToUserData[msg.sender].Goal = goalAmount;

        emit Goal(goalAmount);
    }

    function createGroup(
        uint256 _targetTime,
        uint256 _targetAmount,
        GroupVisibility _visibility,
        string calldata _title,
        string calldata _description,
        uint _category
    ) external {
        groupCount++;

        groupById[groupCount] = Group(
            groupCount,
            _targetTime,
            _targetAmount,
            _visibility,
            _title,
            _description,
            _category,
            new address[](0),
            msg.sender,
            block.timestamp
        );

        User storage groupOwner = userAddressToUserData[msg.sender];
        // groupOwner.groups.push(Group(groupCount, _targetTime, _targetAmount, _visibility));
        groupOwner.groups.push(groupCount);

        emit GroupCreated(
            Group(
                groupCount,
                _targetTime,
                _targetAmount,
                _visibility,
                _title,
                _description,
                _category,
                new address[](0),
                msg.sender,
                block.timestamp
            )
        );
    }

    function editGroup(uint256 id, GroupVisibility _visibility) external {
        Group storage groupToBeEdited = groupById[id];
        groupToBeEdited.visibility = _visibility;
        allGroups[id - 1].visibility = _visibility;

        emit GroupVisibilityStatus(id, _visibility);
    }

    function addToCircle(address circleAddress) external {
        User storage addingToCircle = userAddressToUserData[msg.sender];
        addingToCircle.circle.push(circleAddress);
        bool added = true;

        emit CircleAdded(added);
    }

    function joinGroup(uint id) external {
        bool verify = belongToGroup(id);
        if (verify) revert("address exists!");
        User storage UpdatingUserData = userAddressToUserData[msg.sender];
        Group storage addingUserToGroup = groupById[id];

        if (addingUserToGroup.visibility == GroupVisibility.PUBLIC) {
            UpdatingUserData.groups.push(id);
            addingUserToGroup.groupMembers.push(msg.sender);
        } else {
            address creatorAddress = addingUserToGroup.creator;
            address[] memory membersOfCircle = userAddressToUserData[
                creatorAddress
            ].circle;
            bool foundCircleMember = false;
            for (uint i = 0; i < membersOfCircle.length; i++) {
                if (msg.sender == membersOfCircle[i]) {
                    foundCircleMember = true;
                    break;
                }
            }
            if (foundCircleMember) {
                UpdatingUserData.groups.push(id);
                addingUserToGroup.groupMembers.push(msg.sender);
            } else revert("Not a circle member");
        }

        emit GroupJoined(addingUserToGroup);
    }

    function leaveGroup(uint id) external {
        bool verify = belongToGroup(id);
        if (!verify) revert("User does not belong!");
        User storage UpdatingUserData = userAddressToUserData[msg.sender];
        Group storage addingUserToGroup = groupById[id];
        // Delete user from array

        emit LeftGroup(addingUserToGroup);
    }

    function claimRewards() external {
        User storage userData = userAddressToUserData[msg.sender];

        address[] memory addressOfUserTokens = userData.tokens;
        for (uint i = 0; i < addressOfUserTokens.length; i++) {
            TokenSavingsData storage tokenData = userAddressToTokenToData[
                msg.sender
            ][addressOfUserTokens[i]];
            uint256 newRewards = (tokenData.tokenBalance *
                (block.timestamp - tokenData.timeSaved) *
                percentageRewardPerDay);
            userData.rewardsEarned += newRewards;
            tokenData.timeSaved = block.timestamp;
            tokenData.tokenRewards += newRewards;
        }
    }

    function withdrawTelos(uint amount) external {
        // require time and calc charge
        uint balance = userAddressToUserData[msg.sender].telosBalance;
        require(balance >= amount, "Insufficient funds");
        unchecked {
            userAddressToUserData[msg.sender].telosBalance -= amount;
        }
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit TelosWithdrawn(amount);
    }

    function withdrawTokens(address tokenAddress, uint amount) external {
        uint balance = userAddressToTokenToData[msg.sender][tokenAddress]
            .tokenBalance;
        require(balance >= amount, "Insufficient funds");
        unchecked {
            userAddressToTokenToData[msg.sender][tokenAddress]
                .tokenBalance -= amount;
        }
        IERC20 token = IERC20(tokenAddress);
        token.transfer(msg.sender, amount);

        // Make it to be 0 like rewardsEarnes

        // emit BalanceWithdrawn(msg.sender, amount);
    }

    function withdrawTokenRewards(uint tokenAddress, uint amount) external {
        uint totalRewards = userAddressToUserData[msg.sender].rewardsEarned;
        require((totalRewards * 1e18) >= amount, "Insufficient funds");
        unchecked {
            userAddressToUserData[msg.sender].rewardsEarned -= amount;
        }

        minter.mint(msg.sender, amount);

        // emit BalanceWithdrawn(msg.sender, amount);
    }

    function createInvestment(
        string memory _title,
        string memory _description,
        uint256 _depositPrice,
        uint256 _duration,
        uint256 _percentInterest
    ) external {
        // Make it only owner
        require(
            _percentInterest >= 10 && _percentInterest <= 20,
            "Not in percent range"
        );
        investmentCount++;
        hashInvestment[investmentCount] = Investment(
            investmentCount,
            _title,
            _description,
            _depositPrice,
            _duration,
            _percentInterest,
            new address[](0),
            true,
            Status.IN_PROGRESS
        );
        allInvestments.push(
            Investment(
                investmentCount,
                _title,
                _description,
                _depositPrice,
                _duration,
                _percentInterest,
                new address[](0),
                true,
                Status.IN_PROGRESS
            )
        );
    } // another contract

    function userJoinsInvestment(uint id) external {
        // User storage addUserToInvestment = userAddressToTokenToData[msg.sender][tokenAddress];
        User storage userJoiningInvestment = userAddressToUserData[msg.sender];
        uint256[] memory userInvestmentsDetails = userJoiningInvestment
            .investments;
        for (uint i = 0; i < userInvestmentsDetails.length; i++) {
            bool verify = false;
            if (userInvestmentsDetails[i] == id) verify = true;
            if (verify) revert("User exists");
        }
        require(
            userJoiningInvestment.telosBalance ==
                hashInvestment[id].depositPrice,
            "Insufficient funds"
        );

        userJoiningInvestment.investments.push(id);
        hashInvestment[id].investmentParticipants.push(msg.sender);

        // add to investment participants
        // Owner[i_owner] +=

        // transfer collateral
    }

    // Customer joins investment

    // Admin disburses profit

    // Methods
    function belongToGroup(uint id) internal view returns (bool) {
        uint[] memory userGroups = userAddressToUserData[msg.sender].groups;
        bool verify = false;
        for (uint i = 0; i < userGroups.length; i++) {
            if (id == userGroups[i]) {
                verify = true;
                break;
            }
        }
        return verify;
    }

    // Getter function for token balance and telos balance
    function circleMembers() external view returns (address[] memory) {
        return userAddressToUserData[msg.sender].circle;
    }

    function getGroupById(uint id) external view returns (Group memory) {
        return groupById[id];
    }

    function getAllGroups() external view returns (Group[] memory) {
        return allGroups;
    }

    function getUser() external view returns (User memory) {
        return userAddressToUserData[msg.sender];
    }

    function getUserTokensData() external returns (TokenSavingsData[] memory) {
        User storage userData = userAddressToUserData[msg.sender];
        address[] memory userTokensAddresses = userData.tokens;

        TokenSavingsData[] memory listOfUserTokensData = new TokenSavingsData[](
            userTokensAddresses.length
        );

        for (uint i = 0; i < userTokensAddresses.length; i++) {
            TokenSavingsData storage tokenData = userAddressToTokenToData[
                msg.sender
            ][userTokensAddresses[i]];

            // update rewards
            uint256 secondsPassed = (block.timestamp - tokenData.timeSaved);
            if (secondsPassed >= 86400) {
                uint256 newRewards = (tokenData.tokenBalance *
                    secondsPassed *
                    (calcRewardsPerSeconds(percentageRewardPerDay) * rate)) /
                    1e18;
                userData.rewardsEarned += newRewards;
                tokenData.timeSaved = block.timestamp;
                tokenData.tokenRewards += newRewards;
            }

            listOfUserTokensData[i] = tokenData;
        }
        return listOfUserTokensData;
    }

    function getBalanceOfContract(
        address tokenAddress
    ) public view returns (uint256) {
        IERC20 balanceOfTokenInContract = IERC20(tokenAddress);
        return balanceOfTokenInContract.balanceOf(address(this));
    }

    function changePerentageRewardPerDay(uint256 _tokenRewards) external {
        percentageRewardPerDay = _tokenRewards;
    }

    function calcRewardsPerSeconds(
        uint dailyRate
    ) internal pure returns (uint256) {
        return (dailyRate * 1e16) / (24 * 60 * 60);
    }

    function getAllInvestments() external view returns (Investment[] memory) {
        return allInvestments;
    }

    // function getTokenStatus() public view returns(uint256, uint256) {
    //     uint256 allowance = ecdisToken.allowance(msg.sender, address(this));
    //     uint256 balance = ecdisToken.balanceOf(msg.sender);
    //     return (allowance, balance);
    // }
}
