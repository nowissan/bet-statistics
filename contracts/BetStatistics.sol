// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

struct forecastor {
    address payable forecastorAddress;
    // uint256 bet;// [TODO]
}

contract BetStatistics is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    // state variables
    bytes32 private jobId;
    uint256 private fee;

    uint256 private s_BET_AMOUNT;
    uint8 private s_lastRate;
    // uint256 private immutable i_MINIMUM_BET = 10000000000000000; // [TODO]
    address private immutable i_owner;
    // address private s_UPKEEP_NODE;
    mapping(uint8 => forecastor[]) public s_forecastersByValue; // 3.6 => [0x9a...b6, ...]

    event RequestFirstValue(bytes32 indexed requestId, uint256 volume);

    // modifiers
    // modifier onlyOwner() {
    //     require(msg.sender == i_owner, "Caller is not an owner");
    //     _;
    // }

    constructor() ConfirmedOwner(msg.sender) {
        // initialize for chainlink
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xCC79157eb46F5624204f47AB42b3906cAA40eaB7);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)

        // initialize for app
        s_BET_AMOUNT = 10000000000000000; // 0.01 eth = 10000000000000000 wei
        i_owner = msg.sender;
    }

    // 1, 2
    function bet(uint8 _forecastValue) public payable {
        // require(// [TODO]
        //     msg.value >= i_MINIMUM_BET,
        //     "You need to spend greater than or equal to 0.01 ETH for each bet"
        // );
        require(msg.value == s_BET_AMOUNT, "should be 0.01 ETH for each bet");
        require(_forecastValue >= 0, "forecast should be more than 0");
        require(_forecastValue <= 250, "forecast should be less than 250(25%)");

        // set new forecastor and its bet to the list
        forecastor memory _forecastor;
        _forecastor.forecastorAddress = payable(msg.sender);
        // _forecastor.bet = msg.value; // [TODO]
        s_forecastersByValue[_forecastValue].push(_forecastor);
    }

    // 3, 4
    function requestFirstBLSData() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        // Set the URL to perform the GET request on
        // docs: https://www.bls.gov/developers/api_unix.htm#unix2
        // [example]
        //  curl -i -X POST -H 'Content-Type: application/json' -d '{"seriesid":["LNS14000000"], "startyear":"2022", "endyear":"2022"}' https://api.bls.gov/publicAPI/v1/timeseries/data/
        //  curl -i -X GET https://api.bls.gov/publicAPI/v2/timeseries/data/LNS14000000
        req.add(
            "get",
            "https://api.bls.gov/publicAPI/v2/timeseries/data/LNS14000000"
        );
        req.add("path", "Results,series,0,data,0,value");
        int256 timesAmount = 10;
        req.addInt("times", timesAmount);

        return sendChainlinkRequest(req, fee);
    }

    // 5, 6
    function fulfill(bytes32 _requestId, uint256 _rate)
        public
        payable
        recordChainlinkFulfillment(_requestId)
    {
        emit RequestFirstValue(_requestId, _rate);

        uint8 unemploymentRate = uint8(_rate);
        s_lastRate = unemploymentRate;
        // uint8 unemploymentRate = removePosition(_rate);
        uint256 rewardPerPerson = calculateReward(unemploymentRate);
        // sendReward(unemploymentRate, rewardPerPerson);

        for (
            uint i = 0;
            i < s_forecastersByValue[unemploymentRate].length;
            i++
        ) {
            // send reward to each winner
            uint256 reward = rewardPerPerson + s_BET_AMOUNT; // s_forecastersByValue[unemploymentRate][i].bet [TODO]
            (bool success, ) = s_forecastersByValue[unemploymentRate][i]
                .forecastorAddress
                .call{value: reward}("");
            require(success, "transfer failed");
        }
        // clearForecasters(); // expensive? with this feature
    }

    function calculateReward(uint8 actualRate) private view returns (uint256) {
        uint256 reward = 0;
        uint256 rewardPerPerson = 0;
        require(s_forecastersByValue[actualRate].length > 0, "no winner");
        // sum up the total of bet for losers
        for (uint8 i = 0; i < 250; i++) {
            if (i == actualRate) {
                break;
            }
            for (uint j = 0; j < s_forecastersByValue[i].length; j++) {
                // reward += s_forecastersByValue[i][j].bet;// [TODO]
                reward += s_BET_AMOUNT;
            }
        }

        // take service charge // [TODO]

        if (reward == 0) {
            return reward;
        }

        rewardPerPerson = reward / s_forecastersByValue[actualRate].length;
        return rewardPerPerson;
    }

    /*
    function sendReward(uint8 actualRate, uint256 reward) public payable {
        for (uint i = 0; i < s_forecastersByValue[actualRate].length; i++) {
            // send reward to each winner
            reward += s_BET_AMOUNT;
            payable(s_forecastersByValue[actualRate][i].forecastorAddress)
                .transfer(reward);
        }

        // make the s_forecasterByValue empty
        for (uint8 i = 0; i < 250; i++) {
            for (uint j = 0; j < s_forecastersByValue[i].length; j++) {
                s_forecastersByValue[i].pop();
            }
        }
    }*/

    function clearForecasters() public onlyOwner {
        // make the s_forecasterByValue empty
        for (uint8 i = 0; i < 250; i++) {
            // s_forecastersByValue[i] = new forecastor[](0);
            for (uint j = 0; j < s_forecastersByValue[i].length; j++) {
                s_forecastersByValue[i].pop();
            }
        }
    }

    // function setUPKEEPNODE(address _upkeep_node) public onlyOnwer {
    //     s_UPKEEP_NODE = _upkeep_node;
    // }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function withdraw() public onlyOwner {
        (bool success, ) = i_owner.call{value: address(this).balance}("");
        require(success);
    }

    function getLastUnemploymentRate() public view returns (uint8) {
        return s_lastRate;
    }

    function setEntranceFee(uint256 _bet_amount) public onlyOwner {
        s_BET_AMOUNT = _bet_amount;
    }

    function getEntranceFee() public view returns (uint256) {
        return s_BET_AMOUNT;
    }

    //[TODO] these variables should be defined as global. temporarily this should be set through function for gas price reason
    function getNumberOfLastWinners() public view returns (uint256) {
        return s_forecastersByValue[s_lastRate].length;
    }

    function getLastRewardPerPerson() public view returns (uint256) {
        // [TODO] after the balance is transfered, this calculation is invalid
        uint256 rewardPerPerson = calculateReward(s_lastRate);
        return rewardPerPerson;
    }

    // function updateBetAmount(uint256 _bet_amount) public onlyOnwer {
    //     require(_bet_amount > 0, "Bet amount should be more than 0");
    //     s_BET_AMOUNT = _bet_amount;
    // }
}
