#include "Geometry.cuh"
#include "glm/glm.hpp"
#include "Model.cuh"
#include <vector_types.h>
#include <vector_functions.h>
#include <cuda_runtime.h>
#include <cuda_gl_interop.h>

Geometry::Geometry(const GLfloat *vertexArray, GLsizeiptr vertexSize, GLsizei vertexCount, bool normals) :
        vertexArray(vertexArray),
        vertexSize(vertexSize),
        vertexCount(vertexCount),
        _useNormals(normals) {
    _transform.setUpdateCallback([this] { resetModel(); });
}

void Geometry::bind(Device engine) {
    if (_isBound) return;

    _isBound = true;
    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);
    glGenBuffers(1, &VBO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, vertexSize, vertexArray, GL_STATIC_DRAW);

    if (_useNormals) {
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), nullptr);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), nullptr);
        glEnableVertexAttribArray(1);
    } else {
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), nullptr);
        glEnableVertexAttribArray(0);
    }

//    if (engine == CUDA) {
//        cudaCheckError(cudaMalloc(&cudaVertexArray, vertexSize));
//        cudaCheckError(cudaMemcpy(cudaVertexArray, vertexArray, vertexSize, cudaMemcpyHostToDevice));
//    } else if (engine == CPU) {
//        cpuVertexArray = static_cast<float *>(malloc(vertexSize));
//        memcpy(cpuVertexArray, vertexArray, vertexSize);
//    }
//
//    if (dynamic_cast<Model*>(this)) {
//        printf("H[%d] %.3f %.3f %.3f\n", 0, vertexArray[0], vertexArray[1], vertexArray[2]);
//    }
}

vec3 Geometry::getColor() {
    return {1.0f, 1.0f, 1.0f};
}

void Geometry::render(Scene *scene) {
    bind(scene->getShader()->getDevice());
    updateShader(scene);
    // todo: external pipeline is unstable
//    processVertex(scene);
    draw();
}

void Geometry::updateShader(Scene *scene) {
    Shader *shader = scene->getShader();
    Camera &camera = scene->getCamera();
    vec3 color = getColor();
//    bool decouple = shader->getDevice() != OpenGL;

    shader->useProgram();

//    if (!decouple) {
        mat4 &model = getModel();
        mat4 &view = camera.getView();
        mat4 &projection = camera.getProjection();
        shader->setUniformMatrix(glUniformMatrix4fv, "model", false, model);
        shader->setUniformMatrix(glUniformMatrix4fv, "view", false, view);
        shader->setUniformMatrix(glUniformMatrix4fv, "projection", false, projection);
//    }

//    shader->setUniform("decouple", decouple);
    shader->setUniform("color", color.x, color.y, color.z);
}

void Geometry::processVertex(Scene *scene) {
    Device engine = scene->getShader()->getDevice();

    switch (engine) {
        case CUDA:
            processVertexCuda(scene);
            break;
        case CPU:
            processVertexOpenMP(scene);
            break;
    }
}

Transform &Geometry::getTransform() {
    return _transform;
}

mat4 &Geometry::getModel() {
    if (_model) {
        return *_model;
    }

    static auto unitX = vec3(1.0f, 0.0f, 0.0f);
    static auto unitY = vec3(0.0f, 1.0f, 0.0f);
    static auto unitZ = vec3(0.0f, 0.0f, 1.0f);
    const vec3 &rotation = _transform.getRotation();
    _model = new mat4(1.0f);
    mat4 &model = *_model;
    model = glm::translate(model, _transform.getPosition());
    model = glm::rotate(model, radians(rotation.x), unitX);
    model = glm::rotate(model, radians(rotation.y), unitY);
    model = glm::rotate(model, radians(rotation.z), unitZ);
    model = glm::scale(model, _transform.getScale());
    return model;
}

void Geometry::resetModel() {
    if (_model) {
        free(_model);
        _model = nullptr;
    }
}

__global__ void transformFromKernel(const float *d_vertices, const float *d_transform, float *d_result, int vertexCount, bool model) {
    unsigned int vertexIndex = blockIdx.x * blockDim.x + threadIdx.x;

    if (vertexIndex < vertexCount) {
        unsigned int idx = vertexIndex * 3;
        float4 pos = make_float4(d_vertices[idx], d_vertices[idx + 1], d_vertices[idx + 2], 1.0f);
        float4 result;

        result.x = d_transform[0] * pos.x + d_transform[4] * pos.y + d_transform[8] * pos.z + d_transform[12] * pos.w;
        result.y = d_transform[1] * pos.x + d_transform[5] * pos.y + d_transform[9] * pos.z + d_transform[13] * pos.w;
        result.z = d_transform[2] * pos.x + d_transform[6] * pos.y + d_transform[10] * pos.z + d_transform[14] * pos.w;
        result.w = d_transform[3] * pos.x + d_transform[7] * pos.y + d_transform[11] * pos.z + d_transform[15] * pos.w;

//        result.x = d_transform[0] * pos.x + d_transform[1] * pos.y + d_transform[2] * pos.z + d_transform[3] * pos.w;
//        result.y = d_transform[4] * pos.x + d_transform[5] * pos.y + d_transform[6] * pos.z + d_transform[7] * pos.w;
//        result.z = d_transform[8] * pos.x + d_transform[9] * pos.y + d_transform[10] * pos.z + d_transform[11] * pos.w;
//        result.w = d_transform[12] * pos.x + d_transform[13] * pos.y + d_transform[14] * pos.z + d_transform[15] * pos.w;

        d_result[idx] = result.x;
        d_result[idx + 1] = result.y;
        d_result[idx + 2] = result.z;

        if (model && vertexIndex == 0) {
            printf("K[%d] %.3f %.3f %.3f\n", vertexIndex, d_vertices[0], d_vertices[1], d_vertices[2]);
            printf("K[%d] %.3f %.3f %.3f\n", vertexIndex, d_result[0], d_result[1], d_result[2]);
        }
    }
}

void Geometry::processVertexOpenMP(Scene *scene) {
    Camera &camera = scene->getCamera();
    mat4 &model = getModel();
    mat4 &view = camera.getView();
    mat4 &proj = camera.getProjection();
    mat4 transform = proj * view * model;

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    float *vertices = cpuVertexArray;
    auto *pos = static_cast<GLfloat *>(glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE));

    // todo seems to crash the app
    for (int i = 0; i < vertexCount; ++i) {
        vec4 vertex(vertices[i * 3], vertices[i * 3 + 1], vertices[i * 3 + 2], 1.0f);
        vec4 result = transform * vertex;
        pos[i * 3] = result.x;
        pos[i * 3 + 1] = result.y;
        pos[i * 3 + 2] = result.z;
    }

    glUnmapBuffer(GL_ARRAY_BUFFER);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

void Geometry::processVertexCuda(Scene *scene) {
    cudaGraphicsResource *cudaVBO;
    cudaGraphicsGLRegisterBuffer(&cudaVBO, VBO, cudaGraphicsRegisterFlagsNone);
    cudaGraphicsMapResources(1, &cudaVBO, nullptr);

    // todo: restore VBO if CUDA pipeline is disabled
    Camera &camera = scene->getCamera();
    mat4 &model = getModel();
    mat4 &view = camera.getView();
    mat4 &proj = camera.getProjection();
//    mat4 h_transform = proj * view * model;
    mat4 h_transform = glm::transpose(proj * view * model);

    // device memory allocation
    float *d_transform, *d_vertices;
    cudaGraphicsResourceGetMappedPointer(reinterpret_cast<void **>(&d_vertices), nullptr, cudaVBO);
    cudaCheckError(cudaMalloc(&d_transform, sizeof(float) * 16));

    // host to device
    cudaCheckError(cudaMemcpy(d_transform, glm::value_ptr(h_transform), 16 * sizeof(float), cudaMemcpyHostToDevice));

    dim3 blockSize(256);
    dim3 gridSize((vertexCount + blockSize.x - 1) / blockSize.x);
    transformFromKernel<<<gridSize, blockSize>>>(cudaVertexArray, d_transform, d_vertices, vertexCount, dynamic_cast<Model*>(this) != nullptr);
    cudaDeviceSynchronize();

    // release memory
    cudaCheckError(cudaFree(d_transform));
    cudaGraphicsUnregisterResource(cudaVBO);
}

void Geometry::cudaCheckError(cudaError_t err) {
    if (err != cudaSuccess) {
        std::cerr << "CUDA error: " << cudaGetErrorString(err) << std::endl;
        exit(EXIT_FAILURE);
    }
}
