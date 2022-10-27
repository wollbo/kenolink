// skip using price feeds to calculate fees 
// unless funds are paid out between each round

contract Keno {
    // 0 is not a playable number
    // temporary solution: 1 + VRF % 72  
    // not an equally distributed probability
    enum State {PREPARING, RUNNING, FINISHED}
    mapping(address => mapping(int => bool)) active; // if player stake has been paid/withdrawn or not
    mapping(address => mapping(int => uint)) levels; // player Keno level
    mapping(address => mapping(int => uint256[4])) tips; // player chosen numbers for given round # 4 for testing 21 for live
    mapping(int => uint256[3]) winners; // map roundid to winners + king keno # 3 for testing 20 for live
    mapping(int => uint) kings;
    int round;
    uint players; // number of players in the current round
    uint pool; // may only pay out the sum of the staked bets for a single round
    uint past; // sum of previous pool, can be paid out between lotteries

    bool win; // temporary variable used in winnings calculation

    address public owner;
    uint256[3] public winner; // drawn by VRF
    uint public king; // drawn by VRF
    State public state;

    uint public MIN_PLAYERS = 1;
    uint public MIN_FEE = 1000; // 1000 gwei minimum

    constructor() {
        owner = msg.sender;
        round = 1;
        pool = 0;
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

    function fee(uint _level, uint256[4] memory _numbers) public view returns (uint) { // fee calculated here 
        require(_numbers.length >= _level); // temporary
        // player is participating in King keno if _numbers[21] > 0
        return MIN_FEE;
    }

    function winnings(uint _level, uint[4] memory _tips, uint[3] memory _winners, bool _keno) public returns (bool) { // compare Keno outside this function
        require(_tips.length >= _level);
        win = false;
        if (_winners[0] == _tips[0] || _keno) {
            win = true;
        }
        return win;
    }

    function enter(uint _level, uint256[4] memory _numbers) public payable {
        require(state == State.PREPARING);
        require(msg.value == fee(_level, _numbers));
        tips[msg.sender][round] = _numbers;
        active[msg.sender][round] = true;
        levels[msg.sender][round] = _level;
        pool = pool + msg.value;
        players = players + 1;
    }

    function withdraw() public payable {
        require(state == State.PREPARING);
        require(active[msg.sender][round] == true);
        players = players - 1;
        // pay out based on fee calculation
        // past = past - fee()
    }

    function draw() public payable { // called by keeper, draws VRF number
        require(state == State.PREPARING);
        require(players >= MIN_PLAYERS);
        state = State.RUNNING; // should pause for 15 minutes in RUNNING state, then draw numbers
        // requests random number from VRF ...
    }

    function reset() public { // called by oracle callback
        require(state == State.RUNNING);
        winner = [1, 2, 3]; //, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];
        king = 21; 
        // king keno can be determined by
        // idx = winner[21] % 20; king = winner[idx]

        winners[round] = winner; // do this in callback function
        kings[round] = king; // and this
        round = round + 1;
        past = pool;
        pool = 0;
        players = 0;
        state = State.PREPARING;
    }


    function payout(int round_id) public payable { // round participation is stored in DB
        require(state == State.PREPARING || state == State.FINISHED);
        require(active[msg.sender][round_id] == true, "Player is not active in this round");
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
        
        if (tips[msg.sender][round_id][3] > 0 && tips[msg.sender][round_id][3] == kings[round_id]) {
            if (winnings(levels[msg.sender][round_id], tips[msg.sender][round_id], winners[round_id], true)) {
                payable(msg.sender).transfer(MIN_FEE); // for testing
                active[msg.sender][round_id] = false;
            }
        }
        else {
            if (winnings(levels[msg.sender][round_id], tips[msg.sender][round_id], winners[round_id], false)) {
                payable(msg.sender).transfer(MIN_FEE); // for testing
                active[msg.sender][round_id] = false;
            }
        }
    }
}
