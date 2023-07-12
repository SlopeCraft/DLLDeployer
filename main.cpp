#include <omp.h>
#include <zip.h>
#include <iostream>
#include <QCoreApplication>

int main(int argc,char**argv) {

  QCoreApplication qapp{argc,argv};

  omp_set_num_threads(20);

  zip_close(nullptr);

  std::cout<<"DLLDeployer!"<<std::endl;

  return 0;
}