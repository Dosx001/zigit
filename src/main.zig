const std = @import("std");
const git = @cImport(@cInclude("git2.h"));

pub fn main() !void {
    _ = git.git_libgit2_init();
    var repo: ?*git.git_repository = undefined;
    if (git.git_repository_open_ext(&repo, ".", 0, null) == git.GIT_ENOTFOUND) return;
    var oid: git.git_oid = undefined;
    try log(repo, &oid);
    try status();
    try state(repo);
    try branch(repo, &oid);
    try stash(repo);
    return;
}

fn branch(repo: ?*git.git_repository, oid: *git.git_oid) !void {
    var ref: ?*git.git_reference = undefined;
    _ = git.git_repository_head(&ref, repo);
    const name = git.git_reference_shorthand(ref);
    for ("HEAD", 0..) |c, i| {
        if (name[i] != c) break;
    } else {
        var output: [8]u8 = undefined;
        _ = git.git_oid_tostr(&output, 8, oid);
        std.debug.print("\x1b[30;41m {s} \x1b[0m", .{output});
        return;
    }
    std.debug.print("\x1b[30;41m {s} \x1b[0m", .{name});
}

fn log(repo: ?*git.git_repository, oid: *git.git_oid) !void {
    var walker: ?*git.git_revwalk = undefined;
    _ = git.git_revwalk_new(&walker, repo);
    _ = git.git_revwalk_push_ref(walker, "HEAD");
    _ = git.git_revwalk_next(oid, walker);
    var commit: ?*git.git_commit = undefined;
    _ = git.git_commit_lookup(&commit, repo, oid);
    std.debug.print("\x1b[90m{s}", .{git.git_commit_message(commit)});
}

fn stash(repo: ?*git.git_repository) !void {
    var count: u8 = 0;
    _ = git.git_stash_foreach(repo, stash_cb, &count);
    if (count == 0) {
        std.debug.print("\x1b[31m\n", .{});
    } else std.debug.print("\x1b[31;45m\x1b[30;45m Stashes: {} \x1b[0m\x1b[35m\n", .{count});
}

fn stash_cb(index: usize, message: [*c]const u8, stash_id: [*c]const git.git_oid, payload: ?*anyopaque) callconv(.C) c_int {
    _ = index;
    _ = stash_id;
    _ = message;
    const count: *u8 = @ptrCast(@alignCast(payload));
    count.* += 1;
    return 0;
}

fn state(repo: ?*git.git_repository) !void {
    const repo_state = git.git_repository_state(repo);
    const mode =
        switch (repo_state) {
        git.GIT_REPOSITORY_STATE_MERGE => "Merging onto",
        git.GIT_REPOSITORY_STATE_REVERT => "Revert",
        git.GIT_REPOSITORY_STATE_REVERT_SEQUENCE => "Revert",
        git.GIT_REPOSITORY_STATE_CHERRYPICK => "Cherrypick",
        git.GIT_REPOSITORY_STATE_CHERRYPICK_SEQUENCE => "Cherrypick",
        git.GIT_REPOSITORY_STATE_BISECT => "Bisect",
        git.GIT_REPOSITORY_STATE_REBASE => "Rebase",
        git.GIT_REPOSITORY_STATE_REBASE_INTERACTIVE => "Rebase",
        git.GIT_REPOSITORY_STATE_REBASE_MERGE => "Rebase/Merge",
        git.GIT_REPOSITORY_STATE_APPLY_MAILBOX => "Mailbox",
        git.GIT_REPOSITORY_STATE_APPLY_MAILBOX_OR_REBASE => "Mailbox or Rebase",
        else => return,
    };
    if (repo_state == git.GIT_REPOSITORY_STATE_MERGE) {
        const file = try std.fs.cwd().openFile(try std.fmt.allocPrintZ(std.heap.page_allocator, "{s}MERGE_MSG", .{git.git_repository_path(repo)}), .{});
        var buf: [32]u8 = undefined;
        _ = try file.reader().readUntilDelimiterOrEof(&buf, '\'');
        _ = try file.reader().readUntilDelimiterOrEof(&buf, '\'');
        for (buf, 0..) |c, i| {
            if (c == '\'') {
                std.debug.print("\x1b[30;41m {s} \x1b[42;31m", .{buf[0..i]});
                break;
            }
        }
    }
    std.debug.print("\x1b[30;42m {s} \x1b[41;32m\x1b[30;41m", .{mode});
}

fn status() !void {
    const args = [_][]const u8{ "git", "status", "-s" };
    var child = std.ChildProcess.init(&args, std.heap.page_allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    _ = try child.spawn();
    var stdout = std.ArrayList(u8).init(std.heap.page_allocator);
    var stderr = std.ArrayList(u8).init(std.heap.page_allocator);
    const max: usize = 1024 * 1024;
    _ = try std.ChildProcess.collectOutput(child, &stdout, &stderr, max);
    var j: usize = 0;
    for (stdout.items, 0..) |c, i| {
        if (c == '\n') {
            const color = switch (stdout.items[j]) {
                '?' => "\x1b[37m",
                ' ' => switch (stdout.items[j + 1]) {
                    'M' => "\x1b[33m",
                    'D' => "\x1b[31m",
                    else => "\x1b[0m",
                },
                'A' => switch (stdout.items[j + 1]) {
                    ' ' => "\x1b[34m",
                    'A' => "\x1b[37;44m",
                    'D' => "\x1b[96m",
                    'M' => "\x1b[94m",
                    'U' => "\x1b[30;44m",
                    else => "\x1b[0m",
                },
                'D' => switch (stdout.items[j + 1]) {
                    ' ' => "\x1b[91m",
                    'D' => "\x1b[37;41m",
                    'U' => "\x1b[30;41m",
                    else => "\x1b[0m",
                },
                'M' => switch (stdout.items[j + 1]) {
                    ' ' => "\x1b[32m",
                    'D' => "\x1b[38;5;202m",
                    'M' => "\x1b[93m",
                    else => "\x1b[0m",
                },
                'U' => switch (stdout.items[j + 1]) {
                    'A' => "\x1b[33;44m",
                    'D' => "\x1b[33;41m",
                    'U' => "\x1b[30;43m",
                    else => "\x1b[0m",
                },
                'R' => switch (stdout.items[j + 1]) {
                    ' ' => "\x1b[35m",
                    'D' => "\x1b[38;5;201m",
                    'M' => "\x1b[38;5;93m",
                    else => "\x1b[0m",
                },
                else => "\x1b[0m",
            };
            std.debug.print("{s}{s}\x1b[0m ", .{ color, stdout.items[j + 3 .. i] });
            j = i + 1;
            continue;
        }
    }
    if (j != 0) std.debug.print("\n", .{});
}
