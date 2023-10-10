#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int N = (1 << 8);

void gemm_baseline(float *A, float *B, float *C);

int main(void)
{
    //  malloc A, B, C
    float *A = (float *)malloc(N * N * sizeof(float));
    float *B = (float *)malloc(N * N * sizeof(float));
    float *C = (float *)malloc(N * N * sizeof(float));

    // random initialize A, B
    srand(time(NULL));
    for (int i = 0; i < N * N; i++)
    {
        A[i] = (float)(rand() % 100) / 100.0;
        B[i] = (float)(rand() % 100) / 100.0;
    }

    // measure time
    clock_t start = clock();
    gemm_baseline(A, B, C);
    clock_t end = clock();
    double cpu_time_used = ((double)(end - start)) / CLOCKS_PER_SEC;
    printf("运行时间：%f秒\n", cpu_time_used);

    // free A, B, C
    free(A);
    free(B);
    free(C);

    return 0;
}

void gemm_baseline(float *A, float *B, float *C)
{
    for (int i = 0; i < N; i++)
    {
        for (int j = 0; j < N; j++)
        {
            for (int k = 0; k < N; k++)
            {
                C[i * N + j] += A[i * N + k] * B[k * N + j];
            }
        }
    }
}
