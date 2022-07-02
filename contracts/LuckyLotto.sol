// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/Counters.sol";        // openzepplin library for generating IDs
import "@openzeppelin/contracts/utils/math/SafeMath.sol";   // openzepplin library to prevent overflow

contract LuckyLoto {

    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter lottoID;           // id for each lottery event
    Counters.Counter gamblerID;         // id of each gambler
    Counters.Counter OrganizerID;       // id of each organizer

    enum LottoType {STANDARD, VARIABLE}                             //
    enum LottoStatus {WAITING, ACTIVE, MAXED_OUT, TIMEUP, CONCLUDED, SUPSPENDED }    //

    // Gambler object
    struct Gambler {
        address gamblerAddress;
        uint256 gamblerID;
        uint256 totalWins;
        uint256 balance;
        uint256[] lottoAsParticipants;
        uint256[] lottoAsOrganizer;
    }

    // Lotto object
    struct LottoEvent {
        // uint256 lottoID;
        uint256 activeTime;
        uint256 drawTime;
        uint256 balance;
        uint256 lottoPot;
        uint256 ticketPrice;
        uint256 maxParticipants;
        uint256 minParticipants;
        address[] participants;
        address[] winners;
        address organizer;
        LottoType lottoType;
        LottoStatus lottoStatus;
    }

    LottoEvent lotto;                               // lotto object
    Gambler gambler;                                // gambler object
    mapping(uint256 => LottoEvent) lottoMapping;    // mapping Lotto ID to lottoEvent object
    mapping(address => Gambler) gamblerMapping;     // mapping gambler ID to gambler object

    uint256[] lottoIDArray;             // array of lotto IDs
    address[] gamblerAddressArray;      // array of lotto IDs
    address[] participantsArray;        // array of address of gamblers who are participating in Lotto
    address[] organizersArray;          // array of address of gamblers who are organizing Lotto

    event GamblerAdded(address, uint256);           // event that will be emited if new gambler is added
    event LottoCreated(uint256, uint256);           // event that will be emited if new lotto is created
    event LottoTicketSold(uint256, address);        // event that will be emited if new lotto is created
    event LottoWinnersAnnounced(uint256, address winner1, address winner2, address winner3);        // event that will be emited when winners are announced
    event WithdrawSuccessfull(address, uint256);

    // MODIFIER to make sure gambler exists
    modifier isGambler {
        require(gamblerMapping[msg.sender].gamblerID != 0, "Not a valid Gambler");
        // require(gamblerMapping[msg.sender].gamblerAddress == address(0), "Already a Gambler");
        _;
    }

    // MODIFIER to make Lotto Exists
    modifier isLotto(uint256 _lottoID) {
        require(lottoMapping[_lottoID].organizer != address(0), "No such lotto exists");
        _;
    }

    // MODIFIER to make Lotto is in ACTIVE state
    modifier isLottoActive(uint256 _lottoID) {
        checkLottoStatus(_lottoID);
        require(lottoMapping[_lottoID].lottoStatus == LottoStatus.ACTIVE, string.concat("Not Active"));
        _;
    }

    // MODIFIER to check if lotto is soldout
    modifier hasLottoMaxedOut(uint256 _lottoID) {
        checkLottoStatus(_lottoID);
        // require(lottoMapping[_lottoID].maxParticipants > lottoMapping[_lottoID].participants.length, "Lotto has maxed out");
        require(lottoMapping[_lottoID].lottoStatus == LottoStatus.MAXED_OUT, "Lotto has maxed out");
        _;
    }

    // MODIFIER to check if lotto can be drawn
    modifier hasLottoTimesUp(uint256 _lottoID) {
        checkLottoStatus(_lottoID);
        require(lottoMapping[_lottoID].lottoStatus == LottoStatus.TIMEUP, "Lotto can not be drawn at this momemnt");
        _;
    }

    // MODIFIER to check if lotto has not been concluded
    modifier isLottoNotConcluded(uint256 _lottoID) {
        require(lottoMapping[_lottoID].lottoStatus != LottoStatus.CONCLUDED, "Lotto Has been concluded.");
        _;
    }

    // UTILITY FUNCTION to check and update LOTTO status
    function checkLottoStatus(uint256 _lottoID) internal {
        LottoStatus status;
        if (lottoMapping[_lottoID].activeTime > block.timestamp) {
            status = LottoStatus.WAITING;
        } else {
            status = LottoStatus.ACTIVE;
        }

        if (status == LottoStatus.ACTIVE) {
            if (lottoMapping[_lottoID].maxParticipants <= lottoMapping[_lottoID].participants.length) {
                status = LottoStatus.MAXED_OUT;
            }

            if (lottoMapping[_lottoID].drawTime <= block.timestamp) {
                if (lottoMapping[_lottoID].minParticipants > lottoMapping[_lottoID].participants.length) {
                    status = LottoStatus.SUPSPENDED;
                } else {
                    status = LottoStatus.TIMEUP;
                }
            }
        }

        if (lottoMapping[_lottoID].lottoStatus != status) {
            lottoMapping[_lottoID].lottoStatus = status;
        }
    }

    // UTILITY FUNCTION to calculate prize money
    function prizeCalculator(uint256 _lottoID, uint256 _position) view internal returns (uint256) {
        uint256 _percent;
        if (_position == 1) {
            _percent = 60;
        } else if (_position == 2) {
            _percent = 30;
        } if (_position == 3) {
            _percent = 10;
        }
        return lottoMapping[_lottoID].lottoPot * _percent / 100;
    }

    // UTILITY FUNCTION togenerate random numberdepending on input numbers
    function generateRandomNumber(uint256 randomNumber, uint256 position) view internal returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, block.difficulty, randomNumber, position)));
    }

    // UTILITY FUNCTION to check if gambler exists
    function gamblerExists() internal view returns (bool) {
        if (gamblerMapping[msg.sender].gamblerID == 0){
            return false;
        } else {
            return true;
        }
        // require(gamblerMapping[msg.sender].gamblerAddress == address(0), "Already a Gambler");
    }

    // UTILITY FUNCTION to add a new Gambler
    function addGambler() internal {
        if (gamblerExists()) {
            gamblerID.increment();      // creating id gambler
            Gambler storage _gambler = gamblerMapping[msg.sender];     // created new gambled object
            _gambler.gamblerAddress = msg.sender;
            _gambler.gamblerID = gamblerID.current();

            gamblerAddressArray.push(msg.sender);       // adding gambler's address to the array
            emit GamblerAdded(msg.sender, gamblerID.current());
        }
    }

    // FUNCTION to let users create a LOTTO
    function createLotto(uint256 _ticketPrice, uint256 _minParticipants, uint256 _maxParticipants, uint256 _drawTime, LottoType _lottoType) payable external {
        lottoID.increment();                        // new lotto ID
        lottoIDArray.push(lottoID.current());       // push newly created lotto ID to array

        addGambler(); // adding gambler(organizer) if doesnot exists

        LottoEvent storage _lotto = lottoMapping[lottoID.current()];
        _lotto.organizer = msg.sender;
        _lotto.lottoPot = msg.value;
        _lotto.balance = msg.value;
        _lotto.ticketPrice = _ticketPrice;
        _lotto.maxParticipants = _maxParticipants;
        _lotto.minParticipants = _minParticipants;
        _lotto.lottoType = _lottoType;
        _lotto.lottoStatus = LottoStatus.ACTIVE;
        _lotto.activeTime = block.timestamp;
        _lotto.drawTime = _drawTime;

        organizersArray.push(msg.sender);

        emit LottoCreated(lottoID.current(), msg.value);
    }

    // FUNCTION to let users to participate in LOTTO
    function participate(uint256 _lottoID) payable external isLotto(_lottoID) isLottoActive(_lottoID) hasLottoMaxedOut(_lottoID) {
        require(msg.value == lottoMapping[lottoID.current()].ticketPrice, "Ticket price");
        addGambler();
        lottoMapping[lottoID.current()].participants.push(msg.sender);
        lottoMapping[lottoID.current()].balance.add(msg.value);
        participantsArray.push(msg.sender);
        emit LottoTicketSold(_lottoID, msg.sender);
    }

    // FUNCTION to let everyone to make lucky draw
    function drawLotto(uint256 _lottoID) external hasLottoTimesUp(_lottoID) isLottoNotConcluded(_lottoID) {
        uint256 _randomNumber = 25;

        // getting 1st 2nd and 3rd winner
        for (uint8 i=1; i<=3; i++) {
            // getting winning participant's array index
            uint256 _winnerIndex = generateRandomNumber(_randomNumber, i) % lottoMapping[_lottoID].participants.length;
            // getting winning participant's array
            address _winnerAddress = lottoMapping[_lottoID].participants[_winnerIndex];
            // updating LOTTO object with winners ID
            lottoMapping[_lottoID].winners.push(_winnerAddress);
            // updating winner's balance and reducing LOTTO balance
            gamblerMapping[_winnerAddress].balance.add(prizeCalculator(_lottoID, i));
        }

        // transfering lotto's balance to organizer
        gamblerMapping[lottoMapping[_lottoID].organizer].balance.add(lottoMapping[_lottoID].balance);
        lottoMapping[_lottoID].balance = 0;

        // updating lotto status
        lottoMapping[_lottoID].lottoStatus = LottoStatus.CONCLUDED;

        emit LottoWinnersAnnounced(_lottoID, lottoMapping[_lottoID].winners[0], lottoMapping[_lottoID].winners[1], lottoMapping[_lottoID].winners[2]);
    }

    // FUNCTION to let everyone to make lucky draw
    function withdraw(uint256 amount) external {
        require(gamblerMapping[msg.sender].balance >= amount, "Donnt have sufficient balance");
        gamblerMapping[msg.sender].balance.sub(amount);
        (bool _success, ) = payable(msg.sender).call{ value: amount }("");      // transfering funds

        //  if transfer succeed
        if (_success) {
            emit WithdrawSuccessfull(msg.sender, _amount);      // emit event
        } else{
            revert ("Unable to sent transaction because of some reason.");
        }
    }

    // FUNCTION to get LOTTO object
    function getLotto(uint256 _lottoID) view external returns(LottoEvent memory) {
        return lottoMapping[_lottoID];
    }

    // FUNCTION to get Prticipants object
    function getGambler() view external returns(Gambler memory) {
        return gamblerMapping[msg.sender];
    }

    function getContractBalance() view external returns(uint256) {
        return address(this).balance;
    }
}