# Compiler and flags
CC = gcc
CFLAGS = -march=native -mavx

# Source files
SRCS = task1.cpp task2.cpp task3.cpp

# Executable names
EXES = task1 task2 task3

all: $(EXES)

$(EXES): $(SRCS)
	$(CC) $(CFLAGS) $@.cpp -o $@

clean:
	rm -f $(EXES)
