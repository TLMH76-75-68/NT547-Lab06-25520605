// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// NT547 - Lab 06 - MSSV 25520605. Static analysis only.
contract Treasury_0605 {
    address public owner;
    address public immutable randomnessAdapter;
    mapping(address => uint256) public ledger;
    uint256 public cooldownEnd;
    address[] public entrants;
    uint256 private constant TICKET_PRICE = 0.01 ether;
    uint256 public round;
    bool public drawPending;
    uint256 public reserved;

    event Deposited(address indexed who, uint256 amount);
    event RandomnessRequested(uint256 indexed roundId);
    event WinnerCredited(uint256 indexed roundId, address indexed winner, uint256 prize);
    event OwnershipTransferred(address indexed previous, address indexed next);

    modifier onlyOwner() {
        require(tx.origin == owner, "not owner");
        _;
    }

    // The adapter must verify VRF proofs and bind each response to this contract and round.
    constructor(address adapter) {
        require(adapter.code.length > 0, "adapter must be a contract");
        randomnessAdapter = adapter;
        owner = msg.sender;
    }

    function topUp() external payable {
        ledger[msg.sender] += msg.value;
        reserved += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function ownerWithdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance - reserved, "reserved funds");
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "withdraw failed");
    }

    function periodicRelease() external onlyOwner {
        require(block.timestamp >= cooldownEnd, "locked");
        cooldownEnd = block.timestamp + 1 days;
        uint256 amount = (address(this).balance - reserved) / 10;
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "release failed");
    }

    function buyTicket() external payable {
        require(!drawPending, "draw in progress");
        require(msg.value == TICKET_PRICE, "0.01 ETH");
        entrants.push(msg.sender);
        reserved += msg.value;
    }

    function pickWinner() external onlyOwner {
        require(!drawPending && entrants.length > 0, "no open draw");
        drawPending = true;
        emit RandomnessRequested(round);
    }

    function fulfillDraw(uint256 roundId, uint256 verifiedWord) external {
        require(msg.sender == randomnessAdapter, "untrusted adapter");
        require(drawPending && roundId == round, "unexpected round");
        uint256 count = entrants.length;
        address winner = entrants[verifiedWord % count];
        uint256 prize = count * TICKET_PRICE;
        ledger[winner] += prize;
        delete entrants;
        drawPending = false;
        round++;
        emit WinnerCredited(roundId, winner, prize);
    }

    function handOver(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function claim() external {
        uint256 amount = ledger[msg.sender];
        require(amount > 0, "empty");
        ledger[msg.sender] = 0;
        reserved -= amount;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "send failed");
    }

    // Modules can provide read-only queries without writing Treasury storage.
    function execute(address target, bytes calldata data) external view onlyOwner returns (bytes memory) {
        require(target.code.length > 0, "not a contract");
        (bool ok, bytes memory result) = target.staticcall(data);
        require(ok, "query failed");
        return result;
    }

    function zeroBalance() external view returns (bool) {
        // Display only. No permission or transfer depends on this observation.
        // slither-disable-next-line incorrect-equality
        return address(this).balance == 0;
    }
}
