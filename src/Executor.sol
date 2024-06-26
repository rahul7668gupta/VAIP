// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Listing} from "./Listing.sol";
import {Propose} from "./Propose.sol";

contract Execute is Ownable {
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

    // Function to update propose funding contract address, only owner
    function updateProposalContract(address proposalContract) public onlyOwner {
        s_proposalContract = proposalContract;
        propose = Propose(payable(proposalContract));
    }

    // Function to update listing contract address, only owner
    function updateListingContract(address listingContract) public onlyOwner {
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
            address proposer,
            ,
            uint256 projectId,
            uint256 autoCloseTime,
            Propose.ProposalStatus status,

        ) = propose.s_proposalMap(_proposalId);
        require(proposer == msg.sender, "Executor: Caller not proposer");
        require(
            status == Propose.ProposalStatus.Pending,
            "Executor: Proposal not approved"
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
    // add execute autoclose only owner
}
