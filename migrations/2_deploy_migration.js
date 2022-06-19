const Lottery = artifacts.require("Migrations"); // build 폴더안에있는 migrations 파일의 데이터를 가져옴

module.exports = function(deployer) {
  // deployer가 컨트랙을 배포한다
  deployer.deploy(Lottery); // migrations 폴더의 바이트코드를 가져와서 배포함
};
