//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");

const board = @import("board.zig");

pub fn main() void {
    var chess_board = board.Board.load_fen("rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2");

    chess_board.print();
    std.debug.print("{}\n", .{chess_board});
}
