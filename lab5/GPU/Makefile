# Compiler and flags
CC = nvcc
CFLAGS =

# Source files
SRCS = task1.cu task2.cu

# Executable names
EXES = task1 task2

all: $(EXES)

$(EXES): $(SRCS)
	$(CC) $(CFLAGS) $@.cu -o $@

clean:
	rm -f $(EXES)
