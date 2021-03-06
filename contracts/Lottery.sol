pragma solidity >=0.4.21 <0.6.0;

contract Lottery {
  struct BetInfo {
    uint256 answerBlockNumber; // 맞출 블록의 넘버
    address payable bettor; // 돈을 건 사람 주소, 특정주소에 돈을 보내려면 payable을 써줘야함
    bytes1 challenges; // 문제. ex) 0xab
  }

  // 매핑으로 큐를 구현하기 위한 변수
  uint256 private _tail;
  uint256 private _head;

  // 키는 uint, 값은 BerInfo인 매핑
  mapping(uint256 => BetInfo) private _bets;

  address public owner;

  uint256 internal constant BLOCK_LIMIT = 256; // 블록해시를 확인할 수 있는 제한
  uint256 internal constant BET_BLOCK_INTERVAL = 3; // 2번 블록에서 베팅을 하면 5번 블록에서 결과가 나온다
  uint256 internal constant BET_AMOUNT = 5 * 10**15; // 0.005ETH

  uint256 private _pot;

  enum BlockStatus {Checkable, NotRevealed, BlockLimitPassed}
  enum BettingResult {Fail, Win, Draw}

  // 이벤트 로그들을 한번에 모을 수 있다, BET이라는 로그들을 찍어줘
  // (몇번째 배팅인지, 누가 배팅했는지, 얼마 배팅했는지, 어떤글자로 베팅했는지, 어떤 블록에 정답이 있는지)
  event BET(uint256 index, address bettor, uint256 amount, bytes1 challenges, uint256 answerBlockNumber);

  constructor() public {
    owner = msg.sender; // msg.sender는 전역변수
  }

  function getPot() public view returns (uint256 value) {
    // 스마트 컨트랙의 변수를 가져와서 쓰려면 view 키ㅕ드를 쓴다
    return _pot;
  }

  // Bet (베팅하기)
  /**
    @dev 베팅을 한다. 유저는 0.005ETH를 보내야하고 베팅용 1byte 글자를 보낸다, 큐에 저장된 베팅 정보는 이후 distribute 함수에서 해결한다
    @param challenges 유저가 베팅하는 글자
    @return 함수가 잘 수행되었는지 확인하는 bool 값
  */
  function bet(bytes1 challenges) public payable returns (bool result) {
    // 돈이 제대로 왔는지 확인
    // require는 if역할, msg.value는 컨트랙트가 받은금액, 문자열은 조건이 false때 출력할 문구
    require(msg.value == BET_AMOUNT, 'Not Enough ETH');

    // 큐에 베팅정보를 넣기
    require(pushBet(challenges), 'Fail to add a new Bew Info');

    // 이벤트 로그를 찍는다
    // (몇번째 배팅인지, 누가 배팅했는지, 얼마 배팅했는지, 어떤글자로 베팅했는지, 어떤 블록에 정답이 있는지)
    emit BET(_tail - 1, msg.sender, msg.value, challenges, block.number + BET_BLOCK_INTERVAL);
    return true;
  }

  // 베팅한 값을 큐에 저장함

  // Distribute (검증하기)
  // 베팅한 값을 토대로 결과값을 검증
  // 검증결과가 틀리면 팟머니에 돈을 넣고, 맞으면 돈을 유저에게 준다
  function distribute() public {
    uint256 cur; // 베팅큐의 현재 포인터
    BetInfo memory b;
    BlockStatus currentBlockStatus;
    for(cur = _head; cur < _tail; cur++){
      b = _bets[cur];
      currentBlockStatus = getBlockStatus(b.answerBlockNumber); // 현재 결과를 볼 수 있는지를 확인함

      // Checkable -> 결과 확인 가능
      if(currentBlockStatus == BlockStatus.Checkable){
        // win: 둘 다 맞췄을 때-> bettor가 pot을 가져감

        // fail: 둘 다 틀렸을 때 -> bettor의 돈이 pot으로 감

        // draw: 글자를 하나만 맞췄을 때 -> bettor의 돈을 환불

      }

      // NotRevealed -> 아직 채굴 안돼서 확인 불가
      if(currentBlockStatus == BlockStatus.NotRevealed){
        break;
      }

      // BlockLimitPassed -> 블록리밋 초과함
      if(currentBlockStatus == BlockStatus.BlockLimitPassed){
        // 환불해줘야함
        // 환불이벤트를 emit

      }

      // queue pop
      popBet(cur);
    }
  }

/**
* @dev 베팅글자와 정답을 확인한다
* @param challenges 베팅 글자
* @param answer 블럭해쉬
* @return 정답결과
 */
  function isMatch(byte challenges, bytes32 answer) public pure returns (BettingResult) {
    // challenges: 0xab
    // answer 0xab.......
    // challenges와 answer의 첫번째 두번째 바이트를 뽑아와서 비교하기

    byte c1 = challenges;
    byte c2 = challenges;

    byte a1 = answer[0]; // 0xab의 a위치가 뽑힘
    byte a2 = answer[0];

    c1 = c1 >> 4; // 4비트 쉬프트: 0xab -> 0x0a // 1010 1011 -> 0000 1010
    c1 = c1 << 4; // 4비트 쉬프트: 0x0a -> 0xa0 // 0000 1010 -> 1010 0000

    a1 = a1 >> 4;
    a1 = a1 << 4; // 0xa0

    c2 = c2 << 4; // 0xb0
    c2 = c2 >> 4; // 0x0b

    a2 = a2 << 4;
    a2 = a2 >> 4;

    // 둘 다 맞았을 때
    if(a1 == c1 && a2 == c2){
      return BettingResult.Win;
    }

    // 하나만 맞았을 때
    if(a1 == c1 || a2 == c2){
      return BettingResult.Draw;
    }

    // 둘 다 틀렸을 때
    return BettingResult.Fail;
  }

  function getBlockStatus(uint256 answerBlockNumber) internal view returns (BlockStatus) {
    // 블록 해쉬를 확인할 수 있을때
    // 현재블록번호 > 정답블록번호 && 현재블록번호 - 블록리밋 < 정답블록번호
    if (block.number > answerBlockNumber && block.number < BLOCK_LIMIT + answerBlockNumber) {
      return BlockStatus.Checkable;
    }

    // 블록해쉬를 체크할 수 없을때(블록이 채굴되지 않았을때)
    // 현재블록번호 <= 정답블록번호
    if (block.number <= answerBlockNumber) {
      return BlockStatus.NotRevealed;
    }

    // 블록 제한을 넘었을 때
    // 현재블록번호 >= 정답블록번호 + 블록리밋
    if (block.number >= answerBlockNumber + BLOCK_LIMIT) {
      return BlockStatus.BlockLimitPassed;
    }
    return BlockStatus.BlockLimitPassed;
  }

  // 베팅정보들을 담고있는 큐에서 베팅정보 가져오기
  function getBetInfo(uint256 index)
    public
    view
    returns (
      uint256 answerBlockNumber,
      address bettor,
    bytes1 challenges
    )
  {
    BetInfo memory b = _bets[index]; // memory형 변수는 함수가 끝나면 지워짐, storage형 변수는 블록에 영영 기록됨
    answerBlockNumber = b.answerBlockNumber; // 반환값1
    bettor = b.bettor; // 반환값2
    challenges = b.challenges; // 반환값3
  }

  // 큐 push
  function pushBet(bytes1 challenges) internal returns (bool) {
    BetInfo memory b; // 베팅정보를 하나 생성하고 세팅한다
    b.bettor = msg.sender; // 함수 호출한 사람
    b.answerBlockNumber = block.number + BET_BLOCK_INTERVAL; // block.number는 현재 이 트랜잭션이 들어가게되는 블록넘버를 가져온다
    b.challenges = challenges; // 내가 베팅한 값

    _bets[_tail] = b; // 큐에 넣고
    _tail++; // 테일 포인터 조정

    return true;
  }

  // 큐 pop
  function popBet(uint256 index) internal returns (bool) {
    // delete를 하면 가스를 돌려받는다. 왜? 상태데이터베이스에 저장된 값을 그냥 뽑아오겠다는 것이기에
    // 그러니 필요하지 않은 값이 있다면 delete를 해주자
    delete _bets[index];
    return true;
  }
}
