// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DeployListing} from "../script/DeployListing.s.sol";
import {Listing} from "../src/Listing.sol";

contract ListingTest is Test {
    DeployListing deployListing;
    Listing listing;
    address NonOwner = makeAddr("NonOwner");
    address Creator1 = makeAddr("Creator1");

    //setup
    // should be able to deploy listing
    function setUp() external {
        deployListing = new DeployListing();
        listing = deployListing.run();
    }

    // s_proposerContract should be zero
    function testProposerContractIsZero() external view {
        assertEq(listing.getProposerContract(), address(0));
    }

    // s_executorContract should be zero
    function testExecutorContractIsZero() external view {
        assertEq(listing.getExecutorContract(), address(0));
    }

    // s_projectId should be zero
    function testProjectIdIsZero() external view {
        assertEq(listing.getLastProjectId(), 0);
    }

    // owner should be msg.sender
    function testOwnerIsMsgSender() external view {
        assertEq(listing.owner(), msg.sender);
    }

    // update proposer address by not owner failure
    function testUpdateProposerWithNonOwner() external {
        vm.expectRevert();
        vm.prank(NonOwner);
        listing.updateProposerAddress(address(0x2));
    }

    // update proposer address by owner success
    function testUpdateProposerWithOwner() external {
        vm.prank(msg.sender);
        listing.updateProposerAddress(address(0x2));
        assertEq(listing.getProposerContract(), address(0x2));
    }

    // update executor address by not owner failure
    function testUpdateExecutorWithNonOwner() external {
        vm.expectRevert();
        vm.prank(NonOwner);
        listing.updateExecutorAddress(address(0x2));
    }

    // update executor address by owner success
    function testUpdateExecutorWithOwner() external {
        vm.prank(msg.sender);
        listing.updateExecutorAddress(address(0x3));
        assertEq(listing.getExecutorContract(), address(0x3));
    }

    // list fails when metadata is empty
    function testListFailWhenMetadataIsEmptyString() external {
        vm.expectRevert();
        vm.prank(Creator1);
        listing.list("");
    }

    // list success, mapping and counter is 1, event is emitted
    function testListSuccess() external {
        // assert event is emitted
        vm.expectEmit();
        emit Listing.Listed(1, Creator1, "metadata");

        vm.prank(Creator1);
        listing.list("metadata");

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

    // update project metadata by non-creator failure
    function testUpdateProjectMetadataByNonCreator() external {
        vm.expectRevert();
        vm.prank(NonOwner);
        listing.updateProjectMetdata(1, "metadata");
    }

    // update project metadata by creator success
    function testUpdateProjectMetadataByCreator() external {
        vm.startPrank(Creator1);
        listing.list("metadata");

        listing.updateProjectMetdata(1, "metadata1");
        (
            uint256 _projectId,
            address _creator,
            bytes memory _metadataUrl
        ) = listing.s_projectMap(1);
        vm.stopPrank();

        assertEq(_projectId, 1);
        assertEq(_creator, Creator1);
        assertEq(string(_metadataUrl), "metadata1");
    }

    // test send eth to listing contract, should revert
    function testSendEthToContract() external {
        vm.expectRevert();
        vm.deal(address(this), 2 ether);
        payable(address(listing)).transfer(1 ether);
    }

    // test send eth to fallback function with incorrect function call, should revert
    function testSendEthToContractFallback() external {
        vm.expectRevert();
        vm.deal(address(this), 2 ether);
        vm.prank(address(this));
        payable(address(listing)).call{value: 1 ether}("abc(uint256)");
    }
}
