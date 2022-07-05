const fs = require("fs-extra");
const path = require("path");
const LuckyLotto = artifacts.require("LuckyLotto");

module.exports = (deployer, network, accounts) => {
  deployer.deploy(LuckyLotto);
  fs.writeFileSync(
    `./ContractAddress__${network}.json`,
    `export const ContractAddress = "${LuckyLotto.address}";
export const Network = "${network}";
export const DeployingAddress = "${accounts[0]}";`);
};
