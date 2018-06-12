var Migrations = artifacts.require("./Migrations.sol");
var ColdStaking = artifacts.require('./ColdStaking.sol');

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(ColdStaking);
};
