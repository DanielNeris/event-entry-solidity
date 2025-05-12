# EventEntry

An on-chain guest-list and check-in system built with Solidity and Hardhat.  
Users can deploy new `EventEntry` contracts, index them in a factory, and allow attendees to check in using off-chain signatures. Owners can toggle event status, enforce capacity and timing, and emit detailed events for off-chain tracking.

---

## Project Structure

| Folder        | Purpose                                                         |
| ------------- | --------------------------------------------------------------- |
| `contracts/`  | Smart contracts (`EventEntry.sol`, `EventEntryFactory.sol`)     |
| `interfaces/` | Public interfaces (`IEventEntry.sol`, `IEventEntryFactory.sol`) |
| `scripts/`    | Deployment & helper scripts                                     |
| `test/`       | Hardhat tests with Chai & solidity-coverage                     |
| `coverage/`   | Coverage reports (`solidity-coverage`)                          |

---

## Smart Contracts

### EventEntry

- **Constructor**

  - `constructor(string name, uint32 eventDate, uint32 maxAttendees)`
  - Reverts `PastEventDate` if `eventDate <= block.timestamp`.
  - Emits `EventCreated(name, eventDate, maxAttendees)`.

- **checkIn(bytes signature)**

  - Verifies EIP-191 message hash and recovers signer.
  - Errors: `InvalidSignatureLength`, `InvalidSignatureV`, `EventInactive`, `EventEnded`, `AlreadyCheckedIn`, `CapacityReached`.
  - Emits `AttendeeCheckedIn(address attendee, uint256 timestamp)` and increments `attendeeCount`.

- **setEventStatus(bool active)**

  - Only owner can pause/unpause check-ins. Emits `EventStatusChanged(active)`.

- **owner()**
  - Returns current owner (transferred by factory).

### EventEntryFactory

- **createEvent(string name, uint32 date, uint32 cap)**

  - Deploys a new `EventEntry`.
  - Transfers ownership to caller.
  - Stores address in `allEvents`.
  - Emits `EventDeployed(address indexed eventAddress, string name, uint32 date, uint32 cap)`.

- **getEventCount() → uint256**
- **getEvent(uint256 index) → address**

  - Reverts `"Factory: index out of range"` if invalid.

- **getAllEvents() → address[]**

---

## Requirements

- Node.js (>= 18.x)
- pnpm (>= 8.x) or npm (>= 9.x)
- Hardhat (>= 2.12.x)

Install dependencies:

```bash
pnpm install
```

---

## Compile Contracts

```bash
pnpm hardhat compile
```

---

## Run Tests & Coverage

```bash
pnpm hardhat test
pnpm hardhat coverage --show-stack-traces
```

---

## Local Development

1. **Start local node**

   ```bash
   pnpm hardhat node
   ```

2. **Deploy to localhost**

   ```bash
   pnpm hardhat run scripts/deploy.js --network localhost
   ```

3. **Open console**

   ```bash
   pnpm hardhat console --network localhost
   ```

4. **Sample interaction**

   ```js
   const [deployer, alice] = await ethers.getSigners();

   // Deploy factory
   const factory = await ethers.getContract("EventEntryFactory");

   // Create event
   await factory.createEvent(
     "My Gala",
     Math.floor(Date.now() / 1000) + 86400, // tomorrow
     100 // max attendees
   );

   const events = await factory.getAllEvents();
   const entryAddr = events[0];
   const eventEntry = await ethers.getContractAt("EventEntry", entryAddr);

   // Sign and check in
   const hash = await eventEntry.getMessageHash(alice.address);
   const sig = await deployer.signMessage(ethers.utils.arrayify(hash));
   await eventEntry.connect(alice).checkIn(sig);
   console.log(
     "Total checked in:",
     (await eventEntry.attendeeCount()).toString()
   );
   ```

---

## Features

- Gas-efficient: immutable state, custom errors.
- Secure: Ownable, CEI pattern, reentrancy-safe.
- Off-chain signatures: no on-chain whitelist.
- Indexed factory: manage multiple events.
- Full test & coverage suite.

---

## License

MIT © 2025 Daniel Neris

---

## Contributions

Pull Requests and Issues are welcome!  
Let’s build the decentralized future together.
