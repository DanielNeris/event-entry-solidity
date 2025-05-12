// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEventEntry
 * @notice External interface for the EventEntry contract
 */
interface IEventEntry {
    /* ───────────────────────────── Errors ───────────────────────────── */
    error EventInactive();
    error EventEnded();
    error AlreadyCheckedIn();
    error CapacityReached();
    error InvalidSignature();
    error InvalidSignatureLength();
    error InvalidSignatureV();
    error PastEventDate();

    /* ───────────────────────────── Events ───────────────────────────── */
    event EventCreated(string name, uint32 date, uint32 maxAttendees);
    event AttendeeCheckedIn(address indexed attendee, uint32 timestamp);
    event EventStatusChanged(bool isActive);

    /* ────────────────────────── Read Methods ────────────────────────── */
    function eventName() external view returns (string memory);
    function eventDate() external view returns (uint32);
    function maxAttendees() external view returns (uint32);
    function attendeeCount() external view returns (uint32);
    function isEventActive() external view returns (bool);
    function hasAttended(address attendee) external view returns (bool);

    function getMessageHash(address attendee) external view returns (bytes32);
    function getEthSignedMessageHash(bytes32 messageHash) external pure returns (bytes32);
    function verifySignature(address attendee, bytes calldata signature) external view returns (bool);
    function recoverSigner(bytes32 ethSignedMessageHash, bytes calldata signature) external pure returns (address);

    /* ────────────────────────── Write Methods ───────────────────────── */
    function setEventStatus(bool isActive) external;
    function checkIn(bytes calldata signature) external;
}