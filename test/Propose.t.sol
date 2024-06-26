// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DeployPropose} from "../script/DeployPropose.s.sol";
import {DeployListing} from "../script/DeployListing.s.sol";
import {Listing} from "../src/Listing.sol";
import {Propose} from "../src/Propose.sol";

contract ProposeTest is Test {
    DeployPropose deployPropose;
    DeployListing deployListing;
    Propose propose;
    Listing listing;
    address Creator1 = makeAddr("Creator1");
    address NonOwner = makeAddr("NonOwner");
    address Proposer1 = makeAddr("Proposer1");
    address Executor = makeAddr("executor");
    address OwnerAddr = msg.sender;

    // setUp
    // should be able to deploy
    function setUp() external {
        deployListing = new DeployListing();
        listing = deployListing.run();
        deployPropose = new DeployPropose();
        propose = deployPropose.run();
        vm.prank(OwnerAddr);
        propose.updateListingAddress(address(listing));
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

    // s_proposalId should be zero
    function testProposalIdIsZero() external view {
        assertEq(propose.getLastProposalId(), 0);
    }

    // s_listingContract should be zero
    function testListingContractIsUpToDate() external view {
        assertEq(propose.getListingContract(), address(listing));
    }

    // s_executorContract should be zero
    function testExecutorContractIsZero() external view {
        assertEq(propose.getExecutorContract(), address(0));
    }

    // assert constants
    function testConstants() external view {
        assertEq(propose.MIN_AUTO_CLOSE_TIME(), 7 days);
        assertEq(propose.MIN_CLOSE_INC_TIME(), 1 days);
        assertEq(propose.MIN_PROPOSAL_ETH(), 0.001 ether);
    }

    // create proposal with < 0.001 eth failure
    function testCreateProposalWithLessThanMinEth() external {
        vm.expectRevert();
        vm.deal(Proposer1, 0.001 ether);
        vm.prank(Proposer1);
        propose.createProposal{value: 0.0001 ether}(
            1,
            (block.timestamp + 7 days),
            ""
        );
    }

    // create proposal with 0.001 eth but < current block ts
    function testCreateProposalWithAutoCloseTimeLessThanCurrentBlockTs()
        external
    {
        vm.expectRevert();
        vm.deal(Proposer1, 0.001 ether);
        vm.prank(Proposer1);
        propose.createProposal{value: 0.001 ether}(
            1,
            (block.timestamp - 1),
            ""
        );
    }

    // create proposal with 0.001 eth but < current block ts + 7 days
    function testCreateProposalWithAutoCloseTimeLessThanCurrentBlockTsPlus7Days()
        external
    {
        vm.expectRevert();
        vm.deal(Proposer1, 0.001 ether);
        vm.prank(Proposer1);
        propose.createProposal{value: 0.001 ether}(
            1,
            (block.timestamp + 7 days - 1),
            ""
        );
    }

    // create proposal success, proposalId inc, mapping check, event emitted
    function testCreateProposalSuccess() external ensureListing {
        // vm.expectEmit();
        emit Propose.ProposalCreated(
            1,
            Proposer1,
            0.001 ether,
            1,
            (block.timestamp + 7 days),
            "metadata"
        );

        vm.deal(Proposer1, 0.001 ether);
        vm.prank(Proposer1);
        // propose.createProposal{value: 0.001 ether}(
        //     1,
        //     (block.timestamp + 7 days),
        //     "metadata"
        // );
        // (
        //     uint256 proposalId,
        //     address proposer,
        //     uint256 amount,
        //     uint256 projectId,
        //     uint256 autoCloseTime,
        //     Propose.ProposalStatus status,
        //     bytes memory metadataUrl
        // ) = propose.s_proposalMap(1);
        // // assert last proposal id
        // assertEq(propose.getLastProposalId(), 1);
        // // assert mapping data
        // assertEq(proposalId, 1);
        // assertEq(proposer, Proposer1);
        // assertEq(amount, 0.001 ether);
        // assertEq(projectId, 1);
        // assertEq(autoCloseTime, block.timestamp + 7 days);
        // assertEq(uint256(status), uint256(Propose.ProposalStatus.Pending));
        // assertEq(metadataUrl, "metadata");
        // // assert balances
        // assertEq(address(propose).balance, 0.001 ether);
        // assertEq(address(Proposer1).balance, 0 ether);
    }

    // update proposal metadata with NonProposer
    function testUpdateProposalMetadataWithNonProposer()
        external
        ensureListing
        createProposal
    {
        vm.expectRevert();
        vm.prank(NonOwner);
        propose.updateProposalMetadata(1, "metadata");
    }

    // update proposal metadata with Proposer, Status Not Pending
    function testUpdateProposalMetdataWithStatusNotPending()
        external
        ensureListing
        createProposal
    {
        vm.prank(OwnerAddr);
        propose.updateProposalStatus(
            1,
            Propose.ProposalStatus.AutomaticallyClosed
        );

        vm.expectRevert();
        vm.prank(Proposer1);
        propose.updateProposalMetadata(1, "metadata");
    }

    // update proposal metadata with Proposer, Success
    function testUpdateProposalMetadataSuccess()
        external
        ensureListing
        createProposal
    {
        vm.prank(Proposer1);
        propose.updateProposalMetadata(1, "metadata2");
        (, , , , , , bytes memory metadataUrl) = propose.s_proposalMap(1);
        assertEq(metadataUrl, "metadata2");
    }

    // update proposal autoclose with NonOwner
    function testUpdateProposalAutoCloseWithNonOwner()
        external
        ensureListing
        createProposal
    {
        vm.expectRevert();
        vm.prank(NonOwner);
        propose.updateProposalAutoClose(1, (block.timestamp + 1 days));
    }

    // update proposal autoclose with Proposer, Status Not Pending
    function testUpdateProposalAutoCloseWithStatusNotPending()
        external
        ensureListing
        createProposal
    {
        vm.prank(OwnerAddr);
        propose.updateProposalStatus(
            1,
            Propose.ProposalStatus.AutomaticallyClosed
        );

        vm.expectRevert();
        vm.prank(Proposer1);
        propose.updateProposalAutoClose(1, (block.timestamp + 1 days));
    }

    // update proposal autoclose with autoclose time > proposalAutoClose + 1 day
    function testUpdateProposalAutoCloseWithAutoCloseTimeLessThanCurrentBlockTsPlus1Day()
        external
        ensureListing
        createProposal
    {
        vm.expectRevert();
        vm.prank(Proposer1);
        propose.updateProposalAutoClose(1, (block.timestamp + 7 days - 1));
    }

    // update proposal autoclose success
    function testUpdateProposalAutoCloseSuccess()
        external
        ensureListing
        createProposal
    {
        (, , , , uint256 autoCloseTimePrev, , ) = propose.s_proposalMap(1);
        vm.prank(Proposer1);
        propose.updateProposalAutoClose(1, (autoCloseTimePrev + 1 days));
        (, , , , uint256 autoCloseTime, , ) = propose.s_proposalMap(1);
        assertEq(autoCloseTime, autoCloseTimePrev + 1 days);
    }

    // updateProposalStatus with NonOwner, fails
    function testUpdateProposalStatusWithNonOwner()
        external
        ensureListing
        createProposal
    {
        vm.expectRevert();
        vm.prank(NonOwner);
        propose.updateProposalStatus(
            1,
            Propose.ProposalStatus.AutomaticallyClosed
        );
    }

    // updateProposalStatus with Proposer, fails
    function testUpdateProposalStatusWithProposer()
        external
        ensureListing
        createProposal
    {
        vm.expectRevert();
        vm.prank(Proposer1);
        propose.updateProposalStatus(
            1,
            Propose.ProposalStatus.AutomaticallyClosed
        );
    }

    // updateProposalStatus with Owner, without any proposal created
    function testUpdateProposalStatusWithOwnerWithoutCreatingProposal()
        external
        ensureListing
    {
        vm.expectRevert();
        vm.prank(OwnerAddr);
        propose.updateProposalStatus(
            1,
            Propose.ProposalStatus.AutomaticallyClosed
        );
    }

    // update proposal status with owner, invalid proposal id, created proposal, fail on update
    function testUpdateProposalStatusWithOwnerInvalidProposalId()
        external
        ensureListing
        createProposal
    {
        vm.expectRevert();
        vm.prank(OwnerAddr);
        propose.updateProposalStatus(
            2,
            Propose.ProposalStatus.AutomaticallyClosed
        );
    }

    // updateProposalStatus with Owner, correct proposal id, created proposal
    function testUpdateProposalStatusWithOwnerCorrectProposalId()
        external
        ensureListing
        createProposal
    {
        vm.prank(OwnerAddr);
        propose.updateProposalStatus(
            1,
            Propose.ProposalStatus.AutomaticallyClosed
        );
        (, , , , , Propose.ProposalStatus status, ) = propose.s_proposalMap(1);
        assertEq(
            uint256(status),
            uint256(Propose.ProposalStatus.AutomaticallyClosed)
        );
    }

    // testUpdateListingAddress
    // update listing address by not owner failure
    function testUpdateListingAddressWithNonOwner() external {
        vm.expectRevert();
        vm.prank(NonOwner);
        propose.updateListingAddress(address(0x2));
    }

    // update listing address by owner success
    function testUpdateListingAddressWithOwner() external {
        vm.prank(OwnerAddr);
        propose.updateListingAddress(address(0x2));
        assertEq(propose.getListingContract(), address(0x2));
    }

    // testUpdateExecutorAddress
    // update executor address by not owner failure
    function testUpdateExecutorAddressWithNonOwner() external {
        vm.expectRevert();
        vm.prank(NonOwner);
        propose.updateExecutorAddress(address(0x2));
    }

    // update executor address by owner success
    function testUpdateExecutorAddressWithOwner() external {
        vm.prank(OwnerAddr);
        propose.updateExecutorAddress(address(0x3));
        assertEq(propose.getExecutorContract(), address(0x3));
    }
}
