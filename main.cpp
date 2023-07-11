#include <omp.h>
#include <zip.h>
#include <iostream>

int main() {

  omp_set_num_threads(20);

  zip_close(nullptr);

  std::cout<<"DLLDeployer!"<<std::endl;

  return 0;
}