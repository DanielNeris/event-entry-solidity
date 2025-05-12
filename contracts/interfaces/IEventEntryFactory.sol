// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice External interface for the EventEntry factory
interface IEventEntryFactory {
    /// Emitted every time a new EventEntry is deployed.
    event EventDeployed(
        address indexed eventAddress,
        string  name,
        uint32  date,
        uint32  maxAttendees
    );

    /* ─────────────  Write  ───────────── */
    function createEvent(
        string calldata  name_,
        uint32           eventDate_,
        uint32           maxAttendees_
    ) external returns (address eventAddress);

    /* ─────────────  Reads  ───────────── */
    function getEventCount() external view returns (uint256);
    function getEvent(uint256 index) external view returns (address);
    function getAllEvents() external view returns (address[] memory);
}
