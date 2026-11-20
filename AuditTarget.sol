// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// NT547 - Lab 06 - Hop dong rieng cua MSSV 25520605. KHONG deploy len mainnet.

interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Treasury_0605 {
    address public owner;
    mapping(address => uint256) public ledger;
    uint256 public cooldownEnd;
    address[] public entrants;

    event Deposited(address indexed who, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function topUp() external payable {
        ledger[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function ownerWithdraw(uint256 amount) external onlyOwner {
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "withdraw failed");
    }

    function periodicRelease() external onlyOwner {
        require(block.timestamp >= cooldownEnd, "locked");
        cooldownEnd = block.timestamp + 1 days;
        (bool ok, ) = payable(owner).call{value: address(this).balance / 10}("");
        require(ok, "release failed");
    }

    function buyTicket() external payable {
        require(msg.value == 0.01 ether, "0.01 ETH");
        entrants.push(msg.sender);
    }

    function pickWinner() external onlyOwner {
        require(entrants.length > 0, "no players");
        uint256 idx = block.timestamp % entrants.length;
        address winner = entrants[idx];
        delete entrants;
        (bool ok, ) = payable(winner).call{value: address(this).balance}("");
        require(ok, "prize failed");
    }

    function handOver(address newOwner) external {
        require(tx.origin == owner, "not owner");
        require(newOwner != address(0), "zero");
        owner = newOwner;
    }

    function claim() external {
        uint256 amount = ledger[msg.sender];
        require(amount > 0, "empty");
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "send failed");
        ledger[msg.sender] = 0;
    }

    function execute(address target, bytes calldata data) external {
        (bool ok, ) = target.delegatecall(data);
        require(ok, "delegatecall failed");
    }

    function zeroBalance() external view returns (bool) {
        return address(this).balance == 0;
    }
}
