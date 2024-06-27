// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Listing is Ownable {
    uint256 private s_projectId;
    address private s_proposerContract;
    address private s_executorContract;

    struct Project {
        uint256 projectId;
        address creator;
        bytes metadataUrl;
    }

    mapping(uint256 => Project) public s_projectMap;

    event Listed(
        uint256 indexed projectId,
        address indexed creator,
        string metadataUrl
    );

    event UpdatedMetadata(uint256 indexed projectId, string metadataUrl);

    constructor() Ownable(msg.sender) {}

    function getProposerContract() external view returns (address) {
        return s_proposerContract;
    }

    function getExecutorContract() external view returns (address) {
        return s_executorContract;
    }

    function getLastProjectId() external view returns (uint256) {
        return s_projectId;
    }

    modifier metadataCheck(string memory metadataUrl) {
        require(bytes(metadataUrl).length > 0, "Metadata URL cannot be empty");
        _;
    }

    function list(
        string memory metadataUrl
    ) external metadataCheck(metadataUrl) {
        // increment the project id counter;
        s_projectId++;
        // add a new project to the project mapping
        s_projectMap[s_projectId] = Project(
            s_projectId,
            msg.sender,
            bytes(metadataUrl)
        );
        // emit listed event
        emit Listed(s_projectId, msg.sender, metadataUrl);
    }

    function updateProjectMetdata(
        uint256 projectId,
        string memory metadataUrl
    ) external metadataCheck(metadataUrl) {
        // only project creator allowed
        Project memory _project = s_projectMap[projectId];
        require(msg.sender == _project.creator, "Caller not Creator");
        // update project metadata directly
        _project.metadataUrl = bytes(metadataUrl);
        // update project in the project mapping
        s_projectMap[projectId] = _project;
        // emit update metadata
        emit UpdatedMetadata(projectId, metadataUrl);
    }

    function updateProposerAddress(address _newProposer) external onlyOwner {
        s_proposerContract = _newProposer;
    }

    function updateExecutorAddress(address _newExecutor) external onlyOwner {
        s_executorContract = _newExecutor;
    }

    // implement recieve and fallback funcs
    receive() external payable {
        revert("Listing: Receive: Cannot recieve funds without function call");
    }

    fallback() external payable {
        revert("Listing: Fallback: Cannot recieve funds without function call");
    }
}
