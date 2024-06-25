// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Propose is Ownable {
    uint256 private s_proposalId;
    address private s_listingContract;
    address private s_executorContract;

    uint256 public constant MIN_AUTO_CLOSE_TIME = 7 days;
    uint256 public constant MIN_CLOSE_INC_TIME = 1 days;
    uint256 public constant MIN_PROPOSAL_ETH = 0.001 ether;

    enum ProposalStatus {
        Pending,
        Approved,
        Closed,
        AutomaticallyClosed
    }

    struct Proposal {
        uint256 proposalId;
        address proposer;
        uint256 amount;
        uint256 projectId;
        uint256 autoCloseTime;
        ProposalStatus status;
        bytes metadataUrl;
    }

    mapping(uint256 => Proposal) public s_proposalMap;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        uint256 indexed projectId,
        uint256 amount,
        uint256 autoCloseTime,
        string metadataUrl
    );

    event ProposalUpdated(
        uint256 indexed proposalId,
        uint256 indexed projectId,
        uint256 autoCloseTime,
        string metadataUrl
    );

    event ProposalStatusUpdated(
        uint256 indexed proposalId,
        ProposalStatus proposalStatus
    );

    constructor() Ownable(msg.sender) {}

    modifier onlyExecutor() {
        require(msg.sender == s_executorContract, "Caller not executor");
        _;
    }

    modifier metadataCheck(string memory metadataUrl) {
        require(bytes(metadataUrl).length > 0, "Metadata URL cannot be empty");
        _;
    }

    function getListingContract() external view returns (address) {
        return s_listingContract;
    }

    function getExecutorContract() external view returns (address) {
        return s_executorContract;
    }

    function getLastProposalId() external view returns (uint256) {
        return s_proposalId;
    }

    function createProposal(
        uint256 projectId,
        uint256 autoCloseTime,
        string memory metadataUrl
    ) external payable metadataCheck(metadataUrl) {
        require(
            msg.value >= MIN_PROPOSAL_ETH,
            "Amount must be greater than 0.001"
        );
        require(
            autoCloseTime >= block.timestamp + MIN_AUTO_CLOSE_TIME,
            "Auto close time must be at least 7 days from now"
        );
        // TODO: require projectId should be lt last proposal id

        s_proposalId++;
        s_proposalMap[s_proposalId] = Proposal(
            s_proposalId,
            msg.sender,
            msg.value,
            projectId,
            autoCloseTime,
            ProposalStatus.Pending,
            bytes(metadataUrl)
        );

        emit ProposalCreated(
            s_proposalId,
            msg.sender,
            msg.value,
            projectId,
            autoCloseTime,
            metadataUrl
        );
    }

    // TODO: split this func to allow updation of metadata url and autoclose time seperately
    function updateProposal(
        uint256 proposalId,
        uint256 autoCloseTime,
        string memory metadataUrl
    ) external metadataCheck(metadataUrl) {
        Proposal memory _proposal = s_proposalMap[proposalId];
        require(
            _proposal.proposer == msg.sender,
            "Only the proposer can update the proposal"
        );
        require(
            _proposal.status == ProposalStatus.Pending,
            "Proposal must be in pending status"
        );
        require(
            autoCloseTime >= _proposal.autoCloseTime + MIN_CLOSE_INC_TIME,
            "Auto close time must be at least 1 day ahead of the existing autoclose"
        );

        _proposal.autoCloseTime = autoCloseTime;
        _proposal.metadataUrl = bytes(metadataUrl);
        s_proposalMap[proposalId] = _proposal;

        emit ProposalUpdated(
            proposalId,
            _proposal.projectId,
            autoCloseTime,
            metadataUrl
        );
    }

    function updateProposalStatus(
        uint256 proposalId,
        ProposalStatus _status
    ) external onlyOwner {
        require(
            proposalId <= s_proposalId && proposalId > 0,
            "Invalid Proposal Id"
        );
        Proposal memory _proposal = s_proposalMap[proposalId];
        require(
            _proposal.status == ProposalStatus.Pending,
            "Proposal must be in pending status"
        );
        _proposal.status = _status;
        s_proposalMap[proposalId] = _proposal;
        emit ProposalStatusUpdated(proposalId, _status);
    }

    function processProposal(
        uint256 proposalId,
        uint256 projectId,
        ProposalStatus status
    ) external onlyExecutor {
        // based on the proposal status, execute movement of funds
    }

    function updateListingAddress(address _newListing) external onlyOwner {
        s_listingContract = _newListing;
    }

    function updateExecutorAddress(address _newExecutor) external onlyOwner {
        s_executorContract = _newExecutor;
    }
}
