pragma solidity >=0.4.21 <0.6.0;

contract Lottery {
  struct BetInfo {
    uint256 answerBlockNumber; // 맞출 블록의 넘버
    address payable bettor; // 돈을 건 사람 주소, 특정주소에 돈을 보내려면 payable을 써줘야함
    bytes challenges; // 문제. ex) 0xab
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
  /*
    @dev 베팅을 한다. 유저는 0.005ETH를 보내야하고 베팅용 1byte 글자를 보낸다, 큐에 저장된 베팅 정보는 이후 distribute 함수에서 해결한다
    @param challenges 유저가 베팅하는 글자
    @return 함수가 잘 수행되었는지 확인하는 bool 값
    */
  function bet(bytes challenges) public payable returns (bool result) {
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

  // 베팅정보들을 담고있는 큐에서 베팅정보 가져오기
  function getBetInfo(uint256 index)
    public
    view
    returns (
      uint256 answerBlockNumber,
      address bettor,
      bytes challenges
    )
  {
    BetInfo memory b = _bets[index]; // memory형 변수는 함수가 끝나면 지워짐, storage형 변수는 블록에 영영 기록됨
    answerBlockNumber = b.answerBlockNumber; // 반환값1
    bettor = b.bettor; // 반환값2
    challenges = b.challenges; // 반환값3
  }

  // 큐 push
  function pushBet(bytes challenges) internal returns (bool) {
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
