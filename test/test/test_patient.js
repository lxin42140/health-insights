const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions"); // npm truffle-assertions
const BigNumber = require("bignumber.js"); // npm install bignumber.js
var assert = require("assert");

var Marketplace = artifacts.require("../contracts/Marketplace.sol");
var Organization = artifacts.require("../contracts/Organization.sol");
var Patient = artifacts.require("../contracts/Patient.sol");
var MedToken = artifacts.require("../contracts/MedToken.sol");
var MedicalRecord = artifacts.require("../contracts/MedicalRecord.sol");

const oneEth = new BigNumber(1000000000000000000); // 1 eth

// =============================     Useful concepts       =============================:
// To get the Eth Account Balance = new BigNumber(await web3.eth.getBalance(accounts[1]));
// Get Latest Dice ID => (await diceInstance.getLatestDiceId()).toNumber() => becomes 1,2,3...
// Calculations with bignumer.js: oneEth.dividedBy(2), oneEth.multipliedBy(10) etc..
// Address of contracts in truffle can be obtain with: diceCasinoInstance.address
// =============================     Useful concepts       =============================:

contract("Patient", function (accounts) {
    before(async () => {
        marketplaceInstance = await Marketplace.deployed();
        medTokenInstance = await MedToken.deployed();
        patientInstance = await Patient.deployed();
        orgInstance = await Organization.deployed();

        // set up marketplace dependency
        await marketplaceInstance.setOrganization(orgInstance.address);
        await marketplaceInstance.setPatient(patientInstance.address);
        await marketplaceInstance.setMedToken(medTokenInstance.address);

        // set up token dependency
        // await medTokenInstance.setOrganization(orgInstance.address);
        // await medTokenInstance.setPatient(patientInstance.address);
        await medTokenInstance.setMarketplace(marketplaceInstance.address);

        // set up org dependency
        await orgInstance.setPatient(patientInstance.address);
        await orgInstance.setMarketplace(marketplaceInstance.address);

        // set up patient dependency
        await patientInstance.setMarketplace(marketplaceInstance.address);
        await patientInstance.setOrganization(orgInstance.address);
    });

    console.log("Testing patient contract");

    it("add new patient", async () => {
        await truffleAssert.reverts(patientInstance.addNewPatient(accounts[1], 10, "male", "singapore", {
            from: accounts[2],
        }), "Verified organization only");

        const patientAdded = await patientInstance.addNewPatient(accounts[1], 10, "male", "singapore", {
            from: accounts[0],
        });

        truffleAssert.eventEmitted(patientAdded, "PatientAdded");
    });


    it("retrieve new patient", async () => {
        await patientInstance.getPatientProfile(accounts[1], {
            from: accounts[0],
        });

        await patientInstance.getPatientProfile(accounts[1], {
            from: marketplaceInstance.address,
        });

        const profile = await patientInstance.getPatientProfile(accounts[1], {
            from: accounts[1],
        });

        assert.deepEqual(profile.issuedBy, accounts[0], "Wrong issued by address");
        assert.deepEqual(profile.patientAddress, accounts[1], "Wrong patient address");
        assert.deepEqual(profile.age, 10, "Wrong patient age");
        assert.deepEqual(profile.gender, "male", "Wrong patient gender");
        assert.deepEqual(profile.country, "singapore", "Wrong patient country");

        await truffleAssert.reverts(patientInstance.getPatientProfile(accounts[1], {
            from: accounts[2],
        }), "Only patient, issued by organization and marketplace can access");

    });

    it("add medical records", async () => {
        await truffleAssert.reverts(patientInstance.addNewMedicalRecord(
            accounts[0],
            accounts[1],
            0,
            "www.file.com",
            {
                from: accounts[3]
            }
        ), "Only patient and verified organization can add records");

        await truffleAssert.reverts(patientInstance.addNewMedicalRecord(
            accounts[1],
            accounts[1],
            0,
            "www.file.com",
            {
                from: accounts[0]
            }
        ), "Associated org must be same");

        await truffleAssert.reverts(patientInstance.addNewMedicalRecord(
            accounts[0],
            accounts[2],
            0,
            "www.file.com",
            {
                from: accounts[0]
            }
        ), "Associated user is not patient");

        await truffleAssert.reverts(patientInstance.addNewMedicalRecord(
            accounts[0],
            accounts[2],
            0,
            "www.file.com",
            {
                from: accounts[1]
            }
        ), "Associated patient must be same");

        await truffleAssert.reverts(patientInstance.addNewMedicalRecord(
            accounts[1],
            accounts[1],
            0,
            "www.file.com",
            {
                from: accounts[1]
            }
        ), "Associated org is not verified");

        const medicalRecordAddress = await patientInstance.addNewMedicalRecord(
            accounts[0],
            accounts[1],
            0,
            "www.file.com",
            {
                from: accounts[0]
            }
        )

        truffleAssert.eventEmitted(medicalRecordAddress, "MedicalRecordAdded");
    });

    it("retrieve all patient medical records", async () => {
        const allMedicalRecords = await patientInstance.getMedicalRecords.call(accounts[1],
            [],
            {
                from: accounts[0]
            });

        assert.equal(allMedicalRecords.length, 1, "Medical record count is wrong");
    })

    it("filter medical records", async () => {
        const matchingRecords = await patientInstance.getMedicalRecords.call(
            accounts[1],
            [0],
            {
                from: accounts[0]
            });

        assert.equal(matchingRecords.length, 1, "Filtered medical record count is wrong");


        const noRecords = await patientInstance.getMedicalRecords.call(
            accounts[1],
            [1],
            {
                from: accounts[0]
            });

        assert.equal(noRecords.length, 0, "Filtered medical record count is wrong");
    })

    it("remove existing patient", async () => {
        assert.equal(await patientInstance.isPatient(accounts[1]), true, "User should be patient");

        await truffleAssert.reverts(patientInstance.removePatient(
            accounts[1],
            {
                from: accounts[2]
            }
        ), "User cannot remove patient!");

        const removedPatient = await patientInstance.removePatient(
            accounts[1],
            {
                from: accounts[0]
            }
        )

        truffleAssert.eventEmitted(removedPatient, "PatientRemoved");

        assert.equal(await patientInstance.isPatient(accounts[1]), false, "User should be deleted from patient");
    });

});
