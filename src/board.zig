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

pub fn as_square(square: []const u8) usize {
    const file = square[0] - 'a';
    const rank = square[1] - '1';

    return (rank * 8) + file;
}

pub fn as_string(square: u64) []const u8 {
    const file = (square % 8) + 'a';
    const rank = (square / 8) + '1';

    return [_]u8{ file, rank };
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

pub const SpecialMove = enum(u4) {
    None = 0b0000,
    double_pawn_push = 0b0001,
    king_castle = 0b0010,
    queen_castle = 0b0011,
    capture = 0b0100,
    en_passant = 0b0101,
    knight_promotion = 0b1000,
    bishop_promotion = 0b1001,
    rook_promotion = 0b1010,
    queen_promotion = 0b1011,
    knight_promotion_capture = 0b1100,
    bishop_promotion_capture = 0b1101,
    rook_promotion_capture = 0b1110,
    queen_promotion_capture = 0b1111,
};

const MoveError = error{
    InvalidStartPiece,
    InvalidEnPassant,
    OwnCapture,
};

pub const Move = struct {
    move: u16,

    pub fn get_from(self: *const Move) usize {
        return self.move & 0x3F;
    }

    pub fn get_to(self: *const Move) usize {
        return (self.move >> 6) & 0x3F;
    }

    pub fn get_special_bitmap(self: *const Move) u4 {
        return @intCast((self.move >> 12) & 0xF);
    }

    pub fn get_special(self: *const Move) SpecialMove {
        return std.meta.intToEnum(SpecialMove, (self.move >> 12) & 0xF) catch SpecialMove.None;
    }

    pub fn is_capture(self: *const Move) bool {
        return self.get_special_bitmap() & @intFromEnum(SpecialMove.capture) > 0;
    }

    pub fn is_en_passant(self: *const Move) bool {
        return self.get_special_bitmap() & @intFromEnum(SpecialMove.en_passant) > 0;
    }

    pub fn is_promotion(self: *const Move) bool {
        return self.get_special_bitmap() & @intFromEnum(SpecialMove.promotion) > 0;
    }

    pub fn create(from: u6, to: u6, special: SpecialMove) Move {
        return Move{
            .move = from | (@as(u16, to) << 6) | (@as(u16, @intFromEnum(special)) << 12),
        };
    }

    pub fn from_string(move: []const u8, board: *Board) Move {
        const from: u6 = @intCast(as_square(move[0..2]));
        const to: u6 = @intCast(as_square(move[2..4]));

        const from_piece = board.get_piece(from);
        const to_piece = board.get_piece(to);

        var special: SpecialMove = SpecialMove.None;
        // Capture
        if (to_piece.type != PieceType.None) {
            special = SpecialMove.capture;
        }
        // En_passant
        if (board.en_passant == to and from_piece.type == PieceType.Pawn) {
            special = SpecialMove.en_passant;
            return Move.create(from, to, special);
        }
        // Promotion
        if (move.len == 5) {
            switch (special) {
                SpecialMove.None => special = switch (move[4]) {
                    'n' => SpecialMove.knight_promotion,
                    'b' => SpecialMove.bishop_promotion,
                    'r' => SpecialMove.rook_promotion,
                    'q' => SpecialMove.queen_promotion,
                    else => unreachable,
                },
                SpecialMove.capture => special = switch (move[4]) {
                    'n' => SpecialMove.knight_promotion_capture,
                    'b' => SpecialMove.bishop_promotion_capture,
                    'r' => SpecialMove.rook_promotion_capture,
                    'q' => SpecialMove.queen_promotion_capture,
                    else => unreachable,
                },
                else => unreachable,
            }
            return Move.create(from, to, special);
        }

        if (from_piece.type == PieceType.King) {
            if (from == 4 and to == 6) {
                special = SpecialMove.king_castle;
            } else if (from == 4 and to == 2) {
                special = SpecialMove.queen_castle;
            }
            if (from == 60 and to == 62) {
                special = SpecialMove.king_castle;
            } else if (from == 60 and to == 58) {
                special = SpecialMove.queen_castle;
            }
        }

        return Move.create(from, to, special);
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

    fn change_turn(self: *Board) void {
        self.turn = switch (self.turn) {
            Color.White => Color.Black,
            Color.Black => Color.White,
            Color.None => unreachable,
        };
    }

    pub fn move_piece(self: *Board, move: Move) MoveError!void {
        const from = move.get_from();
        const to = move.get_to();

        const from_bitboard = Board.get_pos_bitboard(from);
        const to_bitboard = Board.get_pos_bitboard(to);

        const move_bitboard = from_bitboard | to_bitboard;

        const piece = self.get_piece(from);
        var end_piece: ?Piece = null;

        if (move.is_capture() and !move.is_en_passant()) {
            end_piece = self.get_piece(to);
            if (end_piece.?.color == self.turn) {
                return MoveError.OwnCapture;
            }
        }

        if (piece.color != self.turn) {
            return MoveError.InvalidStartPiece;
        }

        switch (piece.color) {
            Color.White => {
                self.white ^= move_bitboard;
            },
            Color.Black => {
                self.black ^= move_bitboard;
            },
            Color.None => unreachable,
        }

        switch (piece.type) {
            PieceType.Pawn => {
                self.pawns ^= move_bitboard;
            },
            PieceType.Knight => {
                self.knights ^= move_bitboard;
            },
            PieceType.Bishop => {
                self.bishops ^= move_bitboard;
            },
            PieceType.Rook => {
                self.rooks ^= move_bitboard;
                switch (piece.color) {
                    Color.White => {
                        if (from == 0) {
                            self.castling.white_queenside = false;
                        } else if (from == 7) {
                            self.castling.white_kingside = false;
                        }
                    },
                    Color.Black => {
                        if (from == 56) {
                            self.castling.black_queenside = false;
                        } else if (from == 63) {
                            self.castling.black_kingside = false;
                        }
                    },
                    Color.None => unreachable,
                }
            },
            PieceType.Queen => {
                self.queens ^= move_bitboard;
            },
            PieceType.King => {
                self.kings ^= move_bitboard;
                switch (piece.color) {
                    Color.White => {
                        self.castling.white_kingside = false;
                        self.castling.white_queenside = false;
                    },
                    Color.Black => {
                        self.castling.black_kingside = false;
                        self.castling.black_queenside = false;
                    },
                    Color.None => unreachable,
                }
            },
            PieceType.None => unreachable,
        }

        if (end_piece != null) {
            switch (end_piece.?.color) {
                Color.White => {
                    self.white ^= to_bitboard;
                },
                Color.Black => {
                    self.black ^= to_bitboard;
                },
                Color.None => unreachable,
            }

            switch (end_piece.?.type) {
                PieceType.Pawn => {
                    self.pawns ^= to_bitboard;
                },
                PieceType.Knight => {
                    self.knights ^= to_bitboard;
                },
                PieceType.Bishop => {
                    self.bishops ^= to_bitboard;
                },
                PieceType.Rook => {
                    self.rooks ^= to_bitboard;
                },
                PieceType.Queen => {
                    self.queens ^= to_bitboard;
                },
                PieceType.King => {
                    self.kings ^= to_bitboard;
                },
                PieceType.None => unreachable,
            }
        }

        switch (move.get_special()) {
            SpecialMove.double_pawn_push => {
                self.en_passant = if (self.turn == Color.White) to - 8 else to + 8;
            },
            SpecialMove.king_castle => {
                if (self.turn == Color.White) {
                    self.castling.white_kingside = false;
                    self.castling.white_queenside = false;
                    self.rooks ^= Board.get_pos_bitboard(7) | Board.get_pos_bitboard(5);
                } else {
                    self.castling.black_kingside = false;
                    self.castling.black_queenside = false;
                    self.rooks ^= Board.get_pos_bitboard(63) | Board.get_pos_bitboard(61);
                }
            },
            SpecialMove.queen_castle => {
                if (self.turn == Color.White) {
                    self.castling.white_kingside = false;
                    self.castling.white_queenside = false;
                    self.rooks ^= Board.get_pos_bitboard(0) | Board.get_pos_bitboard(3);
                } else {
                    self.castling.black_kingside = false;
                    self.castling.black_queenside = false;
                    self.rooks ^= Board.get_pos_bitboard(56) | Board.get_pos_bitboard(59);
                }
            },
            SpecialMove.en_passant => {
                if (self.en_passant == null) {
                    return MoveError.InvalidEnPassant;
                }
                if (self.turn == Color.White) {
                    self.black ^= Board.get_pos_bitboard(self.en_passant.?);
                    self.pawns ^= Board.get_pos_bitboard(self.en_passant.?);
                } else {
                    self.white ^= Board.get_pos_bitboard(self.en_passant.?);
                    self.pawns ^= Board.get_pos_bitboard(self.en_passant.?);
                }
            },
            SpecialMove.knight_promotion => {
                self.knights ^= to_bitboard;
                self.pawns ^= to_bitboard;
            },
            SpecialMove.bishop_promotion => {
                self.bishops ^= to_bitboard;
                self.pawns ^= to_bitboard;
            },
            SpecialMove.rook_promotion => {
                self.rooks ^= to_bitboard;
                self.pawns ^= to_bitboard;
            },
            SpecialMove.queen_promotion => {
                self.queens ^= to_bitboard;
                self.pawns ^= to_bitboard;
            },
            SpecialMove.knight_promotion_capture => {
                self.knights ^= to_bitboard;
                self.pawns ^= to_bitboard;
            },
            SpecialMove.bishop_promotion_capture => {
                self.bishops ^= to_bitboard;
                self.pawns ^= to_bitboard;
            },
            SpecialMove.rook_promotion_capture => {
                self.rooks ^= to_bitboard;
                self.pawns ^= to_bitboard;
            },
            SpecialMove.queen_promotion_capture => {
                self.queens ^= to_bitboard;
                self.pawns ^= to_bitboard;
            },
            else => {},
        }

        self.change_turn();
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
        board.turn = if (fen[pos] == 'w') Color.White else Color.Black;

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
