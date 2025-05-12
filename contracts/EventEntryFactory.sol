// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EventEntry.sol";
import "./interfaces/IEventEntryFactory.sol";

/// @title EventEntryFactory
/// @notice Deploys and indexes multiple EventEntry contracts (one per guest-list)
contract EventEntryFactory is IEventEntryFactory {
    /*────────────────── State ──────────────────*/
    address[] public allEvents;   // dynamic array of every deployed EventEntry

    /*───────────────── Create ──────────────────*/
    /// @inheritdoc IEventEntryFactory
    function createEvent(
        string calldata  name_,
        uint32           eventDate_,     // must be > block.timestamp (checked in constructor)
        uint32           maxAttendees_
    ) external returns (address eventAddress)
    {
        // 1. Deploy a fresh EventEntry.
        EventEntry newEvent = new EventEntry(
            name_,
            eventDate_,
            maxAttendees_
        );

        // 2. Transfer ownership to the caller (factory is initial owner).
        newEvent.transferOwnership(msg.sender);

        // 3. Book-keeping.
        eventAddress = address(newEvent);
        allEvents.push(eventAddress);

        emit EventDeployed(eventAddress, name_, eventDate_, maxAttendees_);
    }

    /*────────────────── Reads ──────────────────*/
    /// @inheritdoc IEventEntryFactory
    function getEventCount() external view returns (uint256) {
        return allEvents.length;
    }

    /// @inheritdoc IEventEntryFactory
    function getEvent(uint256 index) external view returns (address) {
        require(index < allEvents.length, "Factory: index out of range");
        return allEvents[index];
    }

    /// @inheritdoc IEventEntryFactory
    function getAllEvents() external view returns (address[] memory) {
        return allEvents;
    }
}
