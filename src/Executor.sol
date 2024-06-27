// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Listing} from "./Listing.sol";
import {Propose} from "./Propose.sol";

contract Executor is Ownable {
    address private s_listingContract;
    address private s_proposalContract;

    Listing listing;
    Propose propose;

    constructor(
        address listingContract,
        address proposalContract
    ) Ownable(msg.sender) {
        s_listingContract = listingContract;
        s_proposalContract = proposalContract;
        listing = Listing(payable(listingContract));
        propose = Propose(payable(proposalContract));
    }

    modifier validateProposalId(uint256 proposalId) {
        require(
            proposalId <= propose.getLastProposalId() && proposalId > 0,
            "Invalid Proposal Id"
        );
        _;
    }

    function getListingContract() external view returns (address) {
        return (s_listingContract);
    }

    function getProposalContract() external view returns (address) {
        return s_proposalContract;
    }

    // Function to update propose funding contract address, only owner
    function updateProposerAddress(address proposalContract) public onlyOwner {
        s_proposalContract = proposalContract;
        propose = Propose(payable(proposalContract));
    }

    // Function to update listing contract address, only owner
    function updateListingAddress(address listingContract) public onlyOwner {
        s_listingContract = listingContract;
        listing = Listing(payable(listingContract));
    }

    // call the proposal contract to process funds, by project owner
    function executeProposal(
        uint256 _proposalId,
        Propose.ProposalStatus _status
    ) external validateProposalId(_proposalId) {
        require(
            _status == Propose.ProposalStatus.Approved ||
                _status == Propose.ProposalStatus.Closed,
            "Invalid status"
        );
        (
            uint256 proposalId,
            ,
            ,
            uint256 projectId,
            uint256 autoCloseTime,
            Propose.ProposalStatus status,

        ) = propose.s_proposalMap(_proposalId);
        (, address creator, ) = listing.s_projectMap(projectId);
        require(creator == msg.sender, "Executor: Caller not listing creator");
        require(
            status == Propose.ProposalStatus.Pending,
            "Executor: Proposal has been moved"
        );
        require(
            autoCloseTime > block.timestamp,
            "Proposal auto close time passed"
        );
        uint256 lastProjectId = listing.getLastProjectId();
        require(
            projectId > 0 && projectId <= lastProjectId,
            "Invalid Project Id"
        );
        propose.processFunds(proposalId, projectId, _status);
    }

    // execute autoclose only owner
    function executeAutoClose(
        uint256 _proposalId
    ) external onlyOwner validateProposalId(_proposalId) {
        // get the proposal
        (
            uint256 proposalId,
            ,
            ,
            uint256 projectId,
            uint256 autoCloseTime,
            Propose.ProposalStatus status,

        ) = propose.s_proposalMap(_proposalId);
        // validate proposal is pending
        require(
            status == Propose.ProposalStatus.Pending,
            "Executor: Proposal is not in pending state"
        );
        // validate proposal autoCloseTime < block.timestamp
        require(
            autoCloseTime < block.timestamp,
            "Executor: autoCloseTime has not yet passed"
        );
        // process funds with autoclose status
        propose.processFunds(
            proposalId,
            projectId,
            Propose.ProposalStatus.AutomaticallyClosed
        );
    }

    // implement recieve and fallback funcs
    receive() external payable {
        revert("Cannot recieve funds without function call");
    }

    fallback() external {
        revert("Cannot recieve funds without function call");
    }
}
