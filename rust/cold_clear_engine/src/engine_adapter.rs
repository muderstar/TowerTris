use std::sync::Arc;

use cold_clear::evaluation::{Evaluation, Evaluator};
use cold_clear::{BotPollState, Info, Interface, Options};
use libtetris::{Board, FallingPiece, LockResult, Piece, PlacementKind};
use opening_book::Book;

#[derive(Clone, Debug, Default)]
pub struct PlannerConfig {
    pub use_hold: bool,
    pub speculate: bool,
    pub threads: u32,
    pub max_nodes: u32,
    pub min_nodes: u32,
}

impl PlannerConfig {
    pub fn to_options(&self) -> Options {
        let mut options = Options::default();
        options.use_hold = self.use_hold;
        options.speculate = self.speculate;
        options.threads = self.threads;
        options.max_nodes = self.max_nodes;
        options.min_nodes = self.min_nodes;
        options
    }
}

#[derive(Clone, Debug)]
pub struct DecisionResponse {
    pub expected_location: FallingPiece,
    pub inputs: Vec<libtetris::PieceMovement>,
    pub hold: bool,
    pub info: DecisionInfo,
}

#[derive(Clone, Debug)]
pub struct DecisionInfo {
    pub nodes: u32,
    pub depth: u32,
    pub original_rank: u32,
    pub plan_len: usize,
}

impl From<(libtetris::Move, Info)> for DecisionResponse {
    fn from(value: (libtetris::Move, Info)) -> Self {
        let (mv, info) = value;
        let info = match info {
            Info::Normal(info) => DecisionInfo {
                nodes: info.nodes as u32,
                depth: info.depth as u32,
                original_rank: info.original_rank as u32,
                plan_len: info.plan.len(),
            },
            Info::PcLoop(info) => DecisionInfo {
                nodes: 0,
                depth: info.depth as u32,
                original_rank: 0,
                plan_len: 0,
            },
            Info::Book => DecisionInfo {
                nodes: 0,
                depth: 0,
                original_rank: 0,
                plan_len: 0,
            },
        };
        Self {
            expected_location: mv.expected_location,
            inputs: mv.inputs.iter().copied().collect(),
            hold: mv.hold,
            info,
        }
    }
}

pub struct DecisionEngine {
    interface: Interface,
}

impl DecisionEngine {
    pub fn new(board: Board, config: PlannerConfig) -> Self {
        let options = config.to_options();
        let evaluator = NativeEvaluator::default();
        let interface = Interface::launch(board, options, evaluator, None);
        Self { interface }
    }

    pub fn add_piece(&self, piece: Piece) {
        self.interface.add_next_piece(piece);
    }

    pub fn suggest_next_move(&self, incoming: u32) {
        self.interface.suggest_next_move(incoming);
    }

    pub fn poll_next_move(&self) -> Result<DecisionResponse, BotPollState> {
        self.interface.poll_next_move().map(DecisionResponse::from).map_err(|e| e)
    }

    pub fn block_next_move(&self) -> Option<DecisionResponse> {
        self.interface.block_next_move().map(DecisionResponse::from)
    }

    pub fn play_next_move(&self, piece: FallingPiece) {
        self.interface.play_next_move(piece);
    }

    pub fn reset(&self, field: [[bool; 10]; 40], b2b: bool, combo: u32) {
        self.interface.reset(field, b2b, combo);
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord)]
pub struct HeuristicValue(i64);

impl std::ops::Add for HeuristicValue {
    type Output = Self;
    fn add(self, rhs: Self) -> Self::Output {
        Self(self.0 + rhs.0)
    }
}

impl std::ops::Add<HeuristicValue> for i64 {
    type Output = HeuristicValue;
    fn add(self, rhs: HeuristicValue) -> Self::Output {
        HeuristicValue(self + rhs.0)
    }
}

impl std::ops::Div<usize> for HeuristicValue {
    type Output = Self;
    fn div(self, rhs: usize) -> Self::Output {
        Self(self.0 / rhs as i64)
    }
}

impl std::ops::Mul<usize> for HeuristicValue {
    type Output = Self;
    fn mul(self, rhs: usize) -> Self::Output {
        Self(self.0 * rhs as i64)
    }
}

impl Evaluation<()> for HeuristicValue {
    fn modify_death(self) -> Self {
        self
    }

    fn weight(self, min: &Self, rank: usize) -> i64 {
        self.0 - min.0 + rank as i64
    }

    fn improve(&mut self, other: Self) {
        if other.0 > self.0 {
            *self = other;
        }
    }
}

#[derive(Default)]
pub struct NativeEvaluator;

impl Evaluator for NativeEvaluator {
    type Value = HeuristicValue;
    type Reward = ();

    fn name(&self) -> String {
        String::from("tetris_tower_native")
    }

    fn evaluate(
        &self,
        lock: &LockResult,
        _board: &Board,
        move_time: u32,
        _placed: Piece,
    ) -> (Self::Value, Self::Reward) {
        let mut score = 0i64;
        score += (lock.cleared_lines.len() as i64) * 1000;
        score += if lock.perfect_clear { 5000 } else { 0 };
        score += if lock.b2b { 100 } else { 0 };
        score -= (move_time as i64) * 5;

        match lock.placement_kind {
            PlacementKind::MiniTspin | PlacementKind::MiniTspin1 | PlacementKind::MiniTspin2 => {
                score += 300;
            }
            PlacementKind::Tspin | PlacementKind::Tspin1 | PlacementKind::Tspin2 | PlacementKind::Tspin3 => {
                score += 600;
            }
            _ => {}
        }

        (HeuristicValue(score), ())
    }

    fn pick_move(&self, candidates: Vec<cold_clear::dag::MoveCandidate<Self::Value>>, incoming: u32) -> cold_clear::dag::MoveCandidate<Self::Value> {
        let mut best = None;
        for candidate in candidates {
            if best.as_ref().map_or(true, |cur: &cold_clear::dag::MoveCandidate<Self::Value>| candidate.evaluation > cur.evaluation) {
                best = Some(candidate);
            }
        }
        best.unwrap_or_else(|| panic!("No candidates available"))
    }
}
