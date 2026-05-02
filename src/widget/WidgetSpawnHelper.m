#import <spawn.h>
#import <signal.h>
#import "WidgetSpawnHelper.h"

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

extern char **environ;

static NSString *GetHeliumExecutablePath(void) {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    // HeliumWidget.appex is at Helium.app/PlugIns/HeliumWidget.appex
    NSString *appPath = [[bundlePath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    return [appPath stringByAppendingPathComponent:@"Helium"];
}

BOOL WidgetIsHUDRunning(void) {
    NSString *executablePath = GetHeliumExecutablePath();
    if (![[NSFileManager defaultManager] fileExistsAtPath:executablePath]) {
        return NO;
    }

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    posix_spawnattr_set_persona_uid_np(&attr, 0);
    posix_spawnattr_set_persona_gid_np(&attr, 0);

    pid_t task_pid;
    const char *args[] = { executablePath.UTF8String, "-check", NULL };
    int spawnResult = posix_spawn(&task_pid, executablePath.UTF8String, NULL, &attr, (char **)args, environ);
    posix_spawnattr_destroy(&attr);

    if (spawnResult != 0) {
        return NO;
    }

    int status;
    do {
        if (waitpid(task_pid, &status, 0) != -1) {}
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));

    // -check returns EXIT_FAILURE (non-zero) when HUD IS running
    return WEXITSTATUS(status) != 0;
}

void WidgetLaunchHUD(void) {
    NSString *executablePath = GetHeliumExecutablePath();
    if (![[NSFileManager defaultManager] fileExistsAtPath:executablePath]) {
        return;
    }

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    posix_spawnattr_set_persona_uid_np(&attr, 0);
    posix_spawnattr_set_persona_gid_np(&attr, 0);
    posix_spawnattr_setpgroup(&attr, 0);
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP);

    pid_t task_pid;
    const char *args[] = { executablePath.UTF8String, "-hud", NULL };
    posix_spawn(&task_pid, executablePath.UTF8String, NULL, &attr, (char **)args, environ);
    posix_spawnattr_destroy(&attr);
}

BOOL WidgetGetAutoStartEnabled(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:
        @"/var/mobile/Library/Preferences/com.leemin.helium.plist"];
    NSNumber *value = prefs[@"autoStartHUD"];
    return value ? [value boolValue] : NO;
}
