#include "Scene.cuh"

void Scene::draw() {
    if (!_shader) {
        throw runtime_error("Shader is null!");
    }

    _shader->useProgram();

    for (auto *geometry: _geometries) {
        geometry->render(this);
    }
}

void Scene::add(Geometry *geometry) {
    _geometries.push_back(geometry);
}

void Scene::add(initializer_list<Geometry *> list) {
    for (auto ptr: list) {
        add(ptr);
    }
}

Shader *Scene::getShader() {
    return _shader;
}

Camera &Scene::getCamera() {
    return _camera;
}

void Scene::setShader(Shader *shader) {
    _shader = shader;
}
