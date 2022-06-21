const Lottery = artifacts.require("Lottery");

// mocha 테스트
contract('Lottery', ([deployer, user1, user2]) => { // 인자로 들어간 배열은 ganache-cli에서 만들어진 계정 10개가 순서대로 들어간다.
    let lottery;
    beforeEach(async () => {
        console.log('Before each')
        lottery = await Lottery.new(); //컨트랙 배포, migration.js에서 배포한것과 별개다
    })

    it('Basic test', async () => {
        console.log('Basic test')
        let owner = await lottery.owner();
        let value = await lottery.getSomeValue();

        console.log('owner: ' + owner)
        console.log('value: ' + value)
        assert.equal(owner, '0xF76c9B7012c0A3870801eaAddB93B6352c8893DB')
        assert.equal(value ,5)
    })

    // mocha에서 특정 테케만 실행시키려면 only 쓰면된다
    it.only('getPot should return current pot', async () => {
        console.log('Basic test')
        let pot = await lottery.getPot();
        assert.equal(pot ,0)
    })
})
