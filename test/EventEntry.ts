// SPDX-License-Identifier: MIT
/* eslint-disable camelcase */
import hre from "hardhat";
import { expect } from "chai";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { EventEntry, EventEntry__factory } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("EventEntry", () => {
  type Fixture = {
    entry: EventEntry;
    owner: SignerWithAddress;
    guest1: SignerWithAddress;
    guest2: SignerWithAddress;
    guest3: SignerWithAddress;
    date: number;
  };

  async function deployEntryFixture(): Promise<Fixture> {
    const [owner, guest1, guest2, guest3] = await hre.ethers.getSigners();
    const now = await time.latest();
    const date = now + 2 * 24 * 60 * 60; // +2 days
    const cap = 2;
    const name = "SolidityConf 2025";

    const factory = new EventEntry__factory().connect(owner);
    const entry = await factory.deploy(name, date, cap);
    await entry.waitForDeployment();

    return { entry, owner, guest1, guest2, guest3, date };
  }

  async function signFor(
    entry: EventEntry,
    signer: SignerWithAddress,
    attendee: SignerWithAddress
  ) {
    const hash = await entry.getMessageHash(attendee.address);
    return signer.signMessage(hre.ethers.getBytes(hash));
  }

  it("stores params & emits EventCreated", async () => {
    const [deployer] = await hre.ethers.getSigners();
    const future = (await time.latest()) + 60;
    const factory = new EventEntry__factory().connect(deployer);
    const tx = await factory.deploy("Demo", future, 5);

    await expect(tx.deploymentTransaction())
      .to.emit(await tx.waitForDeployment(), "EventCreated")
      .withArgs("Demo", future, 5);
  });

  it("reverts PastEventDate on past timestamp", async () => {
    const [deployer] = await hre.ethers.getSigners();
    const factory = new EventEntry__factory().connect(deployer);
    await expect(
      factory.deploy("Past", (await time.latest()) - 1, 1)
    ).to.be.revertedWithCustomError(factory, "PastEventDate");
  });

  it("only owner can setEventStatus", async () => {
    const { entry, owner, guest1 } = await loadFixture(deployEntryFixture);
    await expect(entry.connect(owner).setEventStatus(false))
      .to.emit(entry, "EventStatusChanged")
      .withArgs(false);

    await expect(entry.connect(guest1).setEventStatus(false)).to.be.reverted;
  });

  it("verifySignature returns true/false correctly", async () => {
    const { entry, owner, guest1 } = await loadFixture(deployEntryFixture);
    const sig = await signFor(entry, owner, guest1);
    expect(await entry.verifySignature(guest1.address, sig)).to.equal(true);

    // tamper last byte
    const rFirstByte = sig.slice(2, 4);
    const toggled = rFirstByte === "ff" ? "00" : "ff";
    const invalidSig = "0x" + toggled + sig.slice(4);
    expect(await entry.verifySignature(guest1.address, invalidSig)).to.equal(
      false
    );
  });

  it("recoverSigner length & v checks", async () => {
    const { entry } = await loadFixture(deployEntryFixture);
    await expect(
      entry.recoverSigner(hre.ethers.ZeroHash, "0x1234")
    ).to.be.revertedWithCustomError(entry, "InvalidSignatureLength");

    const badV = "0x" + "11".repeat(32) + "22".repeat(32) + "1d";
    await expect(
      entry.recoverSigner(hre.ethers.ZeroHash, badV)
    ).to.be.revertedWithCustomError(entry, "InvalidSignatureV");
  });

  it("guest checks-in successfully", async () => {
    const { entry, owner, guest1 } = await loadFixture(deployEntryFixture);
    const sig = await signFor(entry, owner, guest1);

    await expect(entry.connect(guest1).checkIn(sig))
      .to.emit(entry, "AttendeeCheckedIn")
      .withArgs(guest1.address, anyValue);

    expect(await entry.attendeeCount()).to.equal(1n);
  });

  it("reverts EventInactive", async () => {
    const { entry, owner, guest1 } = await loadFixture(deployEntryFixture);
    await entry.connect(owner).setEventStatus(false);
    await expect(
      entry.connect(guest1).checkIn(await signFor(entry, owner, guest1))
    ).to.be.revertedWithCustomError(entry, "EventInactive");
  });

  it("reverts EventEnded", async () => {
    const { entry, owner, guest1, date } = await loadFixture(
      deployEntryFixture
    );
    await time.increaseTo(date + 2 * 24 * 60 * 60);
    await expect(
      entry.connect(guest1).checkIn(await signFor(entry, owner, guest1))
    ).to.be.revertedWithCustomError(entry, "EventEnded");
  });

  it("reverts AlreadyCheckedIn & CapacityReached", async () => {
    const { entry, owner, guest1, guest2, guest3 } = await loadFixture(
      deployEntryFixture
    );

    // first check-in
    await entry.connect(guest1).checkIn(await signFor(entry, owner, guest1));
    await expect(
      entry.connect(guest1).checkIn(await signFor(entry, owner, guest1))
    ).to.be.revertedWithCustomError(entry, "AlreadyCheckedIn");

    // capacity reached on second
    await entry.connect(guest2).checkIn(await signFor(entry, owner, guest2));
    await expect(
      entry.connect(guest3).checkIn(await signFor(entry, owner, guest3))
    ).to.be.revertedWithCustomError(entry, "CapacityReached");
  });

  it("reverts InvalidSignatureV for garbage", async () => {
    const { entry, guest1 } = await loadFixture(deployEntryFixture);
    const bad = "0x" + "aa".repeat(65);
    await expect(
      entry.connect(guest1).checkIn(bad)
    ).to.be.revertedWithCustomError(entry, "InvalidSignatureV");
  });
});
