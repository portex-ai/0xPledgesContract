// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract PortexPledge {
    address public immutable deployer;
    address public immutable beneficiary;
    address public immutable oracle;
    uint256 public immutable expirationTimestamp;
    uint256 public expirationBuffer;
    string public appId;
    uint256 public amount;
    uint256 public oracleFee;
    bool public verified;
    bool public result;

    event PledgeCreated(address indexed deployer, address indexed beneficiary, address indexed oracle, uint256 expirationTimestamp, uint256 amount, string appId, uint256 oracleFee);
    event PledgeVerified(bool result, address indexed oracle);
    event FundsWithdrawn(address indexed recipient, uint256 amount);

    constructor(uint256 _expirationTimestamp, uint256 _expirationBuffer, address _beneficiary, address _oracle, string memory _appId, uint256 _oracleFee) payable {
        require(msg.value >= _oracleFee, "Insufficient funds to cover oracle fee");
        deployer = msg.sender;
        amount = msg.value;
        beneficiary = _beneficiary;
        oracle = _oracle;
        expirationTimestamp = _expirationTimestamp;
        expirationBuffer = _expirationBuffer;
        appId = _appId;
        oracleFee = _oracleFee; 
        emit PledgeCreated(deployer, beneficiary, oracle, expirationTimestamp, amount, appId, oracleFee);
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
        require(block.timestamp >= expirationTimestamp, "Pledge has not expired yet");
        require(block.timestamp <= expirationTimestamp + expirationBuffer, "Verification period has expired");
        require(!verified, "Pledge already verified");

        verified = true;
        result = _result;

        uint256 balance = address(this).balance - oracleFee;
        address recipient = _result ? deployer : beneficiary;

        (bool successToRecipient, ) = payable(recipient).call{value: balance}("");
        require(successToRecipient, "Transfer to recipient failed.");
        emit FundsWithdrawn(recipient, balance);

        (bool successToOracle, ) = payable(oracle).call{value: oracleFee}("");
        require(successToOracle, "Transfer to oracle failed.");
        emit PledgeVerified(_result, oracle);
    }

    function withdraw() external onlyDeployer {
        require(block.timestamp > expirationTimestamp + expirationBuffer, "Cannot withdraw before verification period ends");
        require(!verified, "Pledge already verified");

        uint256 balance = address(this).balance;
        (bool success, ) = payable(deployer).call{value: balance}("");
        require(success, "Transfer to deployer failed.");
        emit FundsWithdrawn(deployer, balance);
    }
}