#ifndef GAUSSIAN_RASTERIZER_SCENE_CUH
#define GAUSSIAN_RASTERIZER_SCENE_CUH


#include "Geometry.cuh"

class Scene {
public:
    explicit Scene(const Shader &shader);

    void draw();

    void add(Geometry *geometry);

private:
    Shader shader;
    vector<Geometry*> geometries;
};


#endif //GAUSSIAN_RASTERIZER_SCENE_CUH
