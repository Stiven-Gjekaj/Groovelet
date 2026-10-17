// GLTest: a small test runner that operates on macOS and on iOS 6.
// Each test is a function that GL_TEST makes and registers at load time.

#import <Foundation/Foundation.h>

typedef void (*GLTestFunction)(void);

void GLTestRegister(const char *name, GLTestFunction function);
void GLTestFail(const char *file, int line, NSString *message);
void GLTestSkip(void);

#define GL_TEST(name)                                                         \
    static void name(void);                                                   \
    __attribute__((constructor)) static void name##_register(void) {          \
        GLTestRegister(#name, name);                                          \
    }                                                                         \
    static void name(void)

#define GL_EXPECT(condition)                                                  \
    do {                                                                      \
        if (!(condition)) GLTestFail(__FILE__, __LINE__, @"expected: " #condition); \
    } while (0)

#define GL_EQUAL(actual, expected)                                            \
    do {                                                                      \
        id gl_a = (actual), gl_e = (expected);                                \
        if (!(gl_a == gl_e || [gl_a isEqual:gl_e]))                           \
            GLTestFail(__FILE__, __LINE__, [NSString stringWithFormat:        \
                @"%s is <%@>, expected <%@>", #actual, gl_a, gl_e]);           \
    } while (0)

#define GL_EQUAL_INT(actual, expected)                                        \
    do {                                                                      \
        long long gl_a = (long long)(actual), gl_e = (long long)(expected);   \
        if (gl_a != gl_e)                                                     \
            GLTestFail(__FILE__, __LINE__, [NSString stringWithFormat:        \
                @"%s is %lld, expected %lld", #actual, gl_a, gl_e]);           \
    } while (0)

// Runs the run loop until done is YES or the time is over.
BOOL GLTestWait(BOOL *done, NSTimeInterval seconds);

// Makes a new empty directory for one test and returns its path.
NSString *GLTestTemporaryDirectory(void);
