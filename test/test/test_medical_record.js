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

contract("MedicalRecord", function (accounts) {
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

    console.log("Testing MedicalRecord contracts");

    const SEED_ORG = accounts[0]; // HOSPITAL
    const VERIFIED_ORG_1 = accounts[1]; // RESEARCH
    const VERIFIED_ORG_2 = accounts[2]; // Pharmacy,
    const PATIENT = accounts[3];
    const INVALID = accounts[4];

    it("set up", async () => {
        // add new org
        await orgInstance.addNewOrganization(VERIFIED_ORG_1, 1, "Singapore", "TTS")
        await orgInstance.addNewOrganization(VERIFIED_ORG_2, 2, "Singapore", "KK")

        // add new patient
        await patientInstance.addNewPatient(PATIENT, 10, "male", "singapore", {
            from: VERIFIED_ORG_1,
        });
    });

    it("add and access new medical record", async () => {
        const result = await patientInstance.addNewMedicalRecord(
            SEED_ORG,
            PATIENT,
            0,
            "www.0.com",
            {
                from: SEED_ORG
            }
        )

        // get record address from event log
        const recordAddress = result.logs[0].args.medicalRecord;
        // get created medical record
        const medicalRecordInstance = await MedicalRecord.at(recordAddress);

        const data = await medicalRecordInstance.getMetadata();

        assert.deepEqual(data.patient, PATIENT, "owner incorrect");
        assert.deepEqual(data.issuedBy, SEED_ORG, "issued by org incorrect");
        assert.deepEqual(data.record, recordAddress, "record address incorrect");
        assert.deepEqual(data.recordType, 0, "record type incorrect");
        assert.deepEqual(data.uri, "www.0.com", "file pointer incorrect");
    })

    it("toggle record validity", async () => {
        const result = await patientInstance.addNewMedicalRecord(
            SEED_ORG,
            PATIENT,
            0,
            "www.0.com",
            {
                from: SEED_ORG
            }
        )

        // get record address from event log
        const recordAddress = result.logs[0].args.medicalRecord;
        // get created medical record
        const medicalRecordInstance = await MedicalRecord.at(recordAddress);

        await truffleAssert.reverts(medicalRecordInstance.toggleValidity({
            from: PATIENT
        }), "Organization that issued the record only!");

        await medicalRecordInstance.toggleValidity({
            from: SEED_ORG
        });

        await truffleAssert.reverts(medicalRecordInstance.getMetadata(), "Record invalid!");

        await medicalRecordInstance.toggleValidity({
            from: SEED_ORG
        });

        await medicalRecordInstance.getMetadata();
    })

    it("toggle record access", async () => {
        const result = await patientInstance.addNewMedicalRecord(
            SEED_ORG,
            PATIENT,
            0,
            "www.0.com",
            {
                from: SEED_ORG
            }
        )

        // get record address from event log
        const recordAddress = result.logs[0].args.medicalRecord;
        // get created medical record
        const medicalRecordInstance = await MedicalRecord.at(recordAddress);

        await truffleAssert.reverts(medicalRecordInstance.toggleContractStopped({
            from: SEED_ORG
        }), "Owner only!");

        await medicalRecordInstance.toggleContractStopped({
            from: PATIENT
        });

        await truffleAssert.reverts(medicalRecordInstance.getMetadata(), "Record access stopped!");

        await medicalRecordInstance.toggleContractStopped({
            from: PATIENT
        });

        await medicalRecordInstance.getMetadata();
    })

});
