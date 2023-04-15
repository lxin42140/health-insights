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

contract("Organization", function (accounts) {
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

    console.log("Testing organization contract");

    const SEED_ORG = accounts[0]; // HOSPITAL
    const VERIFIED_ORG_1 = accounts[1]; // RESEARCH
    const VERIFIED_ORG_2 = accounts[2]; // Pharmacy,
    const INVALID = accounts[4];

    it("add new organization", async () => {
        truffleAssert.reverts(orgInstance.addNewOrganization(VERIFIED_ORG_1, 0, "singapore", "KK", {
            from: INVALID
        }), "Verified organization only!");

        truffleAssert.reverts(orgInstance.addNewOrganization(SEED_ORG, 0, "singapore", "KK", {
            from: SEED_ORG
        }), "Organization already added!");

        const orgAdded = await orgInstance.addNewOrganization(VERIFIED_ORG_1, 1, "singapore", "TTS")

        truffleAssert.eventEmitted(orgAdded, "OrganizationAdded");

        await orgInstance.addNewOrganization(VERIFIED_ORG_2, 2, "singapore", "KK")
    });


    it("get organization type", async () => {
        const orgType = await orgInstance.getOrganizationType(VERIFIED_ORG_1);
        assert.equal(orgType, 1, "incorrect organization type!");
    });

    it("get organization profile", async () => {
        const profile = await orgInstance.getOrganizationProfile(VERIFIED_ORG_1);

        assert.deepEqual(profile.verifiedBy, SEED_ORG, "incorrect verified by");
        assert.deepEqual(profile.organizationType, 1, "incorrect organization type");
        assert.deepEqual(profile.location, "singapore", "incorrect location");
        assert.deepEqual(profile.organizationName, "TTS", "incorrect organization name");
    });

    it("remove organization profile", async () => {
        await truffleAssert.reverts(orgInstance.removeOrganization(VERIFIED_ORG_1, {
            from: VERIFIED_ORG_2
        }), "Org not eligible to remove organization!");

        const deleteOrg = await orgInstance.removeOrganization(VERIFIED_ORG_1, {
            from: SEED_ORG
        });

        truffleAssert.eventEmitted(deleteOrg, "OrganizationRemoved");
    });

});
