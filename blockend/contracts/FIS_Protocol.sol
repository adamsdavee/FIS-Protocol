//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface MintingInterface {
    function mint(address account, uint256 amount) external;
}

contract SavingsContract {
    uint256 public groupCount;

    IERC20 public piggyToken;
    MintingInterface public minter;
    uint256 private rewardsOfTokenPerDay;

    enum GroupVisibility {
        CIRCLE,
        PUBLIC
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
        address[] tokens;
        uint256 rewardsEarned; // tracking (total)
        uint256[] groups; // Store groups that we are part of
        address[] circle; // add the People to his circle so that they will want to save when he creates a group
        uint256 Goal;
        uint256 investmentCollateral;
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

    mapping(uint => Group) public groupById;

    mapping(address => mapping(address => TokenSavingsData))
        public userAddressToTokenToData;

    mapping(address => User) public userAddressToUserData;

    // Array

    Group[] public allGroups;

    constructor(address tokenAddress, uint256 rewardsOfTokens) {
        minter = MintingInterface(tokenAddress);
        rewardsOfTokenPerDay = calcRewardsPerDay(rewardsOfTokens);
    }

    function saveTokens(
        address tokenAddress,
        uint amount,
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
            .tokenBalance += (amount * 1e18);

        allTokens.transferFrom(msg.sender, address(this), amount);
    }

    function saveTelos() external payable {
        require(msg.value > 0, "No money sent");
        userAddressToUserData[msg.sender].telosBalance += msg.value;
    }

    function createGroup(
        uint256 _targetTime,
        uint256 _targetAmount,
        GroupVisibility _visibility,
        string calldata _title,
        string calldata _description,
        uint _category
    ) external {
        /** TODO */
        // People that can create group are people that has savings on the group

        groupCount++;
        // #tags for the groups starts from 1

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
    }

    function editGroup(uint id, GroupVisibility _visibility) external {
        Group storage groupToBeEdited = groupById[id];
        groupToBeEdited.visibility = _visibility;
        allGroups[id - 1].visibility = _visibility;
    }

    function addToCircle(address circleAddress) external {
        User storage addingToCircle = userAddressToUserData[msg.sender];
        addingToCircle.circle.push(circleAddress);
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
    }

    function leaveGroup(uint id) external {
        bool verify = belongToGroup(id);
        if (!verify) revert("User does not belong!");
        User storage UpdatingUserData = userAddressToUserData[msg.sender];
        Group storage addingUserToGroup = groupById[id];
        // Delete user from array
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
                rewardsOfTokenPerDay);
            userData.rewardsEarned += newRewards;
            tokenData.timeSaved = block.timestamp;
            tokenData.tokenRewards += newRewards;
        }
    }

    function addingInvestment() external {} // another contract

    function withdrawTelos(uint amount) external {
        uint balance = userAddressToUserData[msg.sender].telosBalance;
        require(balance >= amount, "Insufficient funds");
        unchecked {
            userAddressToUserData[msg.sender].telosBalance -= (amount * 1e18);
        }
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        // emit BalanceWithdrawn(msg.sender, amount);
    }

    function withdrawTokens(address tokenAddress, uint amount) external {
        uint balance = userAddressToTokenToData[msg.sender][tokenAddress]
            .tokenBalance;
        require(balance >= amount, "Insufficient funds");
        unchecked {
            userAddressToTokenToData[msg.sender][tokenAddress]
                .tokenBalance -= (amount * 1e18);
        }
        IERC20 token = IERC20(tokenAddress);
        token.transfer(msg.sender, (amount * 1e18));

        // Make it to be 0 like rewardsEarnes

        // emit BalanceWithdrawn(msg.sender, amount);
    }

    function withdrawTokenRewards(uint tokenAddress, uint amount) external {
        uint totalRewards = userAddressToUserData[msg.sender].rewardsEarned;
        require((totalRewards * 1e18) >= amount, "Insufficient funds");
        unchecked {
            userAddressToUserData[msg.sender].rewardsEarned -= (amount * 1e18);
        }

        minter.mint(msg.sender, amount);

        // emit BalanceWithdrawn(msg.sender, amount);
    }

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
            uint256 newRewards = (tokenData.tokenBalance *
                (block.timestamp - tokenData.timeSaved) *
                rewardsOfTokenPerDay);
            userData.rewardsEarned += newRewards;
            tokenData.timeSaved = block.timestamp;
            tokenData.tokenRewards += newRewards;
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

    function generalRewardPerAnyToken(uint256 dailyRate) external {
        uint256 _tokenRewards = calcRewardsPerDay(dailyRate);
        rewardsOfTokenPerDay = _tokenRewards;
    }

    function calcRewardsPerDay(uint dailyRate) internal pure returns (uint256) {
        return (dailyRate / (24 * 60 * 60)) * 1e18;
    }

    // function getTokenStatus() public view returns(uint256, uint256) {
    //     uint256 allowance = ecdisToken.allowance(msg.sender, address(this));
    //     uint256 balance = ecdisToken.balanceOf(msg.sender);
    //     return (allowance, balance);
    // }
}
