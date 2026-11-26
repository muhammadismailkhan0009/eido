// Single-worker cache-scratch-derived workload, independently implemented.
// Volatile accesses keep the memory workload real (the upstream C++
// optimizer otherwise removes the allocations and heap touches).
#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <assert.h>
#include <inttypes.h>
static uint64_t nanos(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t);
    return (uint64_t)t.tv_sec*1000000000+t.tv_nsec;
}
int main(int argc,char **argv) {
    assert(argc==3);
    uint64_t size=strtoull(argv[1],0,10), count=strtoull(argv[2],0,10);
    uint64_t sum=0, start=nanos();
    for(uint64_t i=0;i<count;i++){
        volatile unsigned char *p=calloc(size,1);
        assert(p);
        for(uint64_t k=0;k<size;k++){
            p[k]=(unsigned char)k;
            sum+=p[k];
        }
        free((void*)p);
    }
    uint64_t elapsed=nanos()-start;
    assert(sum==count*size*(size-1)/2);
    printf("%" PRIu64 "\n%" PRIu64 "\nVALID\n",elapsed,sum);
}
