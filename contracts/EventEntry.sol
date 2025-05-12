// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEventEntry} from "./interfaces/IEventEntry.sol";

/**
 * @title EventEntry
 * @author Daniel Neris
 * @notice Minimal on‑chain guest‑list contract secured by an <b>owner‑signed</b> message.
 * @dev    The contract is upgrade‑safe (no self‑destruct, no delegatecall).
 */
contract EventEntry is IEventEntry, Ownable {
    /*───────────────────────────  Storage Layout  ──────────────────────────*/
    string  public eventName;              // Event human‑readable name (UTF‑8)
    uint32  public immutable eventDate;    // Unix timestamp; immutable to freeze schedule
    uint32  public immutable maxAttendees; // Hard cap determined at deployment
    uint32  public attendeeCount;          // Incremented on every successful check‑in
    bool    public isEventActive;          // Toggle‑able by the owner; default: true

    mapping(address => bool) public hasAttended; // O(1) lookup for re‑entrance checks

    /*────────────────────────────  Constructor  ────────────────────────────*/
    /**
     * @param _eventName      Human‑readable event name.
     * @param _eventDateUnix  Future Unix timestamp; must be > block.timestamp.
     * @param _maxAttendees   Hard capacity ( ≤ 4.29 B due to uint32 ).
     */
    constructor(string memory _eventName, uint32 _eventDateUnix, uint32 _maxAttendees)
        Ownable(msg.sender)
    {
        // Prevent deployment with past date (saves wasted deployments).
        if (uint256(_eventDateUnix) <= block.timestamp) revert PastEventDate();

        eventName     = _eventName;
        eventDate     = _eventDateUnix;
        maxAttendees  = _maxAttendees;
        isEventActive = true;

        emit EventCreated(_eventName, _eventDateUnix, _maxAttendees);
    }

    /*──────────────────────────  Admin Function  ───────────────────────────*/
    /**
     * @notice Activate / pause the event (does not change the event date).
     * @param _isActive  True to accept check‑ins, false to block them.
     */
    function setEventStatus(bool _isActive) external onlyOwner {
        isEventActive = _isActive;
        emit EventStatusChanged(_isActive);
    }

    /*────────────────  Off‑chain Signing Helper Functions  ────────────────*/
    /**
     * @notice Computes the hash that must be signed by the organizer off‑chain.
     *         Unique to this contract, the event name and the attendee address.
     */
    function getMessageHash(address _attendee) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), eventName, _attendee));
    }

    /**
     * @dev     Applies the standard Ethereum signed‑message prefix (EIP‑191).
     * @param   _messageHash  32‑byte hash returned by getMessageHash.
     * @return  Prefixed hash that the wallet actually signs.
     */
    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    /*────────────────────  Signature Verification  ───────────────────────*/
    /**
     * @notice Verifies if _signature is a valid owner signature for _attendee.
     * @return True  if the recovered signer equals the owner.
     */
    function verifySignature(address _attendee, bytes memory _signature) public view returns (bool) {
        bytes32 msgHash = getMessageHash(_attendee);
        bytes32 ethHash = getEthSignedMessageHash(msgHash);
        return recoverSigner(ethHash, _signature) == owner();
    }

    /**
     * @dev Recover signer from a 65‑byte ECDSA signature.
     *      Performs minimal malleability checks (v ∈ {27,28}, s not checked).
     */
    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
        public
        pure
        returns (address)
    {
        if (_signature.length != 65) revert InvalidSignatureLength();

        bytes32 r; bytes32 s; uint8 v;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }
        if (v < 27) v += 27;
        if (v != 27 && v != 28) revert InvalidSignatureV();

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    /*───────────────────────────  Main Flow  ──────────────────────────────*/
    /**
     * @notice Public entry‑point for attendees. Requires a valid organizer signature.
     * @dev    Implements the Check‑Effects‑Interaction pattern to guard against
     *         re‑entrancy (even though no external calls with value exist).
     * @param  _signature  65‑byte ECDSA signature produced by the organizer.
     */
    function checkIn(bytes memory _signature) external {
        /*─────────────── Checks ───────────────*/
        if (!isEventActive)                   revert EventInactive();
        if (block.timestamp > uint256(eventDate) + 1 days) revert EventEnded();
        if (hasAttended[msg.sender])         revert AlreadyCheckedIn();
        if (attendeeCount >= maxAttendees)   revert CapacityReached();
        if (!verifySignature(msg.sender, _signature)) revert InvalidSignature();

        /*────────────── Effects ──────────────*/
        hasAttended[msg.sender] = true;      // state change first
        unchecked { ++attendeeCount; }       // safe; cannot overflow uint32 within capacity

        /*─────────── Interaction ────────────*/
        emit AttendeeCheckedIn(msg.sender, uint32(block.timestamp));
    }
}