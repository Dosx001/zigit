const std = @import("std");
const git = @cImport(@cInclude("git2.h"));

pub fn main() void {
    _ = git.git_libgit2_init();
    var repo: ?*git.git_repository = undefined;
    if (git.git_repository_open_ext(
        &repo,
        ".",
        0,
        null,
    ) == git.GIT_ENOTFOUND) return;
    const path = git.git_repository_path(repo);
    var buffer: [1024]u8 = undefined;
    log(repo);
    status();
    state(repo, path, &buffer);
    branch(path, &buffer);
    stash(path, &buffer);
    return;
}

fn branch(
    path: [*c]const u8,
    buffer: []u8,
) void {
    const file = std.fs.openFileAbsolute(
        std.fmt.bufPrint(
            buffer,
            "{s}HEAD",
            .{path},
        ) catch unreachable,
        .{},
    ) catch unreachable;
    var reader = file.reader(buffer);
    const len = reader.interface.discardDelimiterLimit(
        '\n',
        std.Io.Limit.limited(32),
    ) catch |e| switch (e) {
        error.StreamTooLong => return std.debug.print(
            "\x1b[30;41m {s} \x1b[0m",
            .{buffer[0..7]},
        ),
        else => unreachable,
    };
    std.debug.print(
        "\x1b[30;41m {s} \x1b[0m",
        .{buffer[16..len]},
    );
}

fn log(repo: ?*git.git_repository) void {
    var oid: git.git_oid = undefined;
    if (git.git_reference_name_to_id(
        &oid,
        repo,
        "HEAD",
    ) != 0) {
        std.debug.print("\n", .{});
        return;
    }
    var commit: ?*git.git_commit = undefined;
    _ = git.git_commit_lookup(&commit, repo, &oid);
    std.debug.print(
        "\x1b[90m{s}\n",
        .{git.git_commit_summary(commit)},
    );
}

fn stash(
    path: [*c]const u8,
    buffer: []u8,
) void {
    const file = std.fs.openFileAbsolute(
        std.fmt.bufPrint(
            buffer,
            "{s}logs/refs/stash",
            .{path},
        ) catch unreachable,
        .{},
    ) catch |e| {
        switch (e) {
            error.FileNotFound => {
                std.debug.print("\x1b[31m\n", .{});
                return;
            },
            else => unreachable,
        }
    };
    var reader = file.reader(buffer);
    var count: u8 = 0;
    while (reader.interface.takeDelimiterInclusive(
        '\n',
    ) != error.EndOfStream) count += 1;
    std.debug.print(
        "\x1b[31;45m\x1b[30;45m Stashes: {} \x1b[0m\x1b[35m\n",
        .{count},
    );
}

fn state(
    repo: ?*git.git_repository,
    path: [*c]const u8,
    buffer: []u8,
) void {
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
        const file = std.fs.openFileAbsolute(
            std.fmt.bufPrint(
                buffer,
                "{s}MERGE_MSG",
                .{path},
            ) catch unreachable,
            .{},
        ) catch unreachable;
        var reader = file.reader(buffer);
        reader.interface.discardAll(14) catch unreachable;
        std.debug.print(
            "\x1b[30;41m {s} \x1b[42;31m",
            .{reader.interface.takeDelimiterExclusive(
                '\'',
            ) catch unreachable},
        );
    }
    std.debug.print(
        "\x1b[30;42m {s} \x1b[41;32m\x1b[30;41m",
        .{mode},
    );
}

fn status() void {
    const args = [_][]const u8{ "git", "status", "-s" };
    var child = std.process.Child.init(
        &args,
        std.heap.c_allocator,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    _ = child.spawn() catch unreachable;
    var stderr = std.ArrayListAlignedUnmanaged(u8, null){};
    var stdout = std.ArrayListAlignedUnmanaged(u8, std.mem.Alignment.@"1").initCapacity(
        std.heap.c_allocator,
        1024,
    ) catch unreachable;
    _ = std.process.Child.collectOutput(
        child,
        std.heap.c_allocator,
        &stdout,
        &stderr,
        1_048_576,
    ) catch unreachable;
    var j: usize = 0;
    for (stdout.items, 0..) |c, i| {
        if (c == '\n') {
            const color = switch (stdout.items[j]) {
                '?' => "38;2;204;204;204",
                ' ' => switch (stdout.items[j + 1]) {
                    '?' => "38;2;204;204;204",
                    'm' => "38;2;255;255;0",
                    'M' => "38;2;193;156;0",
                    'D' => "38;2;197;15;31",
                    'T' => "38;2;165;42;42",
                    else => "",
                },
                'A' => switch (stdout.items[j + 1]) {
                    '?' => "38;2;204;204;204",
                    ' ' => "38;2;0;55;218",
                    'm' => "38;2;30;144;255",
                    'A' => "38;2;0;0;0m\x1b[48;2;0;55;218",
                    'D' => "38;2;97;214;214",
                    'M' => "38;2;30;144;255",
                    'U' => "38;2;193;156;0m\x1b[48;2;0;55;218",
                    'T' => "38;2;95;158;168",
                    else => "",
                },
                'D' => switch (stdout.items[j + 1]) {
                    ' ' => "38;2;231;72;86",
                    'D' => "38;2;0;0;0m\x1b[48;2;197;15;31",
                    'U' => "38;2;193;156;0m\x1b[48;2;197;15;31",
                    else => "",
                },
                'M' => switch (stdout.items[j + 1]) {
                    ' ' => "38;2;19;161;14",
                    'D' => "38;2;255;95;0",
                    'M' => "38;2;249;241;165",
                    'T' => "38;2;244;164;96",
                    else => "",
                },
                'U' => switch (stdout.items[j + 1]) {
                    'A' => "38;2;204;204;204m\x1b[48;2;0;55;218",
                    'D' => "38;2;204;204;204m\x1b[48;2;197;15;31",
                    'U' => "38;2;0;0;0m\x1b[48;2;193;156;0",
                    else => "",
                },
                'R' => switch (stdout.items[j + 1]) {
                    ' ' => "38;2;136;23;152",
                    'D' => "38;2;255;0;255",
                    'M' => "38;2;135;0;255",
                    'T' => "38;2;238;130;238",
                    else => "",
                },
                'T' => switch (stdout.items[j + 1]) {
                    ' ' => "38;2;210;105;30",
                    'D' => "38;2;240;128;128",
                    'M' => "38;2;255;215;0",
                    'T' => "38;2;205;133;63",
                    else => "",
                },
                else => "",
            };
            std.debug.print(
                "\x1b[{s}m{s}\x1b[0m ",
                .{ color, stdout.items[j + 3 .. i] },
            );
            j = i + 1;
        }
    }
    if (j != 0) std.debug.print("\n", .{});
}
