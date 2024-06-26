#ifndef GAUSSIAN_RASTERIZER_GEOMETRY_CUH
#define GAUSSIAN_RASTERIZER_GEOMETRY_CUH


#include "../Shader.cuh"
#include "../world/Transform.cuh"
#include "../world/Scene.cuh"
#include "../world/Camera.cuh"

class Scene;

class Geometry {
public:
    Geometry(const GLfloat *vertexArray, GLsizeiptr vertexSize, GLsizei vertexCount, bool normals);

    void render(Scene *scene);

    Transform &getTransform();

    mat4 &getModel();

    virtual vec3 getColor();

protected:
    const GLfloat *vertexArray;
    GLsizeiptr vertexSize;
    GLsizei vertexCount;
    GLuint VAO = 0;
    GLuint VBO = 0;
    float *cpuVertexArray = nullptr;
    float *cudaVertexArray = nullptr;

    virtual void bind(Device engine);

    virtual void draw() = 0;

private:
    Transform _transform;
    bool _useNormals;
    bool _isBound = false;
    mat4 *_model = nullptr;

    void resetModel();

    void updateShader(Scene *scene);

    void processVertex(Scene *scene);

    void processVertexOpenMP(Scene *scene);

    void processVertexCuda(Scene *scene);

    static void cudaCheckError(cudaError_t err);
};


#endif //GAUSSIAN_RASTERIZER_GEOMETRY_CUH
