use enum_map::Enum;
use enumset::{enum_set, EnumSet, EnumSetType};
use serde::{Deserialize, Serialize};

use crate::{Board, Row};

#[derive(Copy, Clone, Debug, Hash, Eq, PartialEq, Serialize, Deserialize)]
pub struct FallingPiece {
    pub kind: PieceState,
    pub x: i32,
    pub y: i32,
    pub tspin: TspinStatus,
    #[serde(default)]
    pub t_rotation_eligible: bool,
}

impl FallingPiece {
    #[inline]
    pub fn cells(&self) -> [(i32, i32); 4] {
        let mut cells = self.kind.cells();
        for (dx, dy) in cells.iter_mut() {
            *dx += self.x;
            *dy += self.y;
        }
        cells
    }

    #[inline]
    pub fn cells_with_connections(&self) -> [(i32, i32, EnumSet<Direction>); 4] {
        let mut cells = self.kind.cells_with_connections();
        for (dx, dy, _) in cells.iter_mut() {
            *dx += self.x;
            *dy += self.y;
        }
        cells
    }

    pub fn shift<R: Row>(&mut self, board: &Board<R>, dx: i32, dy: i32) -> bool {
        self.x += dx;
        self.y += dy;
        if board.obstructed(self) {
            self.x -= dx;
            self.y -= dy;
            false
        } else {
            if !board.ras_enabled {
                self.tspin = TspinStatus::None;
                self.t_rotation_eligible = false;
            }
            true
        }
    }

    pub fn sonic_drop<R: Row>(&mut self, board: &Board<R>) -> bool {
        let drop_by = self
            .cells()
            .iter()
            .map(|&(x, y)| y - board.column_heights()[x as usize])
            .min()
            .unwrap();
        if drop_by > 0 {
            if !board.ras_enabled {
                self.tspin = TspinStatus::None;
                self.t_rotation_eligible = false;
            }
            self.y -= drop_by;
            true
        } else if drop_by < 0 {
            let mut fell = false;
            loop {
                self.y -= 1;
                if board.obstructed(self) {
                    self.y += 1;
                    break;
                }
                fell = true;
                if !board.ras_enabled {
                    self.tspin = TspinStatus::None;
                    self.t_rotation_eligible = false;
                }
            }
            fell
        } else {
            false
        }
    }

    fn rotate<R: Row>(&mut self, target: PieceState, board: &Board<R>) -> bool {
			let initial = *self;
			self.kind = target;
	
			// 若提供自定义踢墙表（游戏 asc 踢墙表），使用它；否则用标准 SRS rotation_points。
			let custom_kicks = !board.kick_table.is_empty();
			let kick_count = if custom_kicks {
				board.kick_table.len()
			} else {
				initial.kind.rotation_points().len()
			};
	
			// 旋转方向乘数：CW=1，CCW=-1，180°=1
			let mult = match (initial.kind.1, target.1) {
				(RotationState::North, RotationState::West)
				| (RotationState::West, RotationState::South)
				| (RotationState::South, RotationState::East)
				| (RotationState::East, RotationState::North) => -1, // CCW
				_ => 1,                                              // CW / 180
			};
	
			for i in 0..kick_count {
				let (dx, dy) = if custom_kicks {
					board.kick_table[i]
				} else {
					let initial_offsets = initial.kind.rotation_points();
					let target_offsets = target.rotation_points();
					let (x1, y1) = initial_offsets[i];
					let (x2, y2) = target_offsets[i];
					(x1 - x2, y1 - y2)
				};
				self.x = initial.x + dx * mult;
				self.y = initial.y + dy;
				if !board.obstructed(self) {
					if target.0 == Piece::T {
						self.tspin = board.detect_tspin(self);
						self.t_rotation_eligible = board.ras_enabled;
					}
					return true;
				}
			}
	
			*self = initial;
			false
		}
	
	pub fn cw<R: Row>(&mut self, board: &Board<R>) -> bool {
        let mut target = self.kind;
        target.cw();
        self.rotate(target, board)
    }

    pub fn ccw<R: Row>(&mut self, board: &Board<R>) -> bool {
        let mut target = self.kind;
        target.ccw();
        self.rotate(target, board)
    }

    pub fn c180<R: Row>(&mut self, board: &Board<R>) -> bool {
        let mut target = self.kind;
        target.flip();
        self.rotate(target, board)
    }

    pub fn same_location(&self, other: &Self) -> bool {
        if self.kind.0 != other.kind.0 {
            return false;
        }
        let other_cells = other.cells();
        for c in &self.cells() {
            if !other_cells.contains(c) {
                return false;
            }
        }
        true
    }

    pub fn canonical(&self) -> FallingPiece {
        match self.kind.0 {
            Piece::T | Piece::J | Piece::L => *self,
            Piece::O => match self.kind.1 {
                RotationState::North => *self,
                RotationState::East => FallingPiece {
                    kind: PieceState(Piece::O, RotationState::North),
                    y: self.y - 1,
                    ..*self
                },
                RotationState::West => FallingPiece {
                    kind: PieceState(Piece::O, RotationState::North),
                    x: self.x - 1,
                    ..*self
                },
                RotationState::South => FallingPiece {
                    kind: PieceState(Piece::O, RotationState::North),
                    y: self.y - 1,
                    x: self.x - 1,
                    ..*self
                },
            },
            Piece::S | Piece::Z => match self.kind.1 {
                RotationState::North | RotationState::West => *self,
                RotationState::East => FallingPiece {
                    kind: PieceState(self.kind.0, RotationState::West),
                    x: self.x + 1,
                    ..*self
                },
                RotationState::South => FallingPiece {
                    kind: PieceState(self.kind.0, RotationState::North),
                    y: self.y - 1,
                    ..*self
                },
            },
            Piece::I => *self,
        }
    }
}
#[derive(Copy, Clone, Debug, Eq, PartialEq, Hash)]
pub enum CellColor {
    I,
    O,
    T,
    L,
    J,
    S,
    Z,
    Garbage,
    Unclearable,
    Empty,
}

#[derive(Debug, Hash, EnumSetType, Enum, Serialize, Deserialize)]
pub enum Piece {
    I,
    O,
    T,
    L,
    J,
    S,
    Z,
}

#[derive(Copy, Clone, Debug, Hash, Eq, PartialEq, Serialize, Deserialize)]
pub enum RotationState {
    North,
    South,
    East,
    West,
}

#[derive(Copy, Clone, Debug, Hash, Eq, PartialEq, Serialize, Deserialize)]
pub struct PieceState(pub Piece, pub RotationState);

#[derive(Copy, Clone, Debug, Hash, Eq, PartialEq, Serialize, Deserialize)]
pub enum TspinStatus {
    None,
    Mini,
    Full,
}

impl RotationState {
    pub fn cw(&mut self) {
        use RotationState::*;
        match self {
            North => *self = East,
            East => *self = South,
            South => *self = West,
            West => *self = North,
        }
    }

    pub fn ccw(&mut self) {
        use RotationState::*;
        match self {
            North => *self = West,
            West => *self = South,
            South => *self = East,
            East => *self = North,
        }
    }

    /// 180° 旋转：North<->South，East<->West。
    pub fn flip(&mut self) {
        use RotationState::*;
        match self {
            North => *self = South,
            South => *self = North,
            East => *self = West,
            West => *self = East,
        }
    }

    pub fn mini_tspin_corners(self) -> [(i32, i32); 2] {
        use RotationState::*;
        match self {
            North => [(-1, 1), (1, 1)],
            East => [(1, 1), (1, -1)],
            South => [(1, -1), (-1, -1)],
            West => [(-1, -1), (-1, 1)],
        }
    }

    pub fn non_mini_tspin_corners(self) -> [(i32, i32); 2] {
        use RotationState::*;
        match self {
            South => [(-1, 1), (1, 1)],
            West => [(1, 1), (1, -1)],
            North => [(1, -1), (-1, -1)],
            East => [(-1, -1), (-1, 1)],
        }
    }
}

impl PieceState {
    pub fn cw(&mut self) {
        self.1.cw()
    }

    pub fn ccw(&mut self) {
        self.1.ccw()
    }

    pub fn flip(&mut self) {
        self.1.flip()
    }

    /// Returns the cells this piece and orientation occupy relative to rotation point 1, as well
    /// as the connection directions, in no particular order.
    #[inline(always)]
    pub fn cells(&self) -> [(i32, i32); 4] {
        // I cells 必须与游戏端（tetris_controller.gd 的 4x4 矩阵绕中心旋转 + BlockData.json 的
        // I 形状）逐格一致。经 Python 模拟验证，游戏矩阵各状态 cells（相对左上角）为
        //   N: (0..3, 1)   E: (2, 0..3)   S: (0..3, 2)   W: (1, 0..3)
        // 换算到 CC 锚点（= 游戏左上角 + (1,1)，且 CC y 向上为正、游戏 y 向下为正）后应为：
        //   N: cy=0       S: cy=-1       E: cy=1,0,-1,-2     W: cy=1,0,-1,-2
        // 注意：旧实现把 E/S/W 的 cy 写反，导致 CC 对 I 旋转后的碰撞/落点判定与游戏差 1 行，
        // 表现为 I 方块“落地后旋转踢墙”错位（CC 预想落点与游戏实际落块不一致）。
        if self.0 == Piece::I {
            return match self.1 {
                RotationState::North => [(-1, 0), (0, 0), (1, 0), (2, 0)],
                RotationState::South => [(-1, -1), (0, -1), (1, -1), (2, -1)],
                RotationState::East => [(1, 1), (1, 0), (1, -1), (1, -2)],
                RotationState::West => [(0, 1), (0, 0), (0, -1), (0, -2)],
            };
        }
        macro_rules! gen_cells {
            ($([$(($x:expr, $y:expr)),*]),*) => {
                [$(
                    [$(($x, $y)),*],   // North
                    [$((-$x, -$y)),*], // South
                    [$(($y, -$x)),*],  // East
                    [$((-$y, $x)),*]   // West
                ),*]
            };
        }
        const CELLS: &'static [[(i32, i32); 4]] = &gen_cells![
            [(-1, 0), (0, 0), (1, 0), (2, 0)],  // I
            [(0, 0), (1, 0), (0, 1), (1, 1)],   // O
            [(-1, 0), (0, 0), (1, 0), (0, 1)],  // T
            [(-1, 0), (0, 0), (1, 0), (1, 1)],  // L
            [(-1, 0), (0, 0), (1, 0), (-1, 1)], // J
            [(-1, 0), (0, 0), (0, 1), (1, 1)],  // S
            [(-1, 1), (0, 1), (0, 0), (1, 0)]   // Z
        ];
        let index = self.0 as usize * 4 + self.1 as usize;
        CELLS[index]
    }

    pub fn cells_with_connections(&self) -> [(i32, i32, EnumSet<Direction>); 4] {
        use Direction::*;
        let rotate = |d: EnumSet<_>| match self.1 {
            RotationState::North => d,
            RotationState::East => d.iter().map(Direction::cw).collect(),
            RotationState::South => d.iter().map(Direction::flip).collect(),
            RotationState::West => d.iter().map(Direction::ccw).collect(),
        };
        let cells = self.cells();
        [
            (
                cells[0].0,
                cells[0].1,
                rotate(match self.0 {
                    Piece::I => enum_set!(Right),
                    Piece::O => enum_set!(Right | Up),
                    Piece::L => enum_set!(Right),
                    Piece::J => enum_set!(Right | Up),
                    Piece::T => enum_set!(Right),
                    Piece::S => enum_set!(Right),
                    Piece::Z => enum_set!(Right),
                }),
            ),
            (
                cells[1].0,
                cells[1].1,
                rotate(match self.0 {
                    Piece::I => enum_set!(Left | Right),
                    Piece::O => enum_set!(Left | Up),
                    Piece::L => enum_set!(Left | Right),
                    Piece::J => enum_set!(Left | Right),
                    Piece::T => enum_set!(Left | Right | Up),
                    Piece::S => enum_set!(Left | Up),
                    Piece::Z => enum_set!(Left | Down),
                }),
            ),
            (
                cells[2].0,
                cells[2].1,
                rotate(match self.0 {
                    Piece::I => enum_set!(Left | Right),
                    Piece::O => enum_set!(Right | Down),
                    Piece::L => enum_set!(Left | Up),
                    Piece::J => enum_set!(Left),
                    Piece::T => enum_set!(Left),
                    Piece::S => enum_set!(Down | Right),
                    Piece::Z => enum_set!(Up | Right),
                }),
            ),
            (
                cells[3].0,
                cells[3].1,
                rotate(match self.0 {
                    Piece::I => enum_set!(Left),
                    Piece::O => enum_set!(Left | Down),
                    Piece::L => enum_set!(Down),
                    Piece::J => enum_set!(Down),
                    Piece::T => enum_set!(Down),
                    Piece::S => enum_set!(Left),
                    Piece::Z => enum_set!(Left),
                }),
            ),
        ]
    }

    /// Returns the five rotation points associated with this piece and orientation.
    ///
    /// Note that the first point is always (0, 0). We include it here to make
    /// looping over the possible kicks easier.
    pub fn rotation_points(&self) -> [(i32, i32); 5] {
        use Piece::*;
        use RotationState::*;
        match (self.0, self.1) {
            (O, North) => [(0, 0); 5],
            (O, East) => [(0, -1); 5],
            (O, South) => [(-1, -1); 5],
            (O, West) => [(-1, 0); 5],

            (I, North) => [(0, 0), (-1, 0), (2, 0), (-1, 0), (2, 0)],
            (I, East) => [(-1, 0), (0, 0), (0, 0), (0, 1), (0, -2)],
            (I, South) => [(-1, 1), (1, 1), (-2, 1), (1, 0), (-2, 0)],
            (I, West) => [(0, 1), (0, 1), (0, 1), (0, -1), (0, 2)],

            // The rotation points for T, L, J, S, Z are all the same.
            (_, North) => [(0, 0); 5],
            (_, East) => [(0, 0), (1, 0), (1, -1), (0, 2), (1, 2)],
            (_, South) => [(0, 0); 5],
            (_, West) => [(0, 0), (-1, 0), (-1, -1), (0, 2), (-1, 2)],
        }
    }
}

impl rand::distributions::Distribution<Piece> for rand::distributions::Standard {
    fn sample<R: rand::Rng + ?Sized>(&self, rng: &mut R) -> Piece {
        match rng.gen_range(0, 7) {
            0 => Piece::I,
            1 => Piece::T,
            2 => Piece::O,
            3 => Piece::L,
            4 => Piece::J,
            5 => Piece::S,
            6 => Piece::Z,
            _ => unreachable!(),
        }
    }
}

impl Piece {
    pub fn to_char(self) -> char {
        match self {
            Piece::I => 'I',
            Piece::T => 'T',
            Piece::O => 'O',
            Piece::L => 'L',
            Piece::J => 'J',
            Piece::S => 'S',
            Piece::Z => 'Z',
        }
    }

    pub fn color(self) -> CellColor {
        match self {
            Piece::I => CellColor::I,
            Piece::T => CellColor::T,
            Piece::O => CellColor::O,
            Piece::L => CellColor::L,
            Piece::J => CellColor::J,
            Piece::S => CellColor::S,
            Piece::Z => CellColor::Z,
        }
    }
}

#[derive(Copy, Clone, Debug, Hash, Eq, PartialEq, Serialize, Deserialize)]
pub enum PieceMovement {
    Left,
    Right,
    Cw,
    Ccw,
    C180,
    SonicDrop,
}

impl PieceMovement {
    pub fn apply(self, piece: &mut FallingPiece, board: &Board) -> bool {
        match self {
            PieceMovement::Left => piece.shift(board, -1, 0),
            PieceMovement::Right => piece.shift(board, 1, 0),
            PieceMovement::Ccw => piece.ccw(board),
            PieceMovement::Cw => piece.cw(board),
            PieceMovement::C180 => piece.c180(board),
            PieceMovement::SonicDrop => piece.sonic_drop(board),
        }
    }
}

#[derive(EnumSetType, Debug)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
}

impl Direction {
    fn cw(self) -> Direction {
        match self {
            Direction::Up => Direction::Right,
            Direction::Right => Direction::Down,
            Direction::Down => Direction::Left,
            Direction::Left => Direction::Up,
        }
    }

    fn ccw(self) -> Direction {
        match self {
            Direction::Up => Direction::Left,
            Direction::Right => Direction::Up,
            Direction::Down => Direction::Right,
            Direction::Left => Direction::Down,
        }
    }

    fn flip(self) -> Direction {
        match self {
            Direction::Up => Direction::Down,
            Direction::Right => Direction::Left,
            Direction::Down => Direction::Up,
            Direction::Left => Direction::Right,
        }
    }
}

#[derive(Copy, Clone, Debug, Hash, Eq, PartialEq, Serialize, Deserialize)]
pub enum SpawnRule {
    Row19Or20,
    Row21AndFall,
    RowCustom(u8),
}

impl SpawnRule {
    pub fn spawn<R: Row>(self, piece: Piece, board: &Board<R>) -> Option<FallingPiece> {
        match self {
            SpawnRule::Row19Or20 => {
                let mut spawned = FallingPiece {
                    kind: PieceState(piece, RotationState::North),
                    x: 4,
                    y: 19,
                    tspin: TspinStatus::None,
                    t_rotation_eligible: false,
                };
                if !board.obstructed(&spawned) {
                    return Some(spawned);
                }
                spawned.y += 1;
                if !board.obstructed(&spawned) {
                    return Some(spawned);
                }
            }
            SpawnRule::Row21AndFall => {
                let mut spawned = FallingPiece {
                    kind: PieceState(piece, RotationState::North),
                    x: 4,
                    y: 21,
                    tspin: TspinStatus::None,
                    t_rotation_eligible: false,
                };
                if !board.obstructed(&spawned) {
                    spawned.shift(board, 0, -1);
                    return Some(spawned);
                }
            }
            SpawnRule::RowCustom(spawn_y) => {
                let spawned = FallingPiece {
                    kind: PieceState(piece, RotationState::North),
                    x: 4,
                    y: spawn_y as i32,
                    tspin: TspinStatus::None,
                    t_rotation_eligible: false,
                };
                if !board.obstructed(&spawned) {
                    return Some(spawned);
                }
            }
        }
        None
    }
}
