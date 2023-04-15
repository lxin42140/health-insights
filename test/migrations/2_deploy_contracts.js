const Marketplace = artifacts.require("Marketplace");
const Organization = artifacts.require("Organization");
const Patient = artifacts.require("Patient");
const MedToken = artifacts.require("MedToken");

module.exports = (deployer, network, accounts) => {
    deployer.deploy(Marketplace, 10, 10).then(function () {
        return deployer.deploy(Organization);
    }).then(function () {
        return deployer.deploy(Patient);
    }).then(function () {
        return deployer.deploy(MedToken);
    });
}