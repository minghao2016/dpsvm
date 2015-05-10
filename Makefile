
EXECUTABLE := svmTrain

CU_FILES   := svmTrain.cu

CU_DEPS    :=

CC_FILES   := main.cpp

LOGS	   := logs

###########################################################

ARCH=$(shell uname | sed -e 's/-.*//g')
OBJDIR=objs

CXX=/usr/lib64/openmpi/bin/mpic++
MPIRUN=/usr/lib64/openmpi/bin/mpirun
export LD_LIBRARY_PATH=/usr/local/cuda/lib64/:/usr/local/cuda/lib:/usr/lib64/openmpi/lib:$(shell printenv LD_LIBRARY_PATH)

mpi:=$(shell which mpic++ 2>/dev/null)
ifeq ($(mpi),)
  $(error "mpic++ not found - did you set your environment variables or load the module?")
endif

#CXX=g++ -m64
CXXFLAGS=-O3 -Wall -g -std=c++0x

LIBS       :=
FRAMEWORKS := 

ifeq ($(ARCH), Darwin)
# Building on mac
NVCCFLAGS=-O3 -m64 -arch compute_10
FRAMEWORKS += OpenGL GLUT
LDFLAGS=-L/usr/local/cuda/lib/ -lcudart
else
# Building on Linux
NVCCFLAGS=-O3 -m64 -arch compute_20
LIBS += GL cudart
LDFLAGS=-L/usr/local/cuda/lib64/ -lcudart
CUDA_INCFLAGS=-I/usr/local/cuda/include
BLAS_INCFLAGS=-I/home/siddhar2/blas/CBLAS/include/  
BLAS_LDFLAGS=-L/home/siddhar2/blas/BLAS -L/home/siddhar2/blas/CBLAS/lib -lcblas -lblas -lm -L/usr/lib64 -l:libgfortran.so.3.0.0 -lcublas
MPI_LDFLAGS=-lpthread -lmpi -lmpi_cxx
endif

LDLIBS  := $(addprefix -l, $(LIBS))
LDFRAMEWORKS := $(addprefix -framework , $(FRAMEWORKS))

NVCC=nvcc

OBJS=$(OBJDIR)/svmTrain.o $(OBJDIR)/parse.o $(OBJDIR)/svmTrainMain.o
SAMPLE_OBJS=$(OBJDIR)/mpi_sample.o
SEQ_OBJS=$(OBJDIR)/seq.o

.PHONY: dirs clean

default: $(EXECUTABLE)

dirs:
		mkdir -p $(OBJDIR)/

clean:
		rm -rf $(OBJDIR) *~ $(EXECUTABLE) mpi_sample seq  $(LOGS)

run_old:
	LD_LIBRARY_PATH=$(LD_LIBRARY_PATH) $(MPIRUN) --hostfile host_file -np 6 $(EXECUTABLE) -s 10000000 -d norm -p 5

run: $(EXECUTABLE)
	LD_LIBRARY_PATH=$(LD_LIBRARY_PATH) ./$(EXECUTABLE) --num-att 123 --num-ex 32561 -c 100 -g 0.5 -e 0.01  -f ~/AFS/private/618/git_project/data/adult/8/train_conv.csv -m model.txt --max-iter 100000

run_sample: mpi_sample
	LD_LIBRARY_PATH=$(LD_LIBRARY_PATH) $(MPIRUN) -np 6 mpi_sample -s 10000000 -d norm -p 5

run_seq: seq
	LD_LIBRARY_PATH=$(LD_LIBRARY_PATH) ./seq --num-att 123 --num-ex 32561 -c 100 -g 0.5 -e 0.01 -f ../data/adult/8/train_conv.csv --max-iter 20

mpi_sample: dirs $(SAMPLE_OBJS)
		$(CXX) $(CXXFLAGS) $(MPI_LDFLAGS) -o $@ $(SAMPLE_OBJS) $(LDFLAGS) $(LDLIBS) $(LDFRAMEWORKS) $(BLAS_LDFLAGS)

seq: dirs $(SEQ_OBJS)
		$(CXX) $(CXXFLAGS) $(MPI_LDFLAGS) -o $@ $(SEQ_OBJS) $(LDFLAGS) $(LDLIBS) $(LDFRAMEWORKS) $(BLAS_LDFLAGS)

$(EXECUTABLE): dirs $(OBJS)
		$(NVCC) $(NVCCFLAGS) -o $@ $(OBJS) $(LDFLAGS) $(LDLIBS) $(LDFRAMEWORKS) $(BLAS_LDFLAGS)

$(OBJDIR)/%.o: %.c
		$(CXX) $< $(CXXFLAGS) -c -o $@

$(OBJDIR)/%.o: %.cpp
		$(CXX) $< $(CXXFLAGS) -c -o $@ $(BLAS_INCFLAGS) $(CUDA_INCFLAGS) $(LDFLAGS) $(LDLIBS) $(LDFRAMEWORKS) $(BLAS_LDFLAGS)

$(OBJDIR)/%.o: %.cu
		$(NVCC) $< $(NVCCFLAGS) -c -o $@ $(BLAS_INCFLAGS) $(LDFLAGS) $(LDLIBS) $(LDFRAMEWORKS) $(BLAS_LDFLAGS)