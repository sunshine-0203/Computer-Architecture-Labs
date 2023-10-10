#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <immintrin.h>

int N = (1 << 10);
int BLOCK_SIZE = 8;

void gemm_verify(float *A, float *B, float *C);
void gemm_avx_block(float *A, float *B, float *C);

int main(void)
{
    // malloc A, B, C
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
    gemm_avx_block(A, B, C);
    clock_t end = clock();
    double cpu_time_used = ((double)(end - start)) / CLOCKS_PER_SEC;
    printf("运行时间：%f秒\n", cpu_time_used);

    // use gemm_baseline verify gemm_avx_block
    gemm_verify(A, B, C);

    // free
    free(A);
    free(B);
    free(C);

    return 0;
}

void gemm_verify(float *A, float *B, float *C)
{
    float *baseline = (float *)malloc(N * N * sizeof(float));
    for (int i = 0; i < N * N; i++)
        baseline[i] = 0;
    for (int i = 0; i < N; i++)
    {
        for (int j = 0; j < N; j++)
        {
            for (int k = 0; k < N; k++)
            {
                baseline[i * N + j] += A[i * N + k] * B[k * N + j];
            }
        }
    }

    for (int i = 0; i < N * N; i++)
    {
        if (C[i] != baseline[i])
        {
            printf("fail: C[%d] = %f, baseline[%d] = %f\n", i, C[i], i, baseline[i]);
            break;
        }
    }
    free(baseline);
}

void gemm_avx_block(float *A, float *B, float *C)
{
    for (int si = 0; si < N; si += BLOCK_SIZE)
    {
        for (int sj = 0; sj < N; sj += BLOCK_SIZE)
        {
            for (int sk = 0; sk < N; sk += BLOCK_SIZE)
            {
                __m256 tmp;
                for (int i = si; i < si + BLOCK_SIZE; ++i)
                {
                    for (int j = sj; j < sj + BLOCK_SIZE; j += 8)
                    {
                        tmp = _mm256_loadu_ps(C + i * N + j);
                        for (int k = sk; k < sk + BLOCK_SIZE; ++k)
                        {
                            tmp = _mm256_add_ps(tmp, _mm256_mul_ps(_mm256_broadcast_ss(A + i * N + k), _mm256_loadu_ps(B + k * N + j)));
                            _mm256_storeu_ps(C + i * N + j, tmp);
                        }
                    }
                }
            }
        }
    }
}
