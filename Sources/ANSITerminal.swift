#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

public let ESC = "\u{1B}"  // Escape character (27 or 1B)
public let SS2 = ESC+"N"   // Single Shift Select of G2 charset
public let SS3 = ESC+"O"   // Single Shift Select of G3 charset
public let DCS = ESC+"P"   // Device Control String
public let CSI = ESC+"["   // Control Sequence Introducer
public let OSC = ESC+"]"   // Operating System Command

// some fancy characters, required appropriate font installed
public let RPT = "\u{e0b0}"   // right pointing triangle
public let LPT = "\u{e0b2}"   // left pointing triangle
public let RPA = "\u{e0b1}"   // right pointing angle
public let LPA = "\u{e0b3}"   // left pointing angle

internal private(set) var defaultTerminal = termios()
public   private(set) var isNonBlockingMode = false

@inlinable public func delay(_ ms: Int) {
  usleep(UInt32(ms * 1000))  // convert to milliseconds
}

@inlinable public func unicode(_ code: Int) -> Unicode.Scalar {
  return Unicode.Scalar(code) ?? "\0"
}

@inlinable public func clearBuffer(isOut: Bool = true, isIn: Bool = true) {
  if isIn { fflush(stdin) }
  if isOut { fflush(stdout) }
}

internal func disableNonBlockingTerminal() {
  // restore default terminal mode
  tcsetattr(STDIN_FILENO, TCSANOW, &defaultTerminal)
  isNonBlockingMode = false
}

internal func enableNonBlockingTerminal(rawMode: Bool = false) {
  // store current terminal mode
  tcgetattr(STDIN_FILENO, &defaultTerminal)
  atexit(disableNonBlockingTerminal)
  isNonBlockingMode = true

  // configure non-blocking and non-echoing terminal mode
  var nonBlockTerm = defaultTerminal
  if rawMode {
    //! full raw mode without any input processing at all
    cfmakeraw(&nonBlockTerm)
  } else {
    // disable CANONical mode and ECHO-ing input
    nonBlockTerm.c_lflag &= ~tcflag_t(ICANON | ECHO)
    // acknowledge CRNL line ending and UTF8 input
    nonBlockTerm.c_iflag &= ~tcflag_t(ICRNL | IUTF8)
  }

  // enable new terminal mode
  tcsetattr(STDIN_FILENO, TCSANOW, &nonBlockTerm)
}

// check key from input poll
public func keyPressed() -> Bool {
  if !isNonBlockingMode { enableNonBlockingTerminal() }
  var fds = [ pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0) ]
  return poll(&fds, 1, 0) > 0
}

// read key as character
public func readChar() -> Character {
  var key: UInt8 = 0
  let res = read(STDIN_FILENO, &key, 1)
  return res < 0 ? "\0" : Character(UnicodeScalar(key))
}

// read key as ascii code
public func readCode() -> Int {
  var key: UInt8 = 0
  let res = read(STDIN_FILENO, &key, 1)
  return res < 0 ? 0 : Int(key)
}

// request terminal info using ansi esc command and return the response value
internal func ansiRequest(_ command: String, endChar: Character) -> String {
  // store current input mode
  let nonBlock = isNonBlockingMode
  if !nonBlock { enableNonBlockingTerminal() }

  // send request
  write(STDOUT_FILENO, command, command.count)

  // read response
  var res: String = ""
  var key: UInt8  = 0
  repeat {
    read(STDIN_FILENO, &key, 1)
    if key < 32 {
      res.append("^")  // replace non-printable ascii
    } else {
      res.append(Character(UnicodeScalar(key)))
    }
  } while key != endChar.asciiValue

  // restore input mode and return response value
  if !nonBlock { disableNonBlockingTerminal() }
  return res
}

// direct write to standard output
public func write(_ text: String..., suspend: Int = 0) {
  for txt in text { write(STDOUT_FILENO, txt, txt.utf8.count) }
  if suspend > 0 { delay(suspend) }
  if suspend < 0 { clearBuffer() }
}

// direct write to standard output with new line
public func writeln(_ text: String..., suspend: Int = 0) {
  for txt in text { write(STDOUT_FILENO, txt, txt.utf8.count) }
  write(STDOUT_FILENO, "\n", 1)
  if suspend > 0 { delay(suspend) }
  if suspend < 0 { clearBuffer() }
}

// direct write to standard output only new line
public func writeln(suspend: Int = 0) {
  write(STDOUT_FILENO, "\n", 1)
  if suspend > 0 { delay(suspend) }
  if suspend < 0 { clearBuffer() }
}

public func ask(_ q: String, cleanUp: Bool = false) -> String {
  print(q, terminator: "")
  if cleanUp { clearBuffer() }
  return readLine()!
}
