pragma solidity ^0.8.7;
// skip using price feeds to calculate fees 
// unless funds are paid out between each round

contract Keno {
    // 0 is not a playable number
    // temporary solution: 1 + VRF % 70
    // not an equally distributed probability
    // probably better to do linear search
    enum State {PREPARING, RUNNING, FINISHED}
    mapping(address => mapping(int => bool)) active; // if player stake has been paid/withdrawn or not
    mapping(address => mapping(int => uint)) levels; // player Keno level, needs to be provided and cant simply be encoded in tips
    mapping(address => mapping(int => uint256[12])) tips; // player chosen numbers for given round. 11 long, unplayed levels marked with 0, last for king keno
    mapping(int => uint256[20]) winners; // map roundid to winners 
    mapping(int => uint) kings;
    int round; // current round
    uint players; // number of players in the current round
    uint pool; // carries amount of bets for upcoming round
    uint past; // sum of previous pool, subtracted by payouts
    uint reserve; // accumulated reserves by sum of pasts

    address public owner;
    uint256[20] public winner; // drawn by VRF
    uint public king; // drawn by VRF
    State public state;

    uint public MIN_PLAYERS = 1;
    uint public BASE_FEE = 5 * 10 ** 8; // 1 gwei minimum entry, for simplicity only offer one bet size. 1 gwei = 10 sek in comparison

    mapping(uint => uint256[12]) table; // keno win table - no king
    mapping(uint => uint256[12]) kable; // keno win table - with king


    constructor() {
        owner = msg.sender;
        round = 1;
        pool = 0;
        reserve = 0;

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

    function newMinPlayers(uint _newPlayers) public {
        require(msg.sender == owner);
        MIN_PLAYERS = _newPlayers;
    }

    function newBaseFee(uint _newFee) public {
        require(msg.sender == owner);
        BASE_FEE = _newFee;
    }

    function deposit() public payable {
        require(msg.sender == owner);
        reserve = reserve + msg.value;
    }

    function getRound() public view returns (int) {
        return round;
    }

    function getPool() public view returns (uint) {
        return pool;
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
        // pay out based on fee calculation
        // past = past - fee()
        if (tips[msg.sender][_round][11] > 0) {
            payable(msg.sender).transfer(BASE_FEE * 2);
        }
        else {
            payable(msg.sender).transfer(BASE_FEE);
        }
        players = players - 1;
        active[msg.sender][_round] = false;
    }

    function draw() public payable { // called by keeper, draws VRF number
        require(state == State.PREPARING);
        require(players >= MIN_PLAYERS);
        state = State.RUNNING; // should pause for 15 minutes in RUNNING state, then draw numbers
        // requests random number from VRF ...
    }

    function reset() public { // called by oracle callback
        require(state == State.RUNNING);
        winner = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];
        king = 9; 
        // king keno can be determined by
        // idx = winner[21] % 20; king = winner[idx]
        reserve = reserve + past;
        winners[round] = winner; // do this in callback function
        kings[round] = king; // and this
        round = round + 1; // this is the start of the real reset function
        past = pool;
        pool = 0;
        players = 0;
        state = State.PREPARING;
        // balance = reserve + past + pool
    }

    function calculate(uint _claim) private returns (uint) { // calculates how much you won; balances with vault to maintain protocol solvency
        /* Payout priority
        / 1. Payout _claim if _claim <= past; past = past - _claim;
        / 2. Payout _claim if _claim > past and _claim - past < 0.5 * reserve; reserve = reserve - _claim + past; past = 0;
        / 3. Payout _claim if _claim < 0.5 * reserve; reserve = reserve - _claim;
        / 4. Payout reserve / 2; reserve = reserve / 2;
        */
        if (_claim <= past) {
            return _claim;
        }
        else if (_claim - past < reserve / 2) {
            reserve = reserve - _claim + past; // possible that these state changes should happen outside
            past = 0;
            return _claim;
        }
        else {
            _claim = reserve / 2;
            reserve = _claim;
            return _claim;
        }
    }

    function payout(int _round) public payable { // round participation is stored in DB
        require(state == State.PREPARING || state == State.FINISHED);
        require(active[msg.sender][_round] == true, "Player is not active in this round");
        // this needs some thought - how does smart contract know how many have won and how much?
        // what happens if there are more winning claims than deposited funds in a round?
        /*
        / - one solution is to maintain a surplus at all times 
        / otherwise necessary to iterate over all deposited bets in a round - not feasible
        / 
        / - early claimers get their "full" reward while latecomers get nothing
        / maintains protocol solvency, benefits early claimants but bad user experience
        /
        / - maintain and display an excess vault collected from protocol profits, only used as "insurance"
        / early claimants get their full reward from fee pool for the current round (claimed before next round has ended)
        / late claimants get their full reward from insurance pool 
        / OR a given % of the insurance pool (whichever number is smallest)
        / 
        / - insurance vault should also be used to fund charity/ideal organization
        */
        uint wins = count(tips[msg.sender][_round], levels[msg.sender][_round], winners[_round]);
        if (tips[msg.sender][_round][11] > 0 && kingKeno(tips[msg.sender][_round], kings[_round])) {
            if (winnings(levels[msg.sender][_round], wins, true) > 0) {
                payable(msg.sender).transfer(BASE_FEE * calculate(winnings(levels[msg.sender][_round], wins, true)));
                active[msg.sender][_round] = false;
            }
        }
        else {
            if (winnings(levels[msg.sender][_round], wins, false) > 0) {
                payable(msg.sender).transfer(BASE_FEE * calculate(winnings(levels[msg.sender][_round], wins, false)));
                active[msg.sender][_round] = false;
            }
        }
    }
}
