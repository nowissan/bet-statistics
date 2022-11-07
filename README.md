# Bet Statistics - concept and architecture

## What value to propose?
It is difficult to make accurate market forecasts such as employment statistics. There is a consensus in the market, but it is doubtful how much truth there is in the words of those involved.<br>
This is because they are stating their forecasts taking into account the impact that their opinions may have, that is "position-talk". It is necessary to probe the truthfulness of each person, and therein lies a high barrier.<br>
However, this is not the case if they have incentives to make accurate predictions and can do with anonymity.<br>
To make this possible, the power of smart contracts and Chainlink are needed.
<br>
<br>

## Assumptions
1. We provide a betting service on the unemployment rate of employment situation by U.S BLS (Bureau Labor Statistics).
2. Employment situation are released at 8:30 a.m. on the first Friday of every month.
<br>
<br>

## Scenario
1. User enters their predictions and bet
2. Smart contract add the user and the bet to a list for each prediction value
3. Automation will run at the time when the employment situation is released
4. Smart contract calls the BLS data API to obtain the latest unemployment rate value
5. When call-back triggered, smart contract calculates the reward for the winning group (The winners take all!)
6. Smart contract sends the reward to each winner address
<br>
<br>

## Components
- Frontend
- My contract
- Oracle contract
- Oracle node
    - Automation
    - Call API (get unemployment rate value)
- (external) BLS endpoint

<br>
<br>
![Bet-Statistics system diagram](/assets/images/system-diagram.png)
<br>
<br>

## Reference
- [BLS data API: curl instruction](https://www.bls.gov/developers/api_unix.htm#unix2)

<br>
<br>


note
send LINK to smart/con (not oracle con)
then requestFirstBLSData can be callable
