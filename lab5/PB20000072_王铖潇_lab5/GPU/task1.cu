#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <curand.h>

#define N (1 << 8)

__global__ void gemm_baseline(float *A, float *B, float *C)
{
    // Compute matrix multiplication
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    float sum = 0.0f;
    for (int k = 0; k < N; ++k)
    {
        sum += A[row * N + k] * B[k * N + col];
    }
    C[row * N + col] = sum;
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
        if (abs(C[i] - baseline[i]) > 1e-3)
        {
            printf("fail: C[%d] = %f, baseline[%d] = %f\n", i, C[i], i, baseline[i]);
            break;
        }
    }
    free(baseline);
}

int main()
{
    float *A;
    float *B;
    float *C;

    // malloc A, B, C
    A = (float *)malloc(N * N * sizeof(float));
    B = (float *)malloc(N * N * sizeof(float));
    C = (float *)malloc(N * N * sizeof(float));

    // random initialize A, B
    for (int i = 0; i < N * N; ++i)
    {
        A[i] = (float)rand() / RAND_MAX;
        B[i] = (float)rand() / RAND_MAX;
    }

    // cumalloc A, B, C
    float *cu_A;
    float *cu_B;
    float *cu_C;
    cudaMalloc((void **)&cu_A, N * N * sizeof(float));
    cudaMalloc((void **)&cu_B, N * N * sizeof(float));
    cudaMalloc((void **)&cu_C, N * N * sizeof(float));

    // copy from CPU to GPU
    cudaMemcpy(cu_A, A, N * N * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(cu_B, B, N * N * sizeof(float), cudaMemcpyHostToDevice);

    // define gridsize and blocksize
    dim3 blocksize(4, 4);
    dim3 gridsize((N + blocksize.x - 1) / blocksize.x, (N + blocksize.y - 1) / blocksize.y);

    // compute
    clock_t start_time = clock();
    gemm_baseline<<<gridsize, blocksize>>>(cu_A, cu_B, cu_C);
    clock_t end_time = clock();
    double cpu_time_used = ((double)(end_time - start_time)) / CLOCKS_PER_SEC;
    printf("运行时间：%f秒\n", cpu_time_used);

    // Copy from GPU to CPU
    cudaMemcpy(C, cu_C, N * N * sizeof(float), cudaMemcpyDeviceToHost);

    // verify the result
    gemm_verify(A, B, C);

    // free mem
    cudaFree(cu_A);
    cudaFree(cu_B);
    cudaFree(cu_C);

    free(A);
    free(B);
    free(C);

    return 0;
}
