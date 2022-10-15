// skip using price feeds to calculate fees 
// unless funds are paid out between each round

contract Keno {

    enum State {PREPARING, RUNNING, FINISHED}
    mapping(address => mapping(int => bool)) active; // if player stake has been treated or not
    mapping(address => mapping(int => bool)) keno; // if player participating in King Keno
    mapping(address => mapping(int => uint256[])) tips; // player chosen numbers for given round
    mapping(int => uint256[]) winners; // map roundid to winners + king keno
    mapping(int => uint) kings;
    int round;
    uint pool; // may only pay out the sum of the staked bets for a single round

    address public owner;
    address payable[] public players;
    uint256[] public winner; // drawn by VRF
    uint public king; // drawn by VRF
    State public state;

    uint public MIN_PLAYERS = 1;
    uint public MIN_FEE = 1000; // 1000 gwei minimum

    constructor() {
        owner = msg.sender;
        round = 1;
        pool = 0;
    }

    function fee(uint _level, uint256[] memory _numbers, bool _keno) public payable returns (uint) { // fee calculated here or off-chain?
        require(_numbers.length <= _level);
        require(_keno == true); // temporary

        return MIN_FEE;
    }

    function enter(uint _level, uint256[] memory _numbers, bool _keno) public payable {
        require(state == State.PREPARING);
        require(msg.value == fee(_level, _numbers, _keno));
        tips[msg.sender][round] = _numbers;
        keno[msg.sender][round] = _keno;
        pool = pool + msg.value;
    }

    function withdraw() public payable {
        require(state == State.PREPARING);
        require(active[msg.sender][round] == true);
        // pay out based on fee calculation
        // pool = pool - fee()
    }

    function draw() public payable { // called by keeper, draws VRF number
        require(state == State.PREPARING);
        state = State.RUNNING; // should pause for 15 minutes in RUNNING state, then draw numbers
        winner = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];
        king = 21;

        winners[round] = winner; // do this in callback function
        kings[round] = king; // and this
    }

    function payout(int round_id) public payable { // round participation is stored in DB
        require(state == State.PREPARING || state == State.FINISHED);
        require(active[msg.sender][round_id] == true);
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
        / early claimants get their full reward from fee pool for the current round
        / late claimants get their full reward from insurance pool 
        / OR a given % of the insurance pool (whichever number is smallest)
        / 
        / - insurance vault should also be used to fund charity/ideal organization
        */

    }

    function reset() public {
        require(state == State.RUNNING);
        round = round + 1;
        pool = 0;
        state = State.PREPARING;
    }
}