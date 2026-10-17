// cpu: measure the CPU use of the processes with a name, over a time.
// It reads the CPU time of each process at the start and at the end.
// Usage: cpu SECONDS NAME [NAME ...]
// Run it as root, so that it can read each process.

#import <Foundation/Foundation.h>
#include <mach/mach_time.h>
#include <sys/sysctl.h>
#include <unistd.h>

// From libproc.h, which the iOS SDK does not have.
#define PROC_PIDTASKINFO 4
struct proc_taskinfo {
    uint64_t pti_virtual_size;
    uint64_t pti_resident_size;
    uint64_t pti_total_user;
    uint64_t pti_total_system;
    uint64_t pti_threads_user;
    uint64_t pti_threads_system;
    int32_t pti_policy;
    int32_t pti_faults;
    int32_t pti_pageins;
    int32_t pti_cow_faults;
    int32_t pti_messages_sent;
    int32_t pti_messages_received;
    int32_t pti_syscalls_mach;
    int32_t pti_syscalls_unix;
    int32_t pti_csw;
    int32_t pti_threadnum;
    int32_t pti_numrunning;
    int32_t pti_priority;
};
int proc_pidinfo(int pid, int flavor, uint64_t arg, void *buffer, int size);

static pid_t GLFindProcess(const char *name) {
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    size_t size = 0;
    if (sysctl(mib, 4, NULL, &size, NULL, 0) != 0) return -1;
    struct kinfo_proc *list = malloc(size);
    if (sysctl(mib, 4, list, &size, NULL, 0) != 0) {
        free(list);
        return -1;
    }
    pid_t found = -1;
    for (size_t i = 0; i < size / sizeof(struct kinfo_proc); i++) {
        if (strncmp(list[i].kp_proc.p_comm, name, MAXCOMLEN) == 0) found = list[i].kp_proc.p_pid;
    }
    free(list);
    return found;
}

// The CPU time of the process in seconds, or -1.
static double GLCPUTime(pid_t pid) {
    struct proc_taskinfo info;
    if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, sizeof(info)) != sizeof(info)) return -1;
    // The values are in Mach ticks on iOS 6, not in nanoseconds. A test with
    // a busy loop showed 2.4% before this change.
    mach_timebase_info_data_t base;
    mach_timebase_info(&base);
    return (double)(info.pti_total_user + info.pti_total_system) * base.numer / base.denom / 1e9;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 3) {
            fprintf(stderr, "usage: cpu SECONDS NAME [NAME ...]\n");
            return 2;
        }
        double seconds = atof(argv[1]);
        int count = argc - 2;
        pid_t pids[count];
        double start[count];
        for (int i = 0; i < count; i++) {
            pids[i] = GLFindProcess(argv[i + 2]);
            start[i] = pids[i] > 0 ? GLCPUTime(pids[i]) : -1;
        }
        NSDate *begin = [NSDate date];
        usleep((useconds_t)(seconds * 1e6));
        double elapsed = -[begin timeIntervalSinceNow];
        for (int i = 0; i < count; i++) {
            double end = pids[i] > 0 ? GLCPUTime(pids[i]) : -1;
            if (start[i] < 0 || end < 0) {
                printf("%s: not found\n", argv[i + 2]);
                continue;
            }
            printf("%s: %.1f%% of one core (%.2f s of CPU in %.1f s)\n", argv[i + 2],
                   100 * (end - start[i]) / elapsed, end - start[i], elapsed);
        }
    }
    return 0;
}
