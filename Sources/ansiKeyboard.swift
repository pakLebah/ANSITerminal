public enum NonPrintableChar: Character {
  case none      = "\u{00}"   // \0 NUL
  case bell      = "\u{07}"   // \a BELL
  case erase     = "\u{08}"   // BS
  case tab       = "\u{09}"   // \t TAB (horizontal)
  case linefeed  = "\u{0A}"   // \n LF
  case vtab      = "\u{0B}"   // \v VT (vertical tab)
  case formfeed  = "\u{0C}"   // \f FF
  case enter     = "\u{0D}"   // \r CR
  case endOfLine = "\u{1A}"   // SUB or EOL
  case escape    = "\u{1B}"   // \e ESC
  case space     = "\u{20}"   // SPACE
  case del       = "\u{7F}"   // DEL
}

public extension NonPrintableChar {
  func char() -> Character { return self.rawValue }
  func code() -> Int       { return Int(self.rawValue.asciiValue!) }
}

// check for non-printable character
@inlinable public func isNonPrintable(char: Character) -> Bool {
  return char < " " || char == "\u{7F}"
}

// check for non-printable ansi code
@inlinable public func isNonPrintable(code: Int) -> Bool {
  return code < 32 || code == 127
}

public enum ANSIKeyCode: UInt8 {
  case none      = 0    // null
  case up        = 65   // ESC [ A
  case down      = 66   // ESC [ B
  case right     = 67   // ESC [ C
  case left      = 68   // ESC [ D
  case end       = 70   // ESC [ F  or  ESC [ 4~
  case home      = 72   // ESC [ H  or  ESC [ 1~
  case insert    = 2    // ESC [ 2~
  case delete    = 3    // ESC [ 3~
  case pageUp    = 5    // ESC [ 5~
  case pageDown  = 6    // ESC [ 6~

  case f1        = 80   // ESC O P  or  ESC [ 11~
  case f2        = 81   // ESC O Q  or  ESC [ 12~
  case f3        = 82   // ESC O R  or  ESC [ 13~
  case f4        = 83   // ESC O S  or  ESC [ 14~
  case f5        = 15   // ESC [ 15~
  case f6        = 17   // ESC [ 17~
  case f7        = 18   // ESC [ 18~
  case f8        = 19   // ESC [ 19~
  case f9        = 20   // ESC [ 20~
  case f10       = 21   // ESC [ 21~
  case f11       = 23   // ESC [ 23~
  case f12       = 24   // ESC [ 24~
}

public enum ANSIMetaCode: UInt8 {
  case control = 1
  case shift   = 2
  case alt     = 3
}

private func SS3Letter(_ key: UInt8) -> ANSIKeyCode {
  switch key {
    case ANSIKeyCode.f1.rawValue : return .f1
    case ANSIKeyCode.f2.rawValue : return .f2
    case ANSIKeyCode.f3.rawValue : return .f3
    case ANSIKeyCode.f4.rawValue : return .f4
    default                      : return .none
  }
}

private func CSILetter(_ key: UInt8) -> ANSIKeyCode {
  switch key {
    case ANSIKeyCode.up.rawValue    : return .up
    case ANSIKeyCode.down.rawValue  : return .down
    case ANSIKeyCode.left.rawValue  : return .left
    case ANSIKeyCode.right.rawValue : return .right
    case ANSIKeyCode.home.rawValue  : return .home
    case ANSIKeyCode.end.rawValue   : return .end
    case ANSIKeyCode.f1.rawValue    : return .f1
    case ANSIKeyCode.f2.rawValue    : return .f2
    case ANSIKeyCode.f3.rawValue    : return .f3
    case ANSIKeyCode.f4.rawValue    : return .f4
    default                         : return .none
  }
}

private func CSINumber(_ key: UInt8) -> ANSIKeyCode {
  switch key {
    case 1                             : return .home
    case 4                             : return .end
    case ANSIKeyCode.insert.rawValue   : return .insert
    case ANSIKeyCode.delete.rawValue   : return .delete
    case ANSIKeyCode.pageUp.rawValue   : return .pageUp
    case ANSIKeyCode.pageDown.rawValue : return .pageDown
    case 11                            : return .f1
    case 12                            : return .f2
    case 13                            : return .f3
    case 14                            : return .f4
    case ANSIKeyCode.f5.rawValue       : return .f5
    case ANSIKeyCode.f6.rawValue       : return .f6
    case ANSIKeyCode.f7.rawValue       : return .f7
    case ANSIKeyCode.f8.rawValue       : return .f8
    case ANSIKeyCode.f9.rawValue       : return .f9
    case ANSIKeyCode.f10.rawValue      : return .f10
    case ANSIKeyCode.f11.rawValue      : return .f11
    case ANSIKeyCode.f12.rawValue      : return .f12
    default                            : return .none
  }
}

internal func isLetter(_ key: Int) -> Bool {
  return (65...90 ~= key)
}

internal func isNumber(_ key: Int) -> Bool {
  return (48...57 ~= key)
}

internal func isLetter(_ chr: Character) -> Bool {
  return ("A"..."Z" ~= chr)
}

internal func isNumber(_ chr: Character) -> Bool {
  return ("0"..."9" ~= chr)
}

internal func isLetter(_ str: String) -> Bool {
  return ("A"..."Z" ~= str)
}

internal func isNumber(_ str: String) -> Bool {
  return ("0"..."9" ~= str)
}

private func CSIMeta(_ key: UInt8) -> [ANSIMetaCode] {
  //! NOTE: if x = 1 then ~ becomes letter
  switch key {
    case  2: return [.shift]                     // ESC [ x ; 2~
    case  3: return [.alt]                       // ESC [ x ; 3~
    case  4: return [.shift, .alt]               // ESC [ x ; 4~
    case  5: return [.control]                   // ESC [ x ; 5~
    case  6: return [.shift, .control]           // ESC [ x ; 6~
    case  7: return [.alt,   .control]           // ESC [ x ; 7~
    case  8: return [.shift, .alt,   .control]   // ESC [ x ; 8~
    default: return []
  }
}

// read ANSI key code sequence
public func readKey() -> (code: ANSIKeyCode, meta: [ANSIMetaCode]) {
  let nonBlock = isNonBlockingMode
  if !nonBlock { enableNonBlockingTerminal() }

  var code = ANSIKeyCode.none
  var meta: [ANSIMetaCode] = []

  // make sure there is data in stdin
  if !keyPressed() { return (code, meta) }

  var val: Int    = 0
  var key: Int    = 0
  var cmd: String = ESC
  var chr: Character

  while true {                              // read key sequence
    cmd.append(readChar())                  // check for ESC combination

    if cmd == CSI {                         // found CSI command
      key = readCode()

      if isLetter(key) {                    // CSI + letter
        code = CSILetter(UInt8(key))
        break
      }
      else if isNumber(key) {               // CSI + numbers
        cmd = String(unicode(key))          // collect numbers
        repeat {
          chr = readChar()                  // char after number has been read
          if isNumber(chr) { cmd.append(chr) }
        } while isNumber(chr)
        val = Int(cmd)!                     // guaranted valid number

        if chr == ";" {                     // CSI + numbers + ;
          cmd = String(readChar())          // CSI + numbers + ; + meta
          if isNumber(cmd) { meta = CSIMeta(UInt8(cmd)!) }

          if val == 1 {                     // CSI + 1 + ; + meta
            key = readCode()                // CSI + 1 + ; + meta + letter
            if isLetter(key) { code = CSILetter(UInt8(key)) }
            break
          }
          else {                            // CSI + numbers + ; + meta + ~
            code = CSINumber(UInt8(val))
            _ = readCode()                  // dismiss the tilde (guaranted)
            break
          }
        }
        else {                              // CSI + numbers + ~ (guaranted)
          code = CSINumber(UInt8(val))
          break
        }
      }
      else { break }                        // neither letter nor numbers
    }
    else if cmd == SS3 {                    // found SS3 command
      key = readCode()
      if isLetter(key) { code = SS3Letter(UInt8(key)) }
      break
    }
    else { break }                          // unknown command is found
  }

  if !nonBlock { disableNonBlockingTerminal() }
  return (code, meta)
}
