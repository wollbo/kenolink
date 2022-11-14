pragma solidity ^0.8.7;
// skip using price feeds to calculate fees 
// unless funds are paid out between each round

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract Keno is VRFConsumerBaseV2, ConfirmedOwner {
    // 0 is not a playable number
    // temporary solution: 1 + VRF % 69
    // not an equally distributed probability
    // probably better to do linear search
    enum State {PREPARING, RUNNING, FINISHED}
    mapping(address => mapping(int => bool)) active; // if player stake has been paid/withdrawn or not
    mapping(address => mapping(int => uint)) levels; // player Keno level, needs to be provided and cant simply be encoded in tips
    mapping(address => mapping(int => uint256[12])) tips; // player chosen numbers for given round. 11 long, unplayed levels marked with 0, last for king keno flag
    mapping(int => uint256[20]) winners; // map roundid to winners 
    mapping(int => uint) kings;
    int round; // current round
    uint players; // number of players in the current round
    uint pool; // carries amount of bets for upcoming round
    uint past; // sum of previous pool, subtracted by payouts
    uint reserve; // accumulated reserves by sum of pasts

    uint256[20] public winner; // drawn by VRF
    uint public king; // drawn by VRF
    State public state;

    address recipient;

    uint public MIN_PLAYERS = 1;
    uint public BASE_FEE = 5 * 10 ** 10; // 100 gwei minimum entry, for simplicity only offer one bet size. 100 gwei = 10 sek in comparison

    mapping(uint => uint256[12]) table; // keno win table - no king
    mapping(uint => uint256[12]) kable; // keno win table - with king

    // Keeper 
    address keeper;

    // VRF code below here
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas
    uint32 callbackGasLimit = 2500000; // maximum

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 100; // draw 20

    constructor(uint64 _subscriptionId)
        VRFConsumerBaseV2(0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed);
        s_subscriptionId = _subscriptionId;

        recipient = owner();
        round = 1;

        // construction of regular keno table
        table[1] = [0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        table[2] = [0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        table[3] = [0, 0, 2, 7, 0, 0, 0, 0, 0, 0, 0, 0];
        table[4] = [0, 0, 1, 3, 10, 0, 0, 0, 0, 0, 0, 0];
        table[5] = [0, 0, 0, 2, 7, 10, 0, 0, 0, 0, 0, 0];
        table[6] = [0, 0, 0, 1, 4, 13, 170, 0, 0, 0, 0, 0];
        table[7] = [0, 0, 0, 0, 2, 13, 40, 1000, 0, 0, 0, 0];
        table[8] = [0, 0, 0, 0, 2, 2, 20, 100, 4500, 0, 0, 0];
        table[9] = [0, 0, 0, 0, 0, 2, 14, 60, 540, 25000, 0, 0];
        table[10] = [1, 0, 0, 0, 0, 2, 4, 20, 160, 1500, 100000, 0];
        table[11] = [0, 0, 0, 0, 0, 2, 2, 5, 40, 400, 8000, 500000];

        // construction of king keno table
        kable[1] = [0, 39, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        kable[2] = [0, 8, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        kable[3] = [0, 7, 12, 50, 0, 0, 0, 0, 0, 0, 0, 0];
        kable[4] = [0, 7, 8, 11, 100, 0, 0, 0, 0, 0, 0, 0];
        kable[5] = [0, 10, 4, 7, 20, 250, 0, 0, 0, 0, 0, 0];
        kable[6] = [0, 8, 3, 5, 10, 32, 1000, 0, 0, 0, 0, 0];
        kable[7] = [0, 8, 2, 4, 6, 30, 100, 2500, 0, 0, 0, 0];
        kable[8] = [0, 8, 3, 3, 4, 6, 68, 200, 13000, 0, 0, 0];
        kable[9] = [0, 10, 2, 3, 3, 5, 20, 100, 1000, 60000, 0, 0];
        kable[10] = [0, 8, 2, 2, 3, 4, 10, 50, 320, 3000, 200000, 0];
        kable[11] = [0, 20, 2, 2, 2, 3, 4, 24, 100, 800, 16000, 1000000];
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() internal onlyOwner returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({randomWords: new uint256[](0), exists: true, fulfilled: false});
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function convertToWinner(uint256[] memory _randomWords) public pure returns (uint256[20] memory _winners) { // we just take one random word and segment it
        uint i; // randomWords index, always iterates
        uint j; // _winners index, iterates if number is suitable
        uint len; // lenght of _winners
        bool exists;
        while (i < _randomWords.length - 1 && len < 20) { // two digit numbers
            j = 0;
            exists = false; // reset here 
            uint number = _randomWords[i] % 69 + 1; // we dont want zero
            while (j < len && exists == false) {
                if (_winners[j] == number) {
                    exists = true;
                }
                j++;
            }
            if (exists == false) {
                _winners[len] = number;
                len++;
            }
            i++;
        }
        return _winners;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override { // who is allowed to fulfill?
        require(s_requests[_requestId].exists, 'request not found');
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(uint256 _requestId) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, 'request not found');
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function newMinPlayers(uint _newPlayers) public onlyOwner {
        require(state == State.FINISHED);
        MIN_PLAYERS = _newPlayers;
    }

    function newBaseFee(uint _newFee) public onlyOwner {
        require(state == State.FINISHED);
        BASE_FEE = _newFee;
    }

    function deposit() public payable onlyOwner {
        reserve = reserve + msg.value;
    }

    function donate(uint _amount) public payable onlyOwner {
        require(state == State.FINISHED);
        require(_amount < reserve - past - pool); // can't transfer more than liabilities
        payable(recipient).transfer(_amount);
    }

    function assignKeeper(address _keeper) public onlyOwner {
        require(state == State.FINISHED || state == State.PREPARING);
        keeper = _keeper;
    }

    function assignRecipient(address _newRecipient) public onlyOwner {
        require(state == State.FINISHED);
        recipient = _newRecipient;
    }

    function getRound() public view returns (int) {
        return round;
    }

    function getPool() public view returns (uint) {
        return pool;
    }

    function getPast() public view returns (uint) {
        return past;
    }

    function getPlayers() public view returns (uint) {
        return players;
    }

    function getReserve() public view returns (uint) {
        return reserve;
    }

    function isActive(int _round) public view returns (bool) {
        return active[msg.sender][_round];
    } 

    function historicWinners(int _round) public view returns (uint256[20] memory) {
        return winners[_round];
    }

    function historicKings(int _round) public view returns (uint) {
        return kings[_round];
    }

    function tipLength(uint256[12] memory _numbers) public pure returns (uint) {
        uint len;
        uint i;
        for (i = 0; i < _numbers.length - 1; i++) { // last entry is the King flag
            if (_numbers[i] > 0) {
                len++;
            }
        }
        return len;
    }

    function kingKeno(uint256[12] memory _numbers, uint _king) public pure returns (bool) { 
        // calculates whether played tips contain King or not
        bool _keno;
        uint i;
        for (i = 0; i < _numbers.length - 1; i++) { // last entry is the King flag
            if (_numbers[i] == _king) {
                _keno = true;
            }
        }
        return _keno;
    }

    function count(uint256[12] memory _numbers, uint _len, uint256[20] memory _winners) public pure returns (uint) {
        // calculates how many of player numbers were in the winners
        uint i;
        uint j;
        uint w;
        for (i = 0; i < _len; i++) { // avoid some calculation here since len already known
            for (j = 0; j < _winners.length; j++) {
                if (_numbers[i] == _winners[j]) {
                    w = w + 1;
                }
            }
        }
        return w;
    }

    function fee(uint _level, uint256[12] memory _numbers) public view returns (uint) { // fee calculated here 
        require(_level >= tipLength(_numbers), "Too many numbers for Keno level");
        if (_numbers[11] > 0) { // player is participating in King keno if _numbers[11] > 0
            return 4 * BASE_FEE; // king keno is 2x fee
        }
        return 2 * BASE_FEE; // fee is independent of keno level, keno level dictates probability/payout
    }

    function winnings(uint _level, uint _wins, bool _keno) public view returns (uint) { // compare Keno outside this function
        require(_level >= _wins);
        if (_keno) { // all payout tables are calculated with multiple of 10, minamount is 5
            return 2 * kable[_level][_wins];
        }
        return 2 * table[_level][_wins];
    }

    function enter(uint _level, uint256[12] memory _numbers) public payable {
        require(state == State.PREPARING);
        require(msg.value == fee(_level, _numbers), "Wrong amount provided");
        tips[msg.sender][round] = _numbers;
        active[msg.sender][round] = true;
        levels[msg.sender][round] = _level;
        pool = pool + msg.value;
        players = players + 1;
    }

    function withdraw(int _round) public payable {
        require(state == State.PREPARING);
        require(active[msg.sender][_round] == true);
        require(round == _round, "Round already done");
        if (tips[msg.sender][_round][11] > 0) {
            payable(msg.sender).transfer(BASE_FEE * 4);
            pool = pool - BASE_FEE * 4;
        }
        else {
            payable(msg.sender).transfer(BASE_FEE * 2);
            pool = pool - BASE_FEE * 2;
        }
        players = players - 1;
        active[msg.sender][_round] = false;
    }

    function vrf() public payable { // called by keeper, requests VRF number
        require(msg.sender == owner() || msg.sender == keeper);
        require(state == State.PREPARING);
        require(players >= MIN_PLAYERS);
        state = State.RUNNING; // should pause for 15 minutes in RUNNING state, then reset
        requestRandomWords();
        // requests random number from VRF ...
    }

    function draw() public { // called by keeper, draws VRF number
        require(msg.sender == owner() || msg.sender == keeper);
        require(state == State.RUNNING);
        require(s_requests[lastRequestId].fulfilled == true, "Request not yet fulfilled");
        RequestStatus memory request = s_requests[lastRequestId];
        winner = convertToWinner(request.randomWords); // this needs error control 
        king = request.randomWords[request.randomWords[19] % 19]; // saves computation
        winners[round] = winner;
        kings[round] = king;
        state = State.FINISHED;
    }

    function reset() public { // called by keeper after a small time window in which owner can update parameters
        require(msg.sender == owner() || msg.sender == keeper);
        require(state == State.FINISHED);
        reserve = reserve + past;
        round = round + 1; 
        past = pool;
        pool = 0;
        players = 0;
        state = State.PREPARING;
    }

    function calculate(uint _claim) private returns (uint) { // calculates how much you won; balances with vault to maintain protocol solvency
        /* Payout priority
        / 1. Payout _claim if _claim <= past; past = past - _claim;
        / 2. Payout _claim if _claim > past and _claim - past < 0.5 * reserve; reserve = reserve - _claim + past; past = 0;
        / 3. Payout _claim if _claim < 0.5 * reserve; reserve = reserve - _claim;
        / 4. Payout reserve / 2; reserve = reserve / 2;
        */
        if (_claim <= past) {
            past = past - _claim;
            return _claim;
        }
        else if (_claim - past < reserve / 2 && past > 0) {
            reserve = reserve - _claim + past; // possible that these state changes should happen outside
            past = 0;
            return _claim;
        }
        else if (_claim < reserve / 2) {
            reserve = reserve - _claim;
            return _claim;
        }
        else {
            _claim = reserve / 2;
            reserve = _claim;
            return _claim;
        }
    }

    function payout(int _round) public payable { // problem; previous winners should not have access to "past" pool of last round
        require(state == State.PREPARING || state == State.FINISHED);
        require(active[msg.sender][_round] == true, "Player is not active in this round");
        uint wins = count(tips[msg.sender][_round], levels[msg.sender][_round], winners[_round]);
        if (tips[msg.sender][_round][11] > 0 && kingKeno(tips[msg.sender][_round], kings[_round])) {
            if (winnings(levels[msg.sender][_round], wins, true) > 0) {
                payable(msg.sender).transfer(calculate(BASE_FEE * winnings(levels[msg.sender][_round], wins, true)));
                active[msg.sender][_round] = false;
            }
        }
        else {
            if (winnings(levels[msg.sender][_round], wins, false) > 0) {
                payable(msg.sender).transfer(calculate(BASE_FEE * winnings(levels[msg.sender][_round], wins, false)));
                active[msg.sender][_round] = false;
            }
        }
    }
}
