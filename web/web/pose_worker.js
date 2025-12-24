importScripts('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-core');
importScripts('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-backend-cpu');
importScripts('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-tflite@0.0.1-alpha.9/dist/tf-tflite.min.js');

let movenetModel;
let classifierModel;
let labels = [];

self.onmessage = async (e) => {
    const { type, payload } = e.data;

    if (type === 'load') {
        const log = (msg) => self.postMessage({ type: 'log', payload: msg });
        try {
            log('Worker: 正在加載模型...');
            tflite.setWasmPath('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-tflite@0.0.1-alpha.9/dist/');

            // 從 Dart 接收配置
            const config = payload;
            const modelPath = config.modelPath;
            const classifierPath = config.classifierPath;
            const labelsPath = config.labelsPath;

            log('Worker: 已收到 Dart 配置');
            log('Worker: 模型路徑: ' + modelPath);

            // 加載 MoveNet (Thunder)
            log('Worker: 正在加載 MoveNet 模型: ' + modelPath);
            movenetModel = await tflite.loadTFLiteModel(modelPath);
            log('Worker: MoveNet 模型加載完成');

            // 加載分類器 (可選)
            try {
                log('Worker: 正在加載分類器模型: ' + classifierPath);
                classifierModel = await tflite.loadTFLiteModel(classifierPath);
                log('Worker: 分類器模型加載完成');
            } catch (classifierErr) {
                log('Worker 警告: 分類器加載失敗 (' + classifierErr.toString() + '). 將僅使用 MoveNet 繼續運行。');
                classifierModel = null;
            }

            // 加載標籤 (可選)
            if (classifierModel) {
                try {
                    log('Worker: 正在加載標籤: ' + labelsPath);
                    const response = await fetch(labelsPath);
                    const text = await response.text();
                    labels = text.split('\n').map(s => s.trim()).filter(s => s.length > 0);
                    log('Worker: 標籤加載完成');
                } catch (labelErr) {
                    log('Worker 警告: 標籤加載失敗，將使用原始索引。');
                }
            }

            log('Worker: 模型全部加載成功！分類器狀態: ' + (classifierModel ? '啟用' : '已停用'));
            self.postMessage({ type: 'loaded' });
        } catch (err) {
            log('Worker 錯誤詳細資訊: ' + err.toString());
            self.postMessage({ type: 'error', payload: '模型加載嚴重失敗: ' + err.toString() });
        }
    } else if (type === 'process') {
        if (!movenetModel) return;

        try {
            const { imageData, width, height } = payload;
            // 1. MoveNet 預處理
            // 從像素數據創建張量 (RGBA)
            const inputTensor = tf.tensor3d(new Uint8Array(imageData), [height, width, 4], 'int32');

            // 1. 計算填充量 (Padding)
            const size = Math.max(height, width);
            const padHeight = size - height;
            const padWidth = size - width;

            const padTop = Math.floor(padHeight / 2);
            const padBottom = padHeight - padTop;
            const padLeft = Math.floor(padWidth / 2);
            const padRight = padWidth - padLeft;

            // 2. 應用填充
            const paddedContext = tf.pad(inputTensor, [
                [padTop, padBottom],
                [padLeft, padRight],
                [0, 0]
            ]);

            // 3. 調整大小為 256x256
            const resized = tf.image.resizeBilinear(paddedContext, [256, 256]);

            // 4. 切片並擴展維度
            const rgb = tf.slice(resized, [0, 0, 0], [256, 256, 3]);
            // 嘗試轉換為 int32 (MoveNet Thunder 標準輸入)
            const batched = tf.expandDims(tf.cast(rgb, 'int32'), 0);

            // 執行 MoveNet
            const movenetOutput = movenetModel.predict(batched);

            if (!movenetOutput) {
                throw new Error("MoveNet 預測返回 null");
            }

            const keypoints = await movenetOutput.array();

            // 檢查輸出形狀
            if (!keypoints || keypoints.length === 0 || !keypoints[0] || !keypoints[0][0]) {
                throw new Error("無效的關鍵點形狀: " + JSON.stringify(keypoints));
            }

            // 偵錯：記錄高信心分數的關鍵點
            const rawKpsDebug = keypoints[0][0];
            let detectedParts = [];
            const partNames = [
                '鼻子', '左眼', '右眼', '左耳', '右耳',
                '左肩', '右肩', '左肘', '右肘',
                '左腕', '右腕', '左臀', '右臀',
                '左膝', '右膝', '左踝', '右踝'
            ];

            // 重新映射座標
            const rawKps = rawKpsDebug.map(kp => {
                const y_256 = kp[0];
                const x_256 = kp[1];
                const score = kp[2];

                // 還原座標
                const y_px = y_256 * 256;
                const x_px = x_256 * 256;
                const scale = size / 256;
                const y_pad = y_px * scale;
                const x_pad = x_px * scale;
                const y_orig = y_pad - padTop;
                const x_orig = x_pad - padLeft;

                return [
                    y_orig / height,
                    x_orig / width,
                    score
                ];
            });

            for (let i = 0; i < 17; i++) {
                if (rawKps[i][2] > 0.2) {
                    detectedParts.push(`${partNames[i]}(${rawKps[i][2].toFixed(2)})`);
                }
            }
            if (detectedParts.length > 0) {
                self.postMessage({ type: 'log', payload: 'Worker 偵測到: ' + detectedParts.join(', ') });
            }

            // 準備分類器數據
            const classifierInput = [];
            for (let i = 0; i < 17; i++) {
                classifierInput.push(rawKps[i][1]); // x
                classifierInput.push(rawKps[i][0]); // y
                classifierInput.push(rawKps[i][2]); // score
            }

            // 執行分類器
            let label = '未知';
            let maxScore = 0.0;

            if (classifierModel) {
                try {
                    const classifierTensor = tf.tensor2d([classifierInput], [1, 51]);
                    const classifierOutput = classifierModel.predict(classifierTensor);
                    const scores = await classifierOutput.data();

                    let maxIndex = -1;
                    for (let i = 0; i < scores.length; i++) {
                        if (scores[i] > maxScore) {
                            maxScore = scores[i];
                            maxIndex = i;
                        }
                    }
                    if (labels.length > 0 && maxIndex >= 0 && maxIndex < labels.length) {
                        label = labels[maxIndex];
                    }
                    classifierTensor.dispose();
                    classifierOutput.dispose();
                } catch (clsErr) {
                    // 忽略分類器錯誤
                }
            }

            // 清理張量
            inputTensor.dispose();
            paddedContext.dispose();
            resized.dispose();
            rgb.dispose();
            batched.dispose();
            movenetOutput.dispose();

            // 傳回結果
            self.postMessage({
                type: 'result',
                payload: {
                    keypoints: rawKps,
                    label: label,
                    score: maxScore
                }
            });
        } catch (processErr) {
            self.postMessage({ type: 'log', payload: 'Worker 處理錯誤: ' + processErr.toString() });
        }
    }
};
