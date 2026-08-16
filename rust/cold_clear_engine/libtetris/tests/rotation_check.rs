//! Rotation consistency test for the bot's I-piece rotation geometry (piece.rs).
//!
//! The game (tetris_controller.gd) is the authoritative source for actual piece
//! placement. This test verifies the bot's four I-piece orientations land on the
//! exact absolute cells the game produces (from the prior I-spin fix), so the bot
//! does not mis-rotate the I piece relative to the game.

use libtetris::{Board, FallingPiece, Piece, PieceState, RotationState, TspinStatus};

/// The game's kick table ("all", tetris_controller.gd).
const GAME_KICKS: &[(i32, i32)] = &[
    (0, 0),
    (-1, 0),
    (0, 1),
    (-1, 1),
    (0, 2),
    (-1, 2),
    (-2, 0),
    (-2, 1),
    (-2, 2),
    (1, 0),
    (1, 1),
    (0, -1),
    (-1, -1),
    (-2, -1),
    (1, 2),
    (2, 0),
    (0, -2),
    (-1, -2),
    (-2, -2),
    (2, 1),
    (2, 2),
];

fn make_board() -> Board {
    let mut b: Board = Board::new();
    b.kick_table = GAME_KICKS.to_vec();
    b
}

fn piece_at(p: Piece, r: RotationState, x: i32, y: i32) -> FallingPiece {
    FallingPiece {
        kind: PieceState(p, r),
        x,
        y,
        tspin: TspinStatus::None,
    }
}

fn sorted(mut cells: Vec<(i32, i32)>) -> Vec<(i32, i32)> {
    cells.sort();
    cells
}

#[test]
fn i_piece_absolute_placements_match_game() {
    use libtetris::Piece::I;
    use libtetris::RotationState::*;
    // Authoritative game placements (from the prior I-spin fix), for a spawn at
    // rotation point x=4, y=11.
    let board = make_board();
    let spawn = piece_at(I, North, 4, 11);

    let north = spawn.cells();
    assert_eq!(
        sorted(north.to_vec()),
        sorted(vec![(3, 11), (4, 11), (5, 11), (6, 11)]),
        "I North does not match game"
    );

    let mut east = spawn;
    east.cw(&board);
    assert_eq!(
        sorted(east.cells().to_vec()),
        sorted(vec![(5, 9), (5, 10), (5, 11), (5, 12)]),
        "I East(CW) does not match game"
    );

    let mut south = spawn;
    south.cw(&board);
    south.cw(&board);
    assert_eq!(
        sorted(south.cells().to_vec()),
        sorted(vec![(3, 10), (4, 10), (5, 10), (6, 10)]),
        "I South(CW+CW) does not match game"
    );

    let mut west = spawn;
    west.ccw(&board);
    assert_eq!(
        sorted(west.cells().to_vec()),
        sorted(vec![(4, 9), (4, 10), (4, 11), (4, 12)]),
        "I West(CCW) does not match game"
    );

    println!("I piece absolute placements match the authoritative game placements.");
}