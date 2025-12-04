// 藍牙核心服務，模擬掃描與連線，預留真實硬體接口。

import 'dart:async';

// --- 【新增】我們先定義一個假的藍牙裝置類別 ---
// 這是為了在沒有真實硬體時，也能有一個標準的資料結構來填充 UI。
class MockBluetoothDevice {
  final String platformName;
  final String remoteId;
  MockBluetoothDevice({required this.platformName, required this.remoteId});
}

// 建立一個藍牙服務的類別，方便我們集中管理所有藍牙相關的功能
class BluetoothService {
  final StreamController<List<MockBluetoothDevice>> _scanResultsController =
      StreamController.broadcast();
  Stream<List<MockBluetoothDevice>> get scanResults =>
      _scanResultsController.stream;

  final StreamController<bool> _isScanningController =
      StreamController.broadcast();
  Stream<bool> get isScanning => _isScanningController.stream;

  // --- 核心功能：開始掃描 ---
  Future<void> startScan() async {
    _isScanningController.add(true);
    _scanResultsController.add([]); // 開始掃描時先清空列表

    // 我們用一個 Future.delayed demo
    await Future.delayed(const Duration(seconds: 2), () {
      final mockDevices = [
        MockBluetoothDevice(
            platformName: 'ESP32_Sensor_01', remoteId: '00:11:22:33:44:55'),
        MockBluetoothDevice(
            platformName: 'My_Apple_Watch', remoteId: 'AA:BB:CC:DD:EE:FF'),
        MockBluetoothDevice(
            platformName: 'Smart_Band_7', remoteId: '12:34:56:78:90:AB'),
      ];
      // 將我們產生的假裝置列表，廣播出去
      if (!_scanResultsController.isClosed) {
        _scanResultsController.add(mockDevices);
      }
    });

    // 模擬掃描在 3 秒後結束
    Future.delayed(const Duration(seconds: 3), () {
      stopScan();
    });
  }

  // --- 核心功能：停止掃描 ---
  void stopScan() {
    if (!_isScanningController.isClosed) {
      _isScanningController.add(false);
    }
  }

  // --- 模擬連線功能 ---
  void connectToDevice(MockBluetoothDevice device) {
    // 這裡我們只印出訊息，來模擬連線的動作
  }
  
  void dispose() {
    _scanResultsController.close();
    _isScanningController.close();
  }
}
