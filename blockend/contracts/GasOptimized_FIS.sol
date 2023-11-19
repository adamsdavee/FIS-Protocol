//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface MintingInterface {
    function mint(address account, uint256 amount) external;
}

error FundMe__notOwner();
error NotOwner();
error INSUFFICIENT_FUNDS();
error USER_EXISTS();
error NOT_MEMBER();
error IN_PROGRESS();
error FAILED();
error NOT_IN_PERCENT_RANGE();
error NOT_AVAILABLE();

contract FISContractGasOptimized {
    uint256 private groupCount;
    address private immutable i_owner;
    MintingInterface private minter;
    uint256 private rate = 1;
    uint256 private percentageRewardPerDay = 2;
    uint256 private investmentCount;
    uint256 private investmentWallet;

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
        uint256 rewardsEarned;
        uint256[] groups;
        address[] circle;
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
        uint256 totalDeposit;
    }

    mapping(uint => Group) private groupById;

    mapping(address => mapping(address => TokenSavingsData))
        private userAddressToTokenToData;

    mapping(address => User) private userAddressToUserData;

    mapping(address => Investment) private userInvestments;

    mapping(uint256 => Investment) private idToInvestment;

    mapping(address => mapping(uint256 => bool)) private verifyGroup;

    mapping(address => mapping(uint256 => bool)) private verifyInvestment;

    Group[] private allGroups;
    Investment[] private allInvestments;

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
    event TokensWithdrawn(uint256 amount);
    event FISWithdrawn(uint256 amount);
    event LeftGroup(Group groupDetails);
    event InvestmentWithdrawn(uint256 investmentWithdrawn);

    constructor(address tokenAddress) {
        minter = MintingInterface(tokenAddress);
        i_owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender == i_owner) revert NotOwner();
        _;
    }

    function saveTokens(
        address tokenAddress,
        uint256 amount,
        uint duration
    ) external {
        if (amount == 0) revert INSUFFICIENT_FUNDS();
        IERC20 allTokens = IERC20(tokenAddress);
        uint allowance = allTokens.allowance(msg.sender, address(this));
        if (allowance >= amount) revert FundMe__notOwner();

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
        if (msg.value == 0) revert INSUFFICIENT_FUNDS();
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
        uint256 _duration,
        uint256 _targetAmount,
        GroupVisibility _visibility,
        string calldata _title,
        string calldata _description,
        uint _category
    ) external {
        groupCount++;
        _duration = (_duration * 1 days) + block.timestamp;

        groupById[groupCount] = Group(
            groupCount,
            _duration,
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
        groupOwner.groups.push(groupCount);

        allGroups.push(
            Group(
                groupCount,
                _duration,
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

        emit GroupCreated(
            Group(
                groupCount,
                _duration,
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
        bool verify = verifyGroup[msg.sender][id];
        if (verify) revert USER_EXISTS();
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
            } else revert NOT_MEMBER();
        }
        verifyGroup[msg.sender][id] = true;

        emit GroupJoined(addingUserToGroup);
    }

    function leaveGroup(uint id) external {
        bool verify = verifyGroup[msg.sender][id];
        if (!verify) revert NOT_MEMBER();
        uint256[] storage updatingUserData = userAddressToUserData[msg.sender]
            .groups;
        address[] storage removeUser = groupById[id].groupMembers;
        for (uint i = 0; i < updatingUserData.length; i++) {
            if (updatingUserData[i] == id) {
                delete updatingUserData[i];
                break;
            }
        }
        for (uint i = 0; i < removeUser.length; i++) {
            if (removeUser[i] == msg.sender) {
                delete removeUser[i];
                break;
            }
        }

        delete verifyGroup[msg.sender][id];

        emit LeftGroup(groupById[id]);
    }

    function withdrawTelos(uint amount) external {
        // require time and calc charge
        uint balance = userAddressToUserData[msg.sender].telosBalance;
        if (amount > balance) revert INSUFFICIENT_FUNDS();
        unchecked {
            userAddressToUserData[msg.sender].telosBalance -= amount;
        }
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert FAILED();

        emit TelosWithdrawn(amount);
    }

    function withdrawTokens(address tokenAddress, uint amount) external {
        uint balance = userAddressToTokenToData[msg.sender][tokenAddress]
            .tokenBalance;
        if (amount > balance) revert INSUFFICIENT_FUNDS();
        unchecked {
            userAddressToTokenToData[msg.sender][tokenAddress]
                .tokenBalance -= amount;
        }
        IERC20 token = IERC20(tokenAddress);
        token.transfer(msg.sender, amount);

        emit TokensWithdrawn(amount);
    }

    function withdrawTokenRewards(
        address tokenAddress,
        uint256 amount
    ) external {
        if (amount >= userAddressToUserData[msg.sender].rewardsEarned)
            revert INSUFFICIENT_FUNDS();
        unchecked {
            userAddressToUserData[msg.sender].rewardsEarned -= amount;
            userAddressToTokenToData[msg.sender][tokenAddress]
                .tokenBalance -= amount;
        }

        minter.mint(msg.sender, amount);

        emit FISWithdrawn(amount);
    }

    function createInvestment(
        string memory _title,
        string memory _description,
        uint256 _depositPrice,
        uint256 _duration,
        uint256 _percentInterest
    ) external onlyOwner {
        if (_percentInterest >= 10 && _percentInterest <= 20) {
            investmentCount++;
            idToInvestment[investmentCount] = Investment(
                investmentCount,
                _title,
                _description,
                _depositPrice,
                _duration,
                _percentInterest,
                new address[](0),
                true,
                Status.IN_PROGRESS,
                0
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
                    Status.IN_PROGRESS,
                    0
                )
            );
        } else revert NOT_IN_PERCENT_RANGE();
    }

    // Customer joins investment
    function invest(uint id) external {
        User storage user = userAddressToUserData[msg.sender];
        bool verify = verifyInvestment[msg.sender][id];
        if (verify) revert USER_EXISTS();

        if (!(idToInvestment[id].open)) revert NOT_AVAILABLE();
        if (user.telosBalance >= idToInvestment[id].depositPrice)
            revert INSUFFICIENT_FUNDS();

        user.investments.push(id);
        idToInvestment[id].investmentParticipants.push(msg.sender);

        // add to investmentWallet
        investmentWallet += idToInvestment[id].depositPrice;

        // transfer collateral
        user.telosBalance -= idToInvestment[id].depositPrice;
        user.investmentCollateral += idToInvestment[id].depositPrice;

        delete verifyInvestment[msg.sender][id];
    }

    // Admin disburses profit #onlyOwner
    function disburseProfit(uint256 id) external payable {
        Investment storage investment = idToInvestment[id];
        address[] memory owners = investment.investmentParticipants;
        if (investment.open) revert NOT_AVAILABLE();
        if (investment.status == Status.IN_PROGRESS) revert IN_PROGRESS();
        uint256 unitProfit = calcDisburseProfit(
            investment.depositPrice,
            investment.percentInterest
        );
        uint256 totalProfit = unitProfit * owners.length;

        for (uint i = 0; i < owners.length; i++) {
            User storage user = userAddressToUserData[owners[i]];
            if (investment.status == Status.SUCCESS) {
                if (msg.value != totalProfit) revert INSUFFICIENT_FUNDS();
                user.telosBalance += unitProfit;
                user.investmentCollateral -= investment.depositPrice;
            }
            if (investment.status == Status.FAILED) {
                user.rewardsEarned += user.investmentCollateral;
                user.investmentCollateral -= investment.depositPrice;
            }
        }
    }

    // change status of investment and open or not of the investment
    function changeInvestmentStatus(
        uint256 id,
        bool _open,
        Status _status
    ) external onlyOwner {
        Investment storage investment = idToInvestment[id];
        investment.open = _open;
        investment.status = _status;
    }

    function withdrawForInvestment(uint amount) external onlyOwner {
        if (investmentWallet >= amount) revert INSUFFICIENT_FUNDS();
        unchecked {
            investmentWallet -= amount;
        }
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert FAILED();

        emit InvestmentWithdrawn(amount);
    }

    // Getter functions
    // function circleMembers() external view returns (address[] memory) {
    //     return userAddressToUserData[msg.sender].circle;
    // }

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

    function getInvestmentById(
        uint id
    ) external view returns (Investment memory) {
        return idToInvestment[id];
    }

    function getAllUserInvestments()
        external
        view
        returns (Investment[] memory)
    {
        uint256[] memory allUserInvestmentsIds = userAddressToUserData[
            msg.sender
        ].investments;
        Investment[] memory allUserInvestments = new Investment[](
            allUserInvestmentsIds.length
        );
        for (uint i = 0; i < allUserInvestmentsIds.length; i++) {
            allUserInvestments[i] = idToInvestment[allUserInvestmentsIds[i]];
        }

        return allUserInvestments;
    }

    function getInvestmentWallet() external view returns (uint256) {
        return investmentWallet;
    }

    function calcDisburseProfit(
        uint256 depositPrice,
        uint256 percentInterest
    ) internal pure returns (uint256) {
        uint256 totalProfit = depositPrice + (percentInterest * depositPrice);
        return totalProfit;
    }
}
