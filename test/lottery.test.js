const Lottery = artifacts.require("Lottery");
const assertRevert = require("./asserRevert"); // revert로 인해서 예외발생하면 catch해주기
const expectEvent = require("./expectEvent");

// mocha를 사용하여 컨트랙트에서 구현한 함수들이 정상적으로 동작하는지를 테스트한다
contract("Lottery", ([deployer, user1, user2]) => {
  // 인자로 들어간 배열은 ganache-cli에서 만들어진 계정 10개가 순서대로 들어간다.
  let lottery;
  let betAmount = 5 * 10 ** 15;
  let BET_BLOCK_INTERVAL = 3;
  beforeEach(async () => {
    console.log("Before each");
    lottery = await Lottery.new(); //컨트랙 배포, migration.js에서 배포한것과 별개다
  });

  // it("Basic test", async () => {
  //   console.log("Basic test");
  //   let owner = await lottery.owner();
  //   let value = await lottery.getSomeValue();
  //
  //   console.log("owner: " + owner);
  //   console.log("value: " + value);
  //   assert.equal(owner, "0xF76c9B7012c0A3870801eaAddB93B6352c8893DB");
  //   assert.equal(value, 5);
  // });

  // mocha에서 특정 테케만 실행시키려면 only 쓰면된다
  // it.only("getPot should return current pot", async () => {
  //   console.log("Basic test");
  //   let pot = await lottery.getPot();
  //   assert.equal(pot, 0);
  // });

  describe("Bet", async () => {
    it("베팅큐에 값이 잘 들어갔는지 확인하기", async () => {
      // 베팅한다
      const receipt = await lottery.bet("0xab", {
        from: user1,
        value: betAmount, // 5 * 10 ** 15 -> 0.005ETH
      });

      // bet함수 실행 -> 0.005ETH가 아니기에 트잭이 실패나야한다
      let pot = await lottery.getPot();
      assert.equal(pot, 0);

      // 컨트랙트 주소로 0.005이더가 들어왔는지 확인한다
      let contractBalance = await web3.eth.getBalance(lottery.address); // web3가 자동으로 주입돼있다
      assert.equal(contractBalance, betAmount);

      // 베팅인포가 제대로 들어갔는지 확인한다
      let currentBlockNumber = await web3.eth.getBlockNumber();
      let bet = await lottery.getBetInfo(0); // 큐 제일 앞의 베팅정보를 가져온다

      // 큐에 넣은 베팅정보가 올바른지 확인
      assert.equal(
        bet.answerBlockNumber,
        currentBlockNumber + BET_BLOCK_INTERVAL
      );
      assert.equal(bet.bettor, user1);
      assert.equal(bet.challenges, "0xab");

      // 로그(BET이라는 이벤트)가 제대로 찍혔는지 확인한다
      await expectEvent.inLogs(receipt.logs, "BET");
    });

    it("0.005이더가 안들어왔을때는 실패해야한다", async () => {
      // 트랜잭션 실패
      await assertRevert(
        // 두번째 인자는 트랜잭션 오브젝트, transaction object란
        // (chainId, value, to, from, gas(limit), gasPrice)
        lottery.bet("0xab", { from: user1, value: 4000000000000000 }) // bet함수 실행 -> 0.005ETH가 아니기에 트잭이 실패나야한다
      );
    });
  });

  describe.only('isMatch', function () {
    let blockHash = '0xab65ffa3380377e7694837e74373720e2af9964a9934394f4d717acc959fa8b4'
    it('두개의 글자가 모두 일치하면 BettingResult.Win을 출력해야한다', async function () {
      let matchingResult = await lottery.isMatch('0xab', blockHash);
      assert.equal(matchingResult, 1)
    });
    it('하나의 글자가 일치하면 BettingResult.Draw을 출력해야한다', async function () {
      let matchingResult = await lottery.isMatch('0xfb', blockHash);
      assert.equal(matchingResult, 2)

      matchingResult = await lottery.isMatch('0xae', blockHash);
      assert.equal(matchingResult, 2)
    });
    it('두개의 글자가 모두 실패하면 BettingResult.Fail을 출력해야한다', async function () {
      let matchingResult = await lottery.isMatch('0x12', blockHash);
      assert.equal(matchingResult, 0)
    });

  })
});
