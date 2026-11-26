// Exact libstdc++ MT19937/distribution sequence from mimalloc-bench malloc-large.
// Trace generation is deliberately outside both timed variants.
#include <random>
#include <cstdio>
int main() {
  std::mt19937 gen(42);
  std::uniform_int_distribution<> slots(0,19), sizes(5*1024*1024,25*1024*1024);
  for (int i=0;i<2000;i++) {
    unsigned slot=slots(gen), size=sizes(gen);
    printf("%u %u\n",slot,size);
  }
}
