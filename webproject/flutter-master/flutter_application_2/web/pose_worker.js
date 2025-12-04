importScripts('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-core');
importScripts('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-backend-cpu');
importScripts('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-tflite/dist/tf-tflite.min.js');

let movenetModel;
let classifierModel;
let labels = [];

self.onmessage = async (e) => {
    const { type, payload } = e.data;

    if (type === 'load') {
        try {
            console.log('Worker: Loading models...');
            tflite.setWasmPath('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-tflite/dist/');

            // Load MoveNet (Thunder)
            movenetModel = await tflite.loadTFLiteModel('assets/models/movenet_thunder.tflite');

            // Load Classifier
            classifierModel = await tflite.loadTFLiteModel('assets/models/pose_classifier.tflite');

            // Load Labels
            const response = await fetch('assets/models/pose_labels.txt');
            const text = await response.text();
            labels = text.split('\n').map(s => s.trim()).filter(s => s.length > 0);

            console.log('Worker: Models loaded successfully!');
            self.postMessage({ type: 'loaded' });
        } catch (err) {
            console.error('Worker Error:', err);
            self.postMessage({ type: 'error', payload: err.toString() });
        }
    } else if (type === 'process') {
        if (!movenetModel || !classifierModel) return;

        const { imageData, width, height } = payload;

        // Create tensor from pixel data (RGBA)
        // imageData is Uint8ClampedArray, convert to Uint8Array for tfjs
        const inputTensor = tf.tensor3d(new Uint8Array(imageData), [height, width, 4], 'int32');

        // Preprocess for MoveNet: Resize to 256x256, Remove Alpha, Cast to Int32
        const resized = tf.image.resizeBilinear(inputTensor, [256, 256]);
        const rgb = tf.slice(resized, [0, 0, 0], [256, 256, 3]);
        const batched = tf.expandDims(tf.cast(rgb, 'int32'), 0);

        // Run MoveNet
        const movenetOutput = movenetModel.predict(batched);
        // Output shape: [1, 1, 17, 3] -> [y, x, score]
        const keypoints = await movenetOutput.array();

        // Prepare for Classifier
        // Classifier expects flattened [1, 51] input: [x, y, score, x, y, score, ...]
        const rawKps = keypoints[0][0]; // [17, 3]
        const classifierInput = [];

        for (let i = 0; i < 17; i++) {
            classifierInput.push(rawKps[i][1]); // x
            classifierInput.push(rawKps[i][0]); // y
            classifierInput.push(rawKps[i][2]); // score
        }

        const classifierTensor = tf.tensor2d([classifierInput], [1, 51]);

        // Run Classifier
        const classifierOutput = classifierModel.predict(classifierTensor);
        const scores = await classifierOutput.data();

        // Find max score
        let maxScore = -1;
        let maxIndex = -1;
        for (let i = 0; i < scores.length; i++) {
            if (scores[i] > maxScore) {
                maxScore = scores[i];
                maxIndex = i;
            }
        }

        const label = labels[maxIndex];

        // Cleanup tensors to prevent memory leaks
        inputTensor.dispose();
        resized.dispose();
        rgb.dispose();
        batched.dispose();
        movenetOutput.dispose();
        classifierTensor.dispose();
        classifierOutput.dispose();

        // Send result back
        self.postMessage({
            type: 'result',
            payload: {
                keypoints: rawKps, // [y, x, score]
                label: label,
                score: maxScore
            }
        });
    }
};
