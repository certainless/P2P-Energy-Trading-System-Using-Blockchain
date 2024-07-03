// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EnergyTrading {

    struct User {
        address userAddress;
        bytes32 role;
        uint32 energyBalance;
    }

    struct Bid {
        address bidder;
        uint32 bidAmount;
        uint32 energyRequested;
    }

    struct EnergyData {
        uint32 timestamp;
        uint32 energyAmount;
    }

    mapping(address => User) public users;
    mapping(address => Bid) public bids;
    mapping(address => EnergyData[]) public energyReadings;

    address public prosumer;
    uint16 immutable public conversionRate; // Tokens per unit of energy

    address[] public consumers; // List of all consumer addresses
    address[] public bidders; // List of all current bidders
    mapping(address => bool) public isActiveBidder; // Track active bidders

    event NewBid(address indexed bidder, uint bidAmount, uint energyRequested);
    event EnergySold(address indexed buyer, uint amount, uint energySold);
    event EnergyDataSubmitted(address indexed user, uint timestamp, uint energyAmount);

    modifier onlyProsumer() {
        require(msg.sender == prosumer, "Only prosumer can perform this action");
        _;
    }

    modifier onlyConsumer() {
        require(msg.sender != prosumer, "Only consumer can bid");
        _;
    }

    constructor(uint16 _conversionRate) {
        conversionRate = _conversionRate;
    }

    function registerProsumer(address _prosumer, uint32 _energyAmount) public {
        require(users[_prosumer].userAddress == address(0), "User already registered");
        users[_prosumer] = User(_prosumer, "prosumer", _energyAmount);
        prosumer = _prosumer;
    }

    function registerConsumer(address _consumer) public {
        require(users[_consumer].userAddress == address(0), "User already registered");
        users[_consumer] = User(_consumer, "consumer", 0);
        consumers.push(_consumer);
    }

    function submitEnergyData(uint32 _energyAmount) public {
        EnergyData memory newData = EnergyData(uint32(block.timestamp), _energyAmount);
        energyReadings[msg.sender].push(newData);
        users[msg.sender].energyBalance += _energyAmount;
        emit EnergyDataSubmitted(msg.sender, block.timestamp, _energyAmount);
    }

    function placeBid(uint32 _bidAmount, uint32 _energyRequested) public onlyConsumer {
        require(_bidAmount > 0 && _energyRequested > 0, "Invalid bid amount or energy requested");
        if (!isActiveBidder[msg.sender]) {
            bidders.push(msg.sender); // Add new bidder to the list
            isActiveBidder[msg.sender] = true;
        }
        bids[msg.sender] = Bid(msg.sender, _bidAmount, _energyRequested);
        emit NewBid(msg.sender, _bidAmount, _energyRequested);
    }

    function sellEnergy() public onlyProsumer {
        require(bidders.length > 0, "No bids placed");

        address highestBidder;
        uint32 highestBid;
        uint32 energyRequested;

        (highestBidder, highestBid, energyRequested) = getHighestBid();

        require(highestBid > 0, "No valid bids");
        require(users[prosumer].energyBalance >= energyRequested, "Not enough energy available");

        users[prosumer].energyBalance -= energyRequested;
        users[highestBidder].energyBalance += energyRequested;

        // Transfer tokens (ether) from bidder to prosumer
        payable(prosumer).transfer(highestBid);

        emit EnergySold(highestBidder, highestBid, energyRequested);
        
        resetBids();
    }

    function getHighestBid() internal view returns (address, uint32, uint32) {
        address highestBidder;
        uint32 highestBid;
        uint32 energyRequested;

        for (uint i = 0; i < bidders.length; i++) {
            address addr = bidders[i];
            if (bids[addr].bidAmount > highestBid) {
                highestBid = bids[addr].bidAmount;
                highestBidder = addr;
                energyRequested = bids[addr].energyRequested;
            }
        }

        return (highestBidder, highestBid, energyRequested);
    }

    function resetBids() internal {
        for (uint32 i; i < bidders.length; i++) {
            address bidder = bidders[i];
            delete bids[bidder];
            isActiveBidder[bidder] = false; // Mark bidder as inactive
        }
        delete bidders; // Clear the list of bidders
    }

    function convertEnergyToTokens(uint _energyAmount) public view returns (uint) {
        return _energyAmount * conversionRate;
    }
}
