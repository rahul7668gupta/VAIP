// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DeployPropose} from "../script/DeployPropose.s.sol";
import {DeployListing} from "../script/DeployListing.s.sol";
import {DeployExecutor} from "../script/DeployExecutor.s.sol";
import {Listing} from "../src/Listing.sol";
import {Propose} from "../src/Propose.sol";
import {Executor} from "../src/Executor.sol";

contract ExecuteTest is Test {
    DeployPropose deployPropose;
    DeployListing deployListing;
    DeployExecutor deployExecutor;
    Propose propose;
    Listing listing;
    Executor executor;
    address Creator1 = makeAddr("Creator1");
    address NonOwner = makeAddr("NonOwner");
    address Proposer1 = makeAddr("Proposer1");
    address Executor1 = makeAddr("executor1");
    address OwnerAddr = msg.sender;

    // setUp
    // should be able to deploy
    function setUp() external {
        deployListing = new DeployListing();
        listing = deployListing.run();
        deployPropose = new DeployPropose();
        propose = deployPropose.run(address(listing));
        deployExecutor = new DeployExecutor();
        executor = deployExecutor.run(address(listing), address(propose));
        vm.startPrank(OwnerAddr);
        listing.updateExecutorAddress(address(executor));
        listing.updateProposerAddress(address(propose));
        propose.updateListingAddress(address(listing));
        propose.updateExecutorAddress(address(executor));
        executor.updateListingAddress(address(listing));
        executor.updateProposerAddress(address(propose));
        vm.stopPrank();
    }

    modifier ensureListing() {
        vm.prank(Creator1);
        listing.list("metadata");
        _;
    }

    modifier createProposal() {
        vm.deal(Proposer1, 0.001 ether);
        vm.prank(Proposer1);
        propose.createProposal{value: 0.001 ether}(
            1,
            (block.timestamp + 7 days),
            "metadata"
        );
        _;
    }

    function assertlListSuccess() private view {
        assertEq(listing.getLastProjectId(), 1);
        (
            uint256 _projectId,
            address _creator,
            bytes memory _metadataUrl
        ) = listing.s_projectMap(1);
        assertEq(_projectId, 1);
        assertEq(_creator, Creator1);
        assertEq(_metadataUrl, bytes("metadata"));
    }

    function assertCreateProposalSuccess() private view {
        (
            uint256 proposalId,
            address proposer,
            uint256 amount,
            uint256 projectId,
            uint256 autoCloseTime,
            Propose.ProposalStatus status,
            bytes memory metadataUrl
        ) = propose.s_proposalMap(1);
        // assert last proposal id
        assertEq(propose.getLastProposalId(), 1);
        // assert mapping data
        assertEq(proposalId, 1);
        assertEq(proposer, Proposer1);
        assertEq(amount, 0.001 ether);
        assertEq(projectId, 1);
        assertEq(autoCloseTime, block.timestamp + 7 days);
        assertEq(uint256(status), uint256(Propose.ProposalStatus.Pending));
        assertEq(metadataUrl, "metadata");
        // assert balances
        assertEq(address(propose).balance, 0.001 ether);
        assertEq(address(Proposer1).balance, 0 ether);
    }

    function assertProposalExecuteSuccess(
        Propose.ProposalStatus _expectedStatus,
        uint256 _proposerBalance,
        uint256 _creatorBalance
    ) private view {
        (
            uint256 proposalId,
            address proposer,
            uint256 amount,
            uint256 projectId,
            uint256 autoCloseTime,
            Propose.ProposalStatus status,
            bytes memory metadataUrl
        ) = propose.s_proposalMap(1);
        // assert last proposal id
        assertEq(propose.getLastProposalId(), 1);
        // assert mapping data
        assertEq(proposalId, 1);
        assertEq(proposer, Proposer1);
        assertEq(amount, 0.001 ether);
        assertEq(projectId, 1);
        assertEq(autoCloseTime, block.timestamp + 7 days);
        assertEq(uint256(status), uint256(_expectedStatus));
        assertEq(metadataUrl, "metadata");
        // assert balances
        assertEq(address(propose).balance, 0 ether);
        assertEq(address(Proposer1).balance, _proposerBalance);
        assertEq(address(Creator1).balance, _creatorBalance);
    }

    function assertAutoCloseSuccess(
        uint256 _proposerBalance,
        uint256 _creatorBalance
    ) private view {
        (
            uint256 proposalId,
            address proposer,
            uint256 amount,
            uint256 projectId,
            uint256 autoCloseTime,
            Propose.ProposalStatus status,
            bytes memory metadataUrl
        ) = propose.s_proposalMap(1);
        // assert last proposal id
        assertEq(propose.getLastProposalId(), 1);
        // assert mapping data
        assertEq(proposalId, 1);
        assertEq(proposer, Proposer1);
        assertEq(amount, 0.001 ether);
        assertEq(projectId, 1);
        assertLt(autoCloseTime, block.timestamp);
        assertEq(
            uint256(status),
            uint256(Propose.ProposalStatus.AutomaticallyClosed)
        );
        assertEq(metadataUrl, "metadata");
        // assert balances
        assertEq(address(propose).balance, 0 ether);
        assertEq(address(Proposer1).balance, _proposerBalance);
        assertEq(address(Creator1).balance, _creatorBalance);
    }

    function assertAutoCloseFailure(
        uint256 _proposeContractBalance,
        Propose.ProposalStatus _status,
        uint256 _proposerBalance,
        uint256 _creatorBalance,
        bool _autoCloseBefore
    ) private view {
        (
            uint256 proposalId,
            address proposer,
            uint256 amount,
            uint256 projectId,
            uint256 autoCloseTime,
            Propose.ProposalStatus status,
            bytes memory metadataUrl
        ) = propose.s_proposalMap(1);
        // assert last proposal id
        assertEq(propose.getLastProposalId(), 1);
        // assert mapping data
        assertEq(proposalId, 1);
        assertEq(proposer, Proposer1);
        assertEq(amount, 0.001 ether);
        assertEq(projectId, 1);
        if (_autoCloseBefore) {
            assertGt(autoCloseTime, block.timestamp);
        } else {
            assertLt(autoCloseTime, block.timestamp);
        }
        assertEq(uint256(status), uint256(_status));
        assertEq(metadataUrl, "metadata");
        // assert balances
        assertEq(address(propose).balance, _proposeContractBalance);
        assertEq(address(Proposer1).balance, _proposerBalance);
        assertEq(address(Creator1).balance, _creatorBalance);
    }

    // ensureListing, createProposal, executeProposal with Approved
    // should be able to execute proposal
    function testExecuteProposalApproveSucessWithApproved()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.prank(Creator1);
        executor.executeProposal(1, Propose.ProposalStatus.Approved);
        // assert mapping data
        assertProposalExecuteSuccess(
            Propose.ProposalStatus.Approved,
            0 ether,
            0.001 ether
        );
    }

    function testExecuteProposalApproveSucessWithClosed()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.prank(Creator1);
        executor.executeProposal(1, Propose.ProposalStatus.Closed);
        // assert mapping data
        assertProposalExecuteSuccess(
            Propose.ProposalStatus.Closed,
            0.001 ether,
            0 ether
        );
    }

    function testExecuteProposalApproveSucessWithAutClose()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.expectRevert();
        vm.prank(Creator1);
        executor.executeProposal(1, Propose.ProposalStatus.AutomaticallyClosed);
    }

    function testExecuteProposalApproveSucessWithPending()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.expectRevert();
        vm.prank(Creator1);
        executor.executeProposal(1, Propose.ProposalStatus.Pending);
    }

    // call executeProposal with invalid proposal id
    function testExecuteProposalWithInvalidProposalId()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.expectRevert();
        vm.prank(Creator1);
        executor.executeProposal(2, Propose.ProposalStatus.Approved);
    }

    // call executeProposal with valid proposal id, non project creator
    function testExecuteProposalWithValidProposalIdNonOwner()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.expectRevert();
        vm.prank(NonOwner);
        executor.executeProposal(1, Propose.ProposalStatus.Approved);
    }

    // call execute proposal when proposal status closed
    function testExecuteProposalWhenProposalIsAlreadyClosed()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.prank(Creator1);
        executor.executeProposal(1, Propose.ProposalStatus.Closed);

        vm.expectRevert();
        vm.prank(Creator1);
        executor.executeProposal(1, Propose.ProposalStatus.Approved);
    }

    // call execute proposal with execution after autoCloseTime
    function testExecuteProposalAfterAutoCloseTimeExceeded()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.expectRevert();
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(Creator1);
        executor.executeProposal(1, Propose.ProposalStatus.Approved);
    }

    // execute auto close with owner after autoclose time has passed
    function testExecuteAutoCloseWithOwner()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(OwnerAddr);
        executor.executeAutoClose(1);
        assertAutoCloseSuccess(0.001 ether, 0 ether);
    }

    // execute autoclose with non owner
    function testExecuteAutoCloseWithNonOwner()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.warp(block.timestamp + 7 days + 1);

        vm.expectRevert();
        vm.prank(NonOwner);
        executor.executeAutoClose(1);
        assertAutoCloseFailure(
            0.001 ether,
            Propose.ProposalStatus.Pending,
            0,
            0,
            false
        );
    }

    // execute autoclose with owner, invalid proposal id
    function testExecuteAutoCloseWithOwnerInvalidProposalId()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.warp(block.timestamp + 7 days + 1);
        vm.expectRevert();
        vm.prank(OwnerAddr);
        executor.executeAutoClose(2);
        assertAutoCloseFailure(
            0.001 ether,
            Propose.ProposalStatus.Pending,
            0,
            0,
            false
        );
    }

    // execute autoclose with owner, closed status
    function testExecuteAutoCloseWithOwnerClosedStatus()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        // execute Proposal
        vm.prank(Creator1);
        executor.executeProposal(1, Propose.ProposalStatus.Closed);
        assertProposalExecuteSuccess(
            Propose.ProposalStatus.Closed,
            0.001 ether,
            0 ether
        );
        // try to auto close after proposal is closed
        vm.warp(block.timestamp + 7 days + 1);
        vm.expectRevert();
        vm.prank(OwnerAddr);
        executor.executeAutoClose(1);
        assertAutoCloseFailure(
            0 ether,
            Propose.ProposalStatus.Closed,
            0.001 ether,
            0,
            false
        );
    }

    // execute autoclose with owner, before autoCloseTime
    function testExecuteAutoCloseWithOwnerBeforeAutoCloseTime()
        external
        ensureListing
        createProposal
    {
        assertlListSuccess();
        assertCreateProposalSuccess();
        vm.warp(block.timestamp - 1);
        vm.expectRevert();
        vm.prank(OwnerAddr);
        executor.executeAutoClose(1);
        assertAutoCloseFailure(
            0.001 ether,
            Propose.ProposalStatus.Pending,
            0,
            0,
            true
        );
    }

    // testupdateProposerAddress
    // update executor address by not owner failure
    function testupdateProposerAddressWithNonOwner() external {
        vm.expectRevert();
        vm.prank(NonOwner);
        executor.updateProposerAddress(address(0x2));
    }

    // update executor address by owner success
    function testupdateProposerAddressWithOwner() external {
        vm.prank(OwnerAddr);
        executor.updateProposerAddress(address(0x3));
        assertEq(executor.getProposalContract(), address(0x3));
    }

    // testUpdateListingAddress
    // update listing address by not owner failure
    function testUpdateListingAddressWithNonOwner() external {
        vm.expectRevert();
        vm.prank(NonOwner);
        executor.updateListingAddress(address(0x2));
    }

    // update listing address by owner success
    function testUpdateListingAddressWithOwner() external {
        vm.prank(OwnerAddr);
        executor.updateListingAddress(address(0x2));
        assertEq(executor.getListingContract(), address(0x2));
    }

    // test send eth to propose contract, should revert
    function testSendEthToContract() external {
        vm.expectRevert();
        vm.deal(address(this), 2 ether);
        payable(address(propose)).transfer(1 ether);
    }

    // test send eth to fallback function with incorrect function call, should revert
    function testSendEthToContractFallback() external {
        vm.expectRevert();
        vm.deal(address(this), 2 ether);
        vm.prank(address(this));
        payable(address(propose)).call{value: 1 ether}("abc(uint256)");
    }
}
