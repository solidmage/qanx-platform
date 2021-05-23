
///////////////////////////////////////////////
// QANX STARTS HERE, OPENZEPPELIN CODE ABOVE //
///////////////////////////////////////////////

contract QANX is ERC20, Ownable {

    // INITIALIZE AN ERC20 TOKEN BASED ON THE OPENZEPPELIN VERSION
    constructor() ERC20("QANX Token", "QANX") {

        // INITIALLY MINT TOTAL SUPPLY TO CREATOR
        _mint(_msgSender(), 3333333000 * (10 ** 18));
    }

    // REPRESENTS A LOCK WHICH MIGHT BE APPLIED ON AN ADDRESS
    struct Lock {
        uint256 tokenAmount;    // HOW MANY TOKENS ARE LOCKED
        uint32 hardLockUntil;   // UNTIL WHEN NO LOCKED TOKENS CAN BE ACCESSED
        uint32 softLockUntil;   // UNTIL WHEN LOCKED TOKENS CAN BE GRADUALLY RELEASED
        uint8 allowedHops;      // HOW MANY TRANSFERS LEFT WITH SAME LOCK PARAMS
        uint32 lastUnlock;      // LAST GRADUAL UNLOCK TIME (SOFTLOCK PERIOD)
    }

    // THIS MAPS LOCK PARAMS TO CERTAIN ADDRESSES WHICH RECEIVED LOCKED TOKENS
    mapping (address => Lock) private _locks;

    // RETURNS LOCK INFORMATION OF A GIVEN ADDRESS
    function lockOf(address account) public view virtual returns (Lock memory) {
        return _locks[account];
    }

    // RETURN THE BALANCE OF UNLOCKED AND LOCKED TOKENS COMBINED
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account] + _locks[account].tokenAmount;
    }

    // TRANSFER FUNCTION WITH LOCK PARAMETERS
    function transferLocked(address recipient, uint256 amount, uint32 hardLockUntil, uint32 softLockUntil, uint8 allowedHops) public returns (bool) {

        // ONLY ONE LOCKED TRANSACTION ALLOWED PER RECIPIENT
        require(_locks[recipient].tokenAmount == 0, "Only one lock per address allowed!");

        // SENDER MUST HAVE ENOUGH TOKENS (UNLOCKED + LOCKED BALANCE COMBINED)
        require(_balances[_msgSender()] + _locks[_msgSender()].tokenAmount >= amount, "Transfer amount exceeds balance");

        // IF SENDER HAS ENOUGH UNLOCKED BALANCE, THEN LOCK PARAMS CAN BE CHOSEN
        if(_balances[_msgSender()] >= amount){

            // DEDUCT SENDER BALANCE
            _balances[_msgSender()] = _balances[_msgSender()] - amount;

            // APPLY LOCK
            return _applyLock(recipient, amount, hardLockUntil, softLockUntil, allowedHops);
        }

        // OTHERWISE REQUIRE THAT THE CHOSEN LOCK PARAMS ARE SAME / STRICTER (allowedHops) THAN THE SENDER'S
        require(
            hardLockUntil >= _locks[_msgSender()].hardLockUntil && 
            softLockUntil >= _locks[_msgSender()].softLockUntil && 
            allowedHops < _locks[_msgSender()].allowedHops
        );

        // IF SENDER HAS ENOUGH LOCKED BALANCE
        if(_locks[_msgSender()].tokenAmount >= amount){

            // DECREASE LOCKED BALANCE OF SENDER
            _locks[_msgSender()].tokenAmount = _locks[_msgSender()].tokenAmount - amount;

            // APPLY LOCK
            return _applyLock(recipient, amount, hardLockUntil, softLockUntil, allowedHops);
        }

        // IF NO CONDITIONS WERE MET SO FAR, SPEND LOCKED BALANCE OF SENDER FIRST
        _locks[_msgSender()].tokenAmount = 0;

        // THEN DEDUCT THE REMAINDER FROM THE UNLOCKED BALANCE
        _balances[_msgSender()] = _balances[_msgSender()] - (amount - _locks[_msgSender()].tokenAmount);

        // APPLY LOCK
        return _applyLock(recipient, amount, hardLockUntil, softLockUntil, allowedHops);
    }

    // APPLIES LOCK TO RECIPIENT WITH SPECIFIED PARAMS AND EMITS A TRANSFER EVENT
    function _applyLock(address recipient, uint256 amount, uint32 hardLockUntil, uint32 softLockUntil, uint8 allowedHops) private returns (bool) {
        _locks[recipient] = Lock(amount, hardLockUntil, softLockUntil, allowedHops, 0);
        emit Transfer(_msgSender(), recipient, amount);
        return true;
    }
}
