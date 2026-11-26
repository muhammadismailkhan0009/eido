// Independent matched C baseline, same index ring or native pointer ring.
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
    assert(argc==5);
    size_t n=strtoull(argv[1],0,10), s=strtoull(argv[2],0,10);
    int random=atoi(argv[3]), pointer=atoi(argv[4]);
    uint64_t *d=calloc(n*s,8), *o=malloc(n*8);
    assert(d&&o);
    for(size_t i=0;i<n;i++)o[i]=i;
    uint32_t seed=42;
    if(random) for(size_t i=n-1;i>0;i--){
        seed=seed*1664525u+1013904223u;
        size_t j=seed%(i+1), t=o[i];o[i]=o[j];o[j]=t;
    }
    for(size_t i=0;i<n;i++){
        size_t a=o[i]*s,b=o[(i+1)%n]*s;
        d[a]=pointer?(uintptr_t)(d+b):b;
    }
    uint64_t first=o[0]*s;
    if(pointer)first=(uintptr_t)(d+first);
    free(o);
    uint64_t p=first;
    for(size_t i=0;i<n;i++){
        p=pointer?*(uint64_t*)(uintptr_t)p:d[p];
        assert(p!=first||i==n-1);
    }
    assert(p==first);
    size_t steps=(4000000/n+1)*n;
    for(int t=0;t<8;t++){
        uint64_t start=nanos();
        if(pointer)for(size_t i=0;i<steps;i++)p=*(uint64_t*)(uintptr_t)p;
        else for(size_t i=0;i<steps;i++)p=d[p];
        uint64_t elapsed=nanos()-start;
        assert(p==first);
        if(t)printf("%" PRIu64 "\n",elapsed);
    }
    free(d);puts("VALID");
}
