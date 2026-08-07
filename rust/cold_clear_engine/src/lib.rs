pub use cold_clear as engine;

pub mod adapter {
    use crate::engine::Options;
    use libtetris::{Board, Piece};

    pub struct PlannerConfig {
        pub use_hold: bool,
        pub speculate: bool,
        pub threads: u32,
        pub max_nodes: u32,
        pub min_nodes: u32,
    }

    impl Default for PlannerConfig {
        fn default() -> Self {
            Self {
                use_hold: true,
                speculate: true,
                threads: 1,
                max_nodes: 4_000_000_000,
                min_nodes: 0,
            }
        }
    }

    pub fn build_options(config: &PlannerConfig) -> Options {
        let mut options = Options::default();
        options.use_hold = config.use_hold;
        options.speculate = config.speculate;
        options.threads = config.threads;
        options.max_nodes = config.max_nodes;
        options.min_nodes = config.min_nodes;
        options
    }

    pub fn build_board() -> Board {
        Board::new()
    }

    pub fn add_piece(board: &mut Board, piece: Piece) {
        board.add_next_piece(piece);
    }
}
