// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Listing} from "./Listing.sol";

contract Propose is Ownable {
    uint256 private s_proposalId;
    address private s_listingContract;
    address private s_executorContract;
    Listing public listing;

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

    event ProposalMetadataUpdated(
        uint256 indexed proposalId,
        uint256 indexed projectId,
        string metadataUrl
    );

    event ProposalAutoCloseUpdated(
        uint256 indexed proposalId,
        uint256 indexed projectId,
        uint256 autoCloseTime
    );

    event ProposalStatusUpdated(
        uint256 indexed proposalId,
        ProposalStatus proposalStatus
    );

    event ProposalProcessed(
        uint256 indexed proposalId,
        uint256 indexed projectId,
        ProposalStatus proposalStatus
    );

    constructor(address _listing) Ownable(msg.sender) {
        s_listingContract = _listing;
        listing = Listing(payable(_listing));
    }

    modifier onlyExecutor() {
        require(
            msg.sender == s_executorContract,
            "Only executor contract can call this function"
        );
        _;
    }

    modifier validateProposalId(uint256 proposalId) {
        require(
            proposalId <= s_proposalId && proposalId > 0,
            "Invalid Proposal Id"
        );
        _;
    }

    modifier validateProjectId(uint256 projectId) {
        uint256 lastProjectId = listing.getLastProjectId();
        require(
            projectId > 0 && projectId <= lastProjectId,
            "Invalid Project Id"
        );
        _;
    }

    modifier metadataCheck(string memory metadataUrl) {
        require(bytes(metadataUrl).length > 0, "Metadata URL cannot be empty");
        _;
    }

    function getListingContract() external view returns (address) {
        return (s_listingContract);
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
    ) external payable metadataCheck(metadataUrl) validateProjectId(projectId) {
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

    function updateProposalMetadata(
        uint256 proposalId,
        string memory metadataUrl
    ) external metadataCheck(metadataUrl) validateProposalId(proposalId) {
        Proposal memory _proposal = s_proposalMap[proposalId];
        require(
            _proposal.proposer == msg.sender,
            "Only the proposer can update the proposal"
        );
        require(
            _proposal.status == ProposalStatus.Pending,
            "Proposal must be in pending status"
        );
        _proposal.metadataUrl = bytes(metadataUrl);
        s_proposalMap[proposalId] = _proposal;

        emit ProposalMetadataUpdated(
            proposalId,
            _proposal.projectId,
            metadataUrl
        );
    }

    function updateProposalAutoClose(
        uint256 proposalId,
        uint256 autoCloseTime
    ) external validateProposalId(proposalId) {
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
        s_proposalMap[proposalId] = _proposal;

        emit ProposalAutoCloseUpdated(
            proposalId,
            _proposal.projectId,
            autoCloseTime
        );
    }

    function updateProposalStatus(
        uint256 proposalId,
        ProposalStatus _status
    ) external onlyOwner validateProposalId(proposalId) {
        Proposal memory _proposal = s_proposalMap[proposalId];
        require(
            _proposal.status == ProposalStatus.Pending,
            "Proposal must be in pending status"
        );
        _proposal.status = _status;
        s_proposalMap[proposalId] = _proposal;
        emit ProposalStatusUpdated(proposalId, _status);
    }

    function updateListingAddress(address _newListing) external onlyOwner {
        s_listingContract = _newListing;
        listing = Listing(payable(_newListing));
    }

    function updateExecutorAddress(address _newExecutor) external onlyOwner {
        s_executorContract = _newExecutor;
    }

    function processFunds(
        uint256 proposalId,
        uint256 projectId,
        ProposalStatus status
    )
        external
        onlyExecutor
        validateProposalId(proposalId)
        validateProjectId(projectId)
    {
        // validate proposal id
        // validate project id
        // status should be pending
        Proposal memory _proposal = s_proposalMap[proposalId];
        require(
            _proposal.status == ProposalStatus.Pending,
            "Proposal must be in pending status"
        );

        (, address creator, ) = listing.s_projectMap(projectId);
        // based on the proposal status, execute movement of funds
        if (status == ProposalStatus.Approved) {
            // mark proposal as Approved
            _proposal.status = ProposalStatus.Approved;
            s_proposalMap[proposalId] = _proposal;
            // send funds to project creator
            (bool success, ) = creator.call{value: _proposal.amount}("");
            require(success, "Funds transfer failed");
            // emit proposalProcessed event
            emit ProposalProcessed(
                proposalId,
                projectId,
                ProposalStatus.Approved
            );
        } else if (
            status == ProposalStatus.Closed ||
            status == ProposalStatus.AutomaticallyClosed
        ) {
            // mark proposal as Closed or AutomaticallyClosed
            _proposal.status = status;
            s_proposalMap[proposalId] = _proposal;
            // send funds back to proposer
            (bool success, ) = _proposal.proposer.call{value: _proposal.amount}(
                ""
            );
            require(success, "Funds transfer failed");
            // emit proposalProcessed event
            emit ProposalProcessed(proposalId, projectId, status);
        } else {
            revert("Cannot execute for provided status");
        }
    }

    // implement recieve and fallback funcs
    receive() external payable {
        revert("Cannot recieve funds without function call");
    }

    fallback() external {
        revert("Cannot recieve funds without function call");
    }
}
