const std = @import("std");

const PieceType = enum {
    Pawn,
    Knight,
    Bishop,
    Rook,
    Queen,
    King,
    None,
};

const Color = enum {
    White,
    Black,
    None,
};

pub fn as_square(square: []const u8) u64 {
    const file = square[0] - 'a';
    const rank = square[1] - '1';

    return (rank * 8) + file;
}

const Piece = struct {
    type: PieceType,
    color: Color,

    pub fn ascii_repr(self: *const Piece) u8 {
        var char: u8 = switch (self.type) {
            PieceType.Pawn => 'P',
            PieceType.Knight => 'N',
            PieceType.Bishop => 'B',
            PieceType.Rook => 'R',
            PieceType.Queen => 'Q',
            PieceType.King => 'K',
            PieceType.None => ' ',
        };
        char += switch (self.color) {
            Color.White => 0,
            Color.Black => 32,
            Color.None => 0,
        };

        return char;
    }
};

pub const Board = struct {
    pawns: u64,
    knights: u64,
    bishops: u64,
    rooks: u64,
    queens: u64,
    kings: u64,
    white: u64,
    black: u64,

    turn: Color,
    castling: struct {
        white_kingside: bool,
        white_queenside: bool,
        black_kingside: bool,
        black_queenside: bool,
    },

    en_passant: ?usize,
    halfmove: usize,
    fullmove: usize,

    pub fn get_pos_bitboard(pos: usize) u64 {
        return @as(u64, 1) << @intCast(pos);
    }

    pub fn get_piece_color(self: *Board, pos: usize) Color {
        const bitboard = Board.get_pos_bitboard(pos);

        if (self.white & bitboard > 0) {
            return Color.White;
        } else if (self.black & bitboard > 0) {
            return Color.Black;
        } else {
            return Color.None;
        }
    }

    pub fn get_piece_type(self: *Board, pos: usize) PieceType {
        const bitboard = Board.get_pos_bitboard(pos);

        if (self.pawns & bitboard > 0) {
            return PieceType.Pawn;
        } else if (self.knights & bitboard > 0) {
            return PieceType.Knight;
        } else if (self.bishops & bitboard > 0) {
            return PieceType.Bishop;
        } else if (self.rooks & bitboard > 0) {
            return PieceType.Rook;
        } else if (self.queens & bitboard > 0) {
            return PieceType.Queen;
        } else if (self.kings & bitboard > 0) {
            return PieceType.King;
        } else {
            return PieceType.None;
        }
    }

    pub fn get_piece(self: *Board, pos: usize) Piece {
        return Piece{
            .type = self.get_piece_type(pos),
            .color = self.get_piece_color(pos),
        };
    }

    pub fn load_fen(fen: *const [64]u8) Board {
        var board = Board{
            .pawns = 0,
            .knights = 0,
            .bishops = 0,
            .rooks = 0,
            .queens = 0,
            .kings = 0,
            .white = 0,
            .black = 0,

            .turn = Color.None,
            .castling = .{
                .white_kingside = false,
                .white_queenside = false,
                .black_kingside = false,
                .black_queenside = false,
            },

            .en_passant = null,
            .halfmove = 0,
            .fullmove = 0,
        };

        var pos: usize = 0;
        var square: usize = 56;
        while (fen[pos] != ' ') : ({
            pos += 1;
        }) {
            if (fen[pos] == '/') {
                square -= 16;
                continue;
            }
            switch (fen[pos]) {
                'p' => {
                    board.pawns |= Board.get_pos_bitboard(square);
                    board.black |= Board.get_pos_bitboard(square);
                },
                'n' => {
                    board.knights |= Board.get_pos_bitboard(square);
                    board.black |= Board.get_pos_bitboard(square);
                },
                'b' => {
                    board.bishops |= Board.get_pos_bitboard(square);
                    board.black |= Board.get_pos_bitboard(square);
                },
                'r' => {
                    board.rooks |= Board.get_pos_bitboard(square);
                    board.black |= Board.get_pos_bitboard(square);
                },
                'q' => {
                    board.queens |= Board.get_pos_bitboard(square);
                    board.black |= Board.get_pos_bitboard(square);
                },
                'k' => {
                    board.kings |= Board.get_pos_bitboard(square);
                    board.black |= Board.get_pos_bitboard(square);
                },
                'P' => {
                    board.pawns |= Board.get_pos_bitboard(square);
                    board.white |= Board.get_pos_bitboard(square);
                },
                'N' => {
                    board.knights |= Board.get_pos_bitboard(square);
                    board.white |= Board.get_pos_bitboard(square);
                },
                'B' => {
                    board.bishops |= Board.get_pos_bitboard(square);
                    board.white |= Board.get_pos_bitboard(square);
                },
                'R' => {
                    board.rooks |= Board.get_pos_bitboard(square);
                    board.white |= Board.get_pos_bitboard(square);
                },
                'Q' => {
                    board.queens |= Board.get_pos_bitboard(square);
                    board.white |= Board.get_pos_bitboard(square);
                },
                'K' => {
                    board.kings |= Board.get_pos_bitboard(square);
                    board.white |= Board.get_pos_bitboard(square);
                },
                else => |dist| {
                    square += dist - '1';
                },
            }
            square += 1;
        }

        pos += 1;
        board.turn = if (fen[pos + 1] == 'w') Color.White else Color.Black;

        pos += 2;
        while (fen[pos] != ' ') : ({
            pos += 1;
        }) {
            switch (fen[pos]) {
                'K' => board.castling.white_kingside = true,
                'Q' => board.castling.white_queenside = true,
                'k' => board.castling.black_kingside = true,
                'q' => board.castling.black_queenside = true,
                else => continue,
            }
        }

        pos += 1;
        board.en_passant = if (fen[pos] == '-') null else as_square(fen[pos .. pos + 2]);

        pos += 3;
        while (fen[pos] != ' ') : (pos += 1) {
            board.halfmove = board.halfmove * 10 + fen[pos] - '0';
        }

        pos += 1;
        while (fen[pos] != 0) : (pos += 1) {
            board.fullmove = board.fullmove * 10 + fen[pos] - '0';
        }

        return board;
    }

    pub fn print(self: *Board) void {
        for (0..8) |row| {
            std.debug.print("+---+---+---+---+---+---+---+---+\n", .{});
            for (0..8) |col| {
                const square = 64 - ((row + 1) * 8 - col);
                const piece: Piece = self.get_piece(square);
                const char = piece.ascii_repr();

                std.debug.print("| {c} ", .{char});
            }
            std.debug.print("|\n", .{});
        }
        std.debug.print("+---+---+---+---+---+---+---+---+\n", .{});
    }
};
