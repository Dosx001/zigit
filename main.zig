const std = @import("std");
const git = @cImport(@cInclude("git2.h"));

pub fn main() !void {
    _ = git.git_libgit2_init();
    var repo: ?*git.git_repository = undefined;
    _ = git.git_repository_open(&repo, ".");
    std.debug.print("{?}\n", .{repo});
    var statuses: ?*git.git_status_list = undefined;
    _ = git.git_status_list_new(&statuses, repo, null);
    var len = git.git_status_list_entrycount(statuses);
    std.debug.print("{}", .{len});
    _ = git.git_libgit2_shutdown();
    return;
}
