// SPDX-License-Identifier: MIT
import hre from "hardhat";
import { expect } from "chai";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import {
  EventEntryFactory,
  EventEntryFactory__factory,
  EventEntry,
  EventEntry__factory,
} from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("EventEntryFactory", () => {
  // Deploy the factory
  async function deployFactoryFixture() {
    const [deployer, organizer, guest] =
      (await hre.ethers.getSigners()) as SignerWithAddress[];
    const factory = await new EventEntryFactory__factory()
      .connect(deployer)
      .deploy();
    await factory.waitForDeployment();
    return { factory, deployer, organizer, guest };
  }

  // Helper to create a child EventEntry via factory
  async function createEvent(
    factory: EventEntryFactory,
    organizer: SignerWithAddress
  ) {
    const now = await time.latest();
    const date = now + 3 * 24 * 60 * 60;
    const cap = 5;
    const name = "Hardhat Fest";

    const tx = await factory.connect(organizer).createEvent(name, date, cap);
    const receipt = await tx.wait();
    const log = receipt.logs.find((l) => l.eventName === "EventDeployed");
    if (!log || !log.args) throw new Error("EventDeployed log missing");
    const addr = log.args.eventAddress as string;
    const entry = (await hre.ethers.getContractAt(
      "EventEntry",
      addr
    )) as EventEntry;
    return { entry, addr };
  }

  it("deploys & indexes events", async () => {
    const { factory, organizer } = await loadFixture(deployFactoryFixture);
    const { addr } = await createEvent(factory, organizer);

    expect(await factory.getEventCount()).to.equal(1n);
    // use getAllEvents() instead of getEvent(index)
    const all = await factory.getAllEvents();
    expect(all).to.have.lengthOf(1);
    expect(all[0]).to.equal(addr);
  });

  it("transfers ownership to organizer", async () => {
    const { factory, organizer } = await loadFixture(deployFactoryFixture);
    const { entry } = await createEvent(factory, organizer);
    expect(await entry.owner()).to.equal(organizer.address);
  });

  it("bubbles PastEventDate from child constructor", async () => {
    const { factory, organizer } = await loadFixture(deployFactoryFixture);
    const entryFactory = new EventEntry__factory(); // for error typing
    await expect(
      factory
        .connect(organizer)
        .createEvent("Past", (await time.latest()) - 1, 1)
    ).to.be.revertedWithCustomError(entryFactory, "PastEventDate");
  });

  it("new event fully functional", async () => {
    const { factory, organizer, guest } = await loadFixture(
      deployFactoryFixture
    );
    const { entry } = await createEvent(factory, organizer);

    // Sign with organizer
    const hash = await entry.getMessageHash(guest.address);
    const sig = await organizer.signMessage(hre.ethers.getBytes(hash));

    await expect(entry.connect(guest).checkIn(sig))
      .to.emit(entry, "AttendeeCheckedIn")
      .withArgs(guest.address, anyValue);
  });
});
