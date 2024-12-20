// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PortexPledge {
    address public immutable deployer;
    address public immutable beneficiary;
    address public immutable oracle;
    uint256 public immutable expirationBlock;
    uint256 public expirationBlockBuffer;
    string public appId; 
    uint256 public amount;
    uint256 public oracleFee;
    bool public verified;
    bool public result;

    event PledgeCreated(address indexed deployer, address indexed beneficiary, address indexed oracle, uint256 expirationBlock, uint256 amount, string appId, uint256 oracleFee);
    event PledgeVerified(bool result, address indexed oracle);
    event FundsWithdrawn(address indexed recipient, uint256 amount);

    constructor(uint256 _expirationBlock, uint256 _expirationBlockBuffer, address _beneficiary, address _oracle, string memory _appId, uint256 _oracleFee) payable {
        require(msg.value >= _oracleFee, "Insufficient funds to cover oracle fee");
        deployer = msg.sender;
        amount = msg.value;
        beneficiary = _beneficiary;
        oracle = _oracle;
        expirationBlock = _expirationBlock;
        expirationBlockBuffer = _expirationBlockBuffer;
        appId = _appId;
        oracleFee = _oracleFee; 
        emit PledgeCreated(deployer, beneficiary, oracle, expirationBlock, amount, appId, oracleFee);
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "Only oracle can call this function");
        _;
    }

    modifier onlyDeployer() {
        require(msg.sender == deployer, "Only the deployer can call this function");
        _;
    }

    function verifyPledge(bool _result) external onlyOracle {
        require(block.number >= expirationBlock, "Pledge has not expired yet");
        require(block.number <= expirationBlock + expirationBlockBuffer, "Verification period has expired");
        require(!verified, "Pledge already verified");

        verified = true;
        result = _result;

        uint256 balance = address(this).balance - oracleFee;
        address recipient = _result ? deployer : beneficiary;
        payable(recipient).transfer(balance);
        emit FundsWithdrawn(recipient, balance);

        payable(oracle).transfer(oracleFee);
        emit PledgeVerified(_result, oracle);
    }

    function withdraw() external onlyDeployer {
        require(block.number > expirationBlock + expirationBlockBuffer, "Cannot withdraw before verification period ends");
        require(!verified, "Pledge already verified");

        uint256 balance = address(this).balance;
        payable(deployer).transfer(balance);
        emit FundsWithdrawn(deployer, balance);
    }
}