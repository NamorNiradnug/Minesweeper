import std/[sequtils, random, sets]

type CellState* = enum
  Flagged, Covered, Uncovered

type Cell* = tuple
  state: CellState
  mined: bool

type Board* = seq[seq[Cell]]

type GameState* = enum
  Inited, Running, Won = "won", Lose = "lose"

type Game* = object
  board: Board
  state: GameState
  cells_uncovered: int
  mines_number: int

proc width*(board: Board): int = board.len
proc height*(board: Board): int = board[0].len
proc posOnBoard*(board: Board, x, y: int): bool = 0 <= x and x < board.width and 0 <= y and y < board.height

iterator cellAround*(board: Board, x, y: int): tuple[x: int, y: int] =
  for dx in -1..1:
    for dy in -1..1:
      if (dx != 0 or dy != 0) and board.posOnBoard(x + dx, y + dy): yield (x + dx, y + dy)


proc minesNearby*(board: Board, x, y: Natural): range[0..9] =
  result = 0
  for neigh in board.cellAround(x, y):
    if board[neigh.x][neigh.y].mined: result += 1

proc board*(game: Game): Board = game.board
proc minesNumber*(game: Game): Natural = game.mines_number
proc state*(game: Game): GameState = game.state
proc isFinished*(game: Game): bool = game.state == Won or game.state == Lose

proc initGame*(width, height, mines_number: Natural): Game =
  assert mines_number <= width * height - 9, $width & "x" & $height & " and " & $mines_number  # keeps 3x3 non-mined square empty

  result.mines_number = mines_number
  result.cells_uncovered = 0
  result.state = Inited
  result.board = repeat(repeat((Covered, false), height), width)

proc spawnMines(game: var Game, keep_empty: tuple[x: int, y: int]) =
  if game.state != Inited:
    return
  randomize()
  var positions = toSeq(0..game.board.width * game.board.height - 1).mapIt((it mod game.board.width, it div game.board.width))
  positions.keepItIf(max(abs(it[0] - keep_empty.x), abs(it[1] - keep_empty.y)) > 1)
  positions.shuffle()
  for i in 0..game.mines_number - 1:
    game.board[positions[i][0]][positions[i][1]].mined = true
  game.state = Running


proc uncoverCellAndAdjancent(game: var Game, x, y: Natural, waiting_to_uncover: var HashSet[tuple[x: int, y: int]]) = 
  assert game.board[x][y] == (Covered, false)

  game.board[x][y].state = Uncovered
  game.cells_uncovered += 1
  for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)]:
    let adj = (x: x + dx, y: y + dy)
    if game.board.posOnBoard(adj.x, adj.y):
      if game.board[adj.x][adj.y] == (Covered, false):
        if game.board.minesNearby(x, y) == 0 or game.board.minesNearby(adj.x, adj.y) == 0 or adj in waiting_to_uncover:
          waiting_to_uncover.excl(adj)
          game.uncoverCellAndAdjancent(adj.x, adj.y, waiting_to_uncover)
        else:
          waiting_to_uncover.incl(adj)


proc uncoverMines(board: var Board) =
  for x in 0..board.width - 1:
    for y in 0..board.height - 1:
      if board[x][y].mined: board[x][y].state = Uncovered


proc uncoverCell(game: var Game, x, y: Natural): bool =
  if game.state == Inited:
    game.spawnMines((x, y))
  if game.state != Running or game.board[x][y].state != Covered:
    return false
  if game.board[x][y].mined:
    game.board.uncoverMines()
    game.state = Lose
    return true
  var empty_set = initHashSet[tuple[x: int, y: int]]()
  game.uncoverCellAndAdjancent(x, y, empty_set)
  if game.cells_uncovered + game.mines_number == game.board.width * game.board.height: game.state = Won
  return true


proc toggleFlag(game: var Game, x, y: Natural): bool =
  if game.board[x][y].state == Uncovered:
    return false
  game.board[x][y].state = 
    if game.board[x][y].state == Covered: Flagged
    else: Covered
  return true


type GameAction* = enum
  ToggleFlag, Uncover


proc action*(game: var Game, action: GameAction, x, y: int): bool =
  if not game.board.posOnBoard(x, y) or game.state == Won or game.state == Lose:
    return false
  case action
  of ToggleFlag: return game.toggleFlag(x, y)
  of Uncover: return game.uncoverCell(x, y)


