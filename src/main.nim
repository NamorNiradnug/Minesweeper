import std/[os, times, strformat]

import minesweeper
import illwill
import argparse

var parser = newParser:
  help("TUI-based minesweeper written in nim")
  option("-l", "--level", help="difficulty level", choices = @["b", "beginner", "i", "intermediate", "e", "expert"], default=some("b"))
  option("-W", "--width", help="board width")
  option("-H", "--height", help="board height")
  option("-m", "--mines", help="mines number")

var board_params: tuple[width: int, height: int, mines: int]
try:
  let args = parser.parse(true)
  board_params =
    case args.level[0]
    of 'b': (8, 8, 10)
    of 'i': (14, 14, 40)
    of 'e': (30, 16, 99)
    else: raise newException(ValueError, "Unknown difficulty level name.")
  if not args.width.isEmptyOrWhitespace: board_params.width = args.width.parseInt
  if not args.height.isEmptyOrWhitespace: board_params.height = args.height.parseInt
  if not args.mines.isEmptyOrWhitespace: board_params.mines = args.mines.parseInt
except ShortCircuit as e:
  echo parser.help
  quit(0)
except ValueError as e:
  echo e.msg
  quit(1)


proc onExit() {.noconv.} = 
  illwillDeinit()
  quit(0)

illwillInit()
hideCursor()
setControlCHook(onExit)

proc drawBoard(tb: var TerminalBuffer, board: Board, focused: tuple[x: int, y: int]) =
  for x in 0..board.width - 1:
    for y in 0..board.height - 1:
      let (ch, color) =
        case board[x][y].state
        of Covered: ("#", fgWhite)
        of Uncovered:
          if board[x][y].mined: ("o", fgRed)
          else:
            let nearby = board.minesNearby(x, y)
            if nearby != 0:
              ($nearby, fgCyan)
            else:
              ("\u00B7", fgWhite)
        of Flagged: ("F", fgYellow)
      
      let draw_pos = (x: tb.width div 2 - (board.width - 2 * x), y: tb.height div 2 - (board.height div 2 - y))
      if focused != (x, y):
        tb.write(draw_pos.x, draw_pos.y, color, ch)
      else:
        tb.write(draw_pos.x, draw_pos.y, fgBlack, bgWhite, ch, resetStyle)
  tb.write(resetStyle)


proc writeCenteredText(tb: var TerminalBuffer, height: int, line: string) =
  if height >= 0: tb.write((tb.width - line.len) div 2, height, line)


var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
var game = initGame(board_params.width, board_params.height, board_params.mines)
var focused_pos = (x: 5, y: 5)
tb.drawBoard(game.board, focused_pos)

const CONTROLS_HELP = ["Arrows - navigation", "Space - uncover cell", "F - flag/unflag", "Q/Esc - exit"]

proc showControlsHelp() =
  for (i, line) in CONTROLS_HELP.pairs:
    tb.writeCenteredText((tb.height + game.board.height) div 2 + 1 + i, line)

proc hideControlsHelp() =
  for (i, line) in CONTROLS_HELP.pairs:
    tb.writeCenteredText((tb.height + game.board.height) div 2 + 1 + i, " ".repeat(line.len))

showControlsHelp()

var begining_time: float

while true:
  let game_state_before = game.state
  let key = getKey()
  var board_changed = true

  case key
  of Key.Space: board_changed = game.action(Uncover, focused_pos.x, focused_pos.y)
  of Key.F:     board_changed = game.action(ToggleFlag, focused_pos.x, focused_pos.y)
  of Key.Up:    focused_pos.y = max(focused_pos.y - 1, 0)
  of Key.Down:  focused_pos.y = min(focused_pos.y + 1, game.board.height - 1)
  of Key.Left:  focused_pos.x = max(focused_pos.x - 1, 0)
  of Key.Right: focused_pos.x = min(focused_pos.x + 1, game.board.width - 1)
  of Key.Q, Key.Escape: onExit()
  else:         board_changed = false

  if board_changed:
    tb.drawBoard(game.board, focused_pos)

    if game.isFinished:
      hideControlsHelp()
      tb.writeCenteredText((tb.height + game.board.height) div 2 + 1, &"You {game.state}! (Press Q or Esc to exit)")

    if game_state_before != game.state and game.state == Running:
      begining_time = epochTime()

  if not game.isFinished:
    let time_spent =
      if game.state == Inited: 0
      else: (epochTime() - begining_time).int
    let time_spent_string = &"""Time spent: {min(time_spent, 999):003} sec"""
    tb.write((tb.width - time_spent_string.len) div 2, (tb.height - game.board.height) div 2 - 2, time_spent_string)

  tb.display()
  sleep(20)

