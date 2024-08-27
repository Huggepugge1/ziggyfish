const std = @import("std");

const Board = @import("board.zig").Board;

const UciError = error{
    InvalidCommand,
    InvalidSubCommand,
    TooFewArguments,
    InvalidFen,
};

pub fn run() void {
    var board = Board.load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    while (true) {
        const stdin = std.io.getStdIn().reader();

        var buf: [1024]u8 = undefined;
        const bytes = stdin.readUntilDelimiterOrEof(buf[0..], '\n') catch |err| {
            std.debug.print("Error reading from stdin: {}\n", .{err});
            continue;
        };

        var command = std.mem.splitSequence(u8, bytes.?, " ");

        const mainCommand = command.next();

        if (mainCommand == null) {
            continue;
        } else if (std.mem.eql(u8, mainCommand.?, "uci")) {
            // DO NOTHING
        } else if (std.mem.eql(u8, mainCommand.?, "debug")) {
            // TODO: Implement debug command
        } else if (std.mem.eql(u8, mainCommand.?, "isready")) {
            std.debug.print("readyok\n", .{});
        } else if (std.mem.eql(u8, mainCommand.?, "setoption")) {
            // TODO: Implement setoption command
        } else if (std.mem.eql(u8, mainCommand.?, "position")) {
            board = set_pos(&command) catch |err| {
                std.debug.print("Error: {}\n", .{err});
                continue;
            };
        } else if (std.mem.eql(u8, mainCommand.?, "print")) {
            board.print();
        } else {
            std.debug.print("Error: {} {s}\n", .{ UciError.InvalidCommand, mainCommand.? });
        }
    }
}

fn set_pos(command: *std.mem.SplitIterator(u8, std.mem.DelimiterType.sequence)) UciError!Board {
    const subCommand = command.next();

    if (subCommand == null) {
        return UciError.TooFewArguments;
    }

    var result: Board = Board.load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

    const startpos = std.mem.eql(u8, subCommand.?, "startpos");
    const fen = std.mem.eql(u8, subCommand.?, "fen");

    if (startpos) {
        // TODO: Implement move list
    } else if (fen) {
        var fenbuf: [64]u8 = [_]u8{0} ** 64;
        var len: usize = 0;
        for (0..6) |_| {
            if (command.peek() == null) {
                return UciError.InvalidFen;
            }
            const next = command.next().?;
            for (0..next.len) |i| {
                fenbuf[len] = next[i];
                len += 1;
            }
            fenbuf[len] += ' ';
            len += 1;
        }
        fenbuf[len - 1] = 0;
        std.debug.print("FEN: {s}\n", .{fenbuf});
        result = Board.load_fen(&fenbuf);
        //TODO: Implement move list
    } else {
        return UciError.InvalidSubCommand;
    }

    return result;
}
