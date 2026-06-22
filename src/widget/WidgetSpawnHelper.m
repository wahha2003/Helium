#import <spawn.h>
#import <signal.h>
#import "WidgetSpawnHelper.h"

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

extern char **environ;

static NSString *HeliumExecutablePath(void) {
    NSString *appex = [[NSBundle mainBundle] bundlePath];
    NSString *app = [[appex stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    return [app stringByAppendingPathComponent:@"Helium"];
}

static posix_spawnattr_t RootSpawnAttr(void) {
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    posix_spawnattr_set_persona_uid_np(&attr, 0);
    posix_spawnattr_set_persona_gid_np(&attr, 0);
    return attr;
}

static BOOL IsHUDAlive(const char *exe) {
    posix_spawnattr_t attr = RootSpawnAttr();
    pid_t pid;
    const char *args[] = { exe, "-check", NULL };
    int rc = posix_spawn(&pid, exe, NULL, &attr, (char **)args, environ);
    posix_spawnattr_destroy(&attr);
    if (rc != 0) return NO;

    int status;
    waitpid(pid, &status, 0);
    return WIFEXITED(status) && WEXITSTATUS(status) != 0;
}

BOOL SpawnHUDIfNeeded(void) {
    NSString *exe = HeliumExecutablePath();
    if (![[NSFileManager defaultManager] fileExistsAtPath:exe]) return NO;
    const char *path = exe.UTF8String;

    if (IsHUDAlive(path)) return YES;

    posix_spawnattr_t attr = RootSpawnAttr();
    posix_spawnattr_setpgroup(&attr, 0);
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP);

    pid_t pid;
    const char *args[] = { path, "-hud", NULL };
    int rc = posix_spawn(&pid, path, NULL, &attr, (char **)args, environ);
    posix_spawnattr_destroy(&attr);
    return rc == 0;
}
