/*
 * The MIT License (MIT)
 * Copyright (c) 2011 GClue, inc.
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/*
 * Scene.cpp
 *
 *  Created on: 2011/09/15
 *      Author: GClue, Inc.
 */
#include "Scene.h"
#include "Layer.h"
#include "Log.h"

Scene::Scene(ApplicationController *controller) : IScene(controller) {
	LOGD("****Scene");
}

Scene::~Scene() {
	LOGD("****~Scene");
	// 各レイヤーの削除
	std::map<int, Layer*>::iterator it = layers.begin();
	while (it != layers.end()) {
		Layer *layer = (*it).second;
		delete layer;
		it++;
	}
}

// レイヤーを追加
void Scene::addLayer(int id, Layer *layer) {
	if(layers[id]) {
		delete layers[id];
	}
	layers[id] = layer;
}

// レイヤーを検索
Layer *Scene::getLayer(int id) {
	std::map<int, Layer*>::iterator it = layers.find(id);
	if (it!=layers.end()) {
		return (*it).second;
	} else {
		return NULL;
	}
}

//レイヤの削除
bool Scene::removeLayer(int id) {
	std::map<int, Layer*>::iterator it = layers.find(id);
	if (it != layers.end() ) {
		Layer *layer = (*it).second;
		delete layer;
		layers.erase(it);
		return true;
	}
	
	return false;
}


void Scene::removeAllLayers() {
	std::map<int, Layer*>::iterator it = layers.begin();
	while (it != layers.end()) {
		LOGD("remove");
		Layer *layer = (*it).second;
		delete layer;
		it++;
	}
	layers.clear();
}



/////////////////////////////////////////////////////////////
// IScene の実装
/////////////////////////////////////////////////////////////

// セットアップ処理を行います.
void Scene::setup() {
	LOGD("****Scene::setup()");
	// 各レイヤーの描画
	std::map<int, Layer*>::iterator it = layers.begin();
	while (it != layers.end()) {
		Layer *layer = (*it).second;
		layer->setup();
		it++;
	}
}

// リサイズ
void Scene::resize(int width, int height) {
	LOGD("****Scene::resize:%d-%d", width, height);

	// アスペクト比の計算
	float aspect = width / (float) height;
	// 各レイヤーのリサイズ
	std::map<int, Layer*>::iterator it = layers.begin();
	while (it != layers.end()) {
		Layer *layer = (*it).second;
		layer->resize(aspect);
		it++;
	}
}

// ステップ実行します
void Scene::step(float dt) {
	// 各レイヤーの描画
	std::map<int, Layer*>::iterator it = layers.begin();
	while (it != layers.end()) {
		Layer *layer = (*it).second;
		float t = dt;
		if (layer->pause) t = 0;
		layer->render(t);
		it++;
	}
}

// 活性化します.
void Scene::onActivate() {
	super::onActivate();
	LOGD("****Scene::onActivate");
}

// 休止します.
void Scene::onSuspend() {
	super::onSuspend();
	LOGD("****Scene::onSuspend");
}

// 活性化してシーンが切り替え終わったこと通知します.
void Scene::onStart() {
	super::onStart();
	LOGD("****Scene::onStart");
}

// 非活性化してシーンが切り替え始まったこと通知します.
void Scene::onEnd() {
	super::onEnd();
	LOGD("****Scene::onEnd");
}

// コンテキストが切り替わったことを通知します.
void Scene::onContextChanged() {
	LOGD("****Scene::onContextChanged");
	std::map<int, Layer*>::iterator it = layers.begin();
	while (it != layers.end()) {
		Layer *layer = (*it).second;
		layer->onContextChanged();
		it++;
	}
}

// バックキーイベント
bool Scene::onPressBackKey() {
	LOGD("****Scene::onPressBackKey");
	return false;
}

// タッチイベント
bool Scene::onTouch(TouchEvent &event) {
	LOGD("****Scene::onTouch");
	if (layers.size()==0) return false;
	std::map<int, Layer*>::iterator it = layers.end();
	it--;
	while (true) {
		Layer *layer = (*it).second;
		if (layer->onTouch(event)) {
			return true;
		}
		if(it == layers.begin()) {
			break;
		}
		it--;
	}
	return false;
}
