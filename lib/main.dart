import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const WalkPuzzleApp());
}

class WalkPuzzleApp extends StatelessWidget {
  const WalkPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walk Puzzle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const StepCounterPage(),
    );
  }
}

class StepCounterPage extends StatefulWidget {
  const StepCounterPage({super.key});

  @override
  State<StepCounterPage> createState() => _StepCounterPageState();
}

class _StepCounterPageState extends State<StepCounterPage> {
  // Health Connect instance
  final Health _health = Health();
  
  // Step count data
  int _stepCount = 0;
  bool _isLoading = false;
  String _statusMessage = '歩数データを取得中...';
  bool _hasPermission = false;
  
  // Health Connect data types we need
  static final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
  ];

  @override
  void initState() {
    super.initState();
    _initializeHealthConnect();
  }

  /// Initialize Health Connect and request permissions
  Future<void> _initializeHealthConnect() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Health Connectの初期化中...';
    });

    try {
      // Check if Health Connect is available
      bool isAvailable = await _health.isHealthConnectAvailable() ?? false;
      
      if (!isAvailable) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Health Connectがインストールされていません。\nGoogle Playストアからインストールしてください。';
          _hasPermission = false;
        });
        return;
      }

      // Request permissions
      await _requestPermissions();
      
      // If we have permission, fetch step count
      if (_hasPermission) {
        await _fetchStepCount();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'エラーが発生しました: ${e.toString()}';
        _hasPermission = false;
      });
    }
  }

  /// Request permissions for Health Connect
  Future<void> _requestPermissions() async {
    setState(() {
      _statusMessage = '権限をリクエスト中...';
    });

    try {
      // Request Android activity recognition permission first
      var activityPermission = await Permission.activityRecognition.request();
      
      if (!activityPermission.isGranted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '歩数データの取得には「身体活動」の権限が必要です。';
          _hasPermission = false;
        });
        return;
      }

      // Request Health Connect permissions
      bool hasPermissions = await _health.hasPermissions(_dataTypes) ?? false;
      
      if (!hasPermissions) {
        // Request authorization
        bool authorized = await _health.requestAuthorization(_dataTypes);
        
        setState(() {
          _hasPermission = authorized;
          if (!authorized) {
            _isLoading = false;
            _statusMessage = 'Health Connectの権限が拒否されました。\n設定から権限を許可してください。';
          }
        });
      } else {
        setState(() {
          _hasPermission = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '権限リクエストエラー: ${e.toString()}';
        _hasPermission = false;
      });
    }
  }

  /// Fetch step count from today's midnight to now
  Future<void> _fetchStepCount() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '歩数データを取得中...';
    });

    try {
      // Get today's date at midnight
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Fetch step count data
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: _dataTypes,
        startTime: midnight,
        endTime: now,
      );

      // Calculate total steps
      int totalSteps = 0;
      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          totalSteps += (data.value as num).toInt();
        }
      }

      setState(() {
        _stepCount = totalSteps;
        _isLoading = false;
        _statusMessage = '本日の歩数: $totalSteps 歩';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'データ取得エラー: ${e.toString()}';
      });
    }
  }

  /// Refresh step count manually
  Future<void> _refreshStepCount() async {
    if (_hasPermission) {
      await _fetchStepCount();
    } else {
      await _initializeHealthConnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Walk Puzzle - 歩数確認'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Settings page
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Health Connect status icon
              Icon(
                _hasPermission ? Icons.check_circle : Icons.warning,
                size: 64,
                color: _hasPermission ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 24),
              
              // Status message
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              
              // Step count display
              if (_hasPermission && !_isLoading) ...[
                const Text(
                  '今日の歩数',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                  ),
                  child: Text(
                    '$_stepCount',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '歩',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              
              // Loading indicator
              if (_isLoading) ...[
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
              ],
              
              const SizedBox(height: 32),
              
              // Refresh button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _refreshStepCount,
                icon: const Icon(Icons.refresh),
                label: const Text('更新'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              
              // Retry permission button if no permission
              if (!_hasPermission && !_isLoading) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _initializeHealthConnect,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('権限を再リクエスト'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
