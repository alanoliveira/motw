const std = @import("std");
const game = @import("game.zig");
const settings = @import("settings.zig");

pub fn run() void {
    var p1 = game.p1;
    var p2 = game.p2;
    var match = game.match;

    match.setTimer(game.Match.MAX_TIME);

    if (p1.getStatus().isNeutral() and p2.getStatus().isNeutral()) {
        playerCheats(&p1, settings.p1_settings);
        playerCheats(&p2, settings.p2_settings);
    }
}

fn playerCheats(player: *game.Player, player_settings: settings.PlayerSettings) void {
    if (player_settings.health) |val| player.setHealth(val);
    if (player_settings.power) |val| player.setPower(val);
    if (player_settings.guard) |val| player.setGuard(val);
    if (player_settings.top) |val| player.setTop(val);
}
