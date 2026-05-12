#include <stdio.h>
#include <stdint.h>
#include <math.h>

typedef union {
    float f;
    uint32_t bits;
} fp32;

void print_test(float a, float b, int expect_nan) {
    fp32 fa, fb, fr;
    fa.f = a;
    fb.f = b;
    fr.f = a * b;
    printf("%08X %08X %08X %d\n", fa.bits, fb.bits, fr.bits, expect_nan);
}

int main() {
    //normals
    print_test(1.0f,   2.0f, 0);
    print_test(-1.0f,  2.0f, 0);
    print_test(1.5f,   1.5f, 0);
    print_test(2.0f,   2.0f, 0);

    //zeros
    print_test(0.0f,   1.0f, 0);
    print_test(-0.0f,  1.0f, 0);
    print_test(0.0f,  -0.0f, 0);

    //infs
    print_test(INFINITY,  1.0f, 0);
    print_test(INFINITY, -1.0f, 0);
    print_test(-INFINITY, 1.0f, 0);

    //inf * 0 = nan
    print_test(INFINITY, 0.0f, 1);

    //nan propagation
    print_test(NAN, 1.0f, 0);

    //overflow
    print_test(3.4e38f, 2.0f, 0);

    //subnormals
    print_test(1.175494e-38f, 0.5f, 0);

    return 0;
}