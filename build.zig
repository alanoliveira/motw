const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .x86,
        .os_tag = .windows,
    } });

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const zigwin32 = b.dependency("zigwin32", .{});

    const minhook = b.addStaticLibrary(.{
        .name = "minhook",
        .target = target,
        .optimize = optimize,
    });

    var minhook_src = [_][]const u8{
        "./vendor/minhook/src/buffer.c",
        "./vendor/minhook/src/hook.c",
        "./vendor/minhook/src/trampoline.c",
        "./vendor/minhook/src/hde/hde32.c",
        "./vendor/minhook/src/hde/hde64.c",
    };
    minhook.addCSourceFiles(.{
        .files = &minhook_src,
        .flags = &.{"-fno-sanitize=undefined"}, // without this option Minhook crashes when hooking some external function
    });
    minhook.linkLibC();
    b.installArtifact(minhook);

    const lib = b.addSharedLibrary(.{
        .name = "motw",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.addModule("zigwin32", zigwin32.module("zigwin32"));
    lib.addIncludePath(.{ .path = "./vendor/minhook/include/" });
    lib.linkLibrary(minhook);
    lib.addIncludePath(.{ .path = "./vendor/font8x8/" });
    lib.linkLibC();

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    const injector = b.addExecutable(.{
        .name = "motw",
        .root_source_file = .{ .path = "src/injector/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    injector.addModule("zigwin32", zigwin32.module("zigwin32"));
    injector.linkLibC();

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(injector);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(injector);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
