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
  // IMPORTANT: Including all types we declared in AndroidManifest
  static final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    // Adding these ensures proper permission handling on Android
  ];
  
  // Permission types for Health package (includes ACTIVITY_RECOGNITION on Android)
  static final List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
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
      print('\n========== 権限リクエスト開始 ==========');
      
      // Health package automatically requests ACTIVITY_RECOGNITION on Android
      // when requesting health data permissions
      print('Health Connect権限のリクエスト中...');
      print('⚠️ これからrequestAuthorizationを呼び出します');
      print('対象データ型: $_dataTypes');
      print('注: healthパッケージがACTIVITY_RECOGNITION権限も自動的にリクエストします');
      
      // Check Health Connect permissions BEFORE requesting
      print('\nステップ1: Health Connect権限の事前チェック...');
      bool hasPermissionsBefore = await _health.hasPermissions(_dataTypes) ?? false;
      print('事前チェック結果: hasPermissions = $hasPermissionsBefore');
      
      if (!hasPermissionsBefore) {
        print('\nステップ2: Health Connect権限のリクエスト中...');
        
        // Request authorization
        // The health package handles ACTIVITY_RECOGNITION automatically on Android
        print('>>> requestAuthorization() 実行中...');
        bool authorized = await _health.requestAuthorization(
          _dataTypes,
          permissions: _permissions,
        );
        print('<<< requestAuthorization() 完了');
        print('戻り値（authorized）: $authorized');
        
        // Verify AFTER requesting
        print('\nステップ3: Health Connect権限の事後チェック...');
        bool hasPermissionsAfter = await _health.hasPermissions(_dataTypes) ?? false;
        print('事後チェック結果: hasPermissions = $hasPermissionsAfter');
        
        // Log discrepancy if any
        if (authorized != hasPermissionsAfter) {
          print('⚠️⚠️⚠️ 警告: 戻り値と実際の権限状態が一致しません！');
          print('  requestAuthorizationの戻り値: $authorized');
          print('  hasPermissionsの結果: $hasPermissionsAfter');
          print('  → hasPermissionsの結果を正として採用します');
          authorized = hasPermissionsAfter;
        }
        
        if (authorized) {
          print('✅ Health Connect権限が許可されました');
          print('✅ ACTIVITY_RECOGNITION権限も自動的に処理されました');
        } else {
          print('❌ Health Connect権限が拒否されました');
        }
        
        setState(() {
          _hasPermission = authorized;
          if (!authorized) {
            _isLoading = false;
            _statusMessage = 'Health Connectの権限が拒否されました。\n設定から権限を許可してください。';
          }
        });
      } else {
        print('✅ Health Connect権限は既に許可されています');
        setState(() {
          _hasPermission = true;
        });
      }
      
      print('========== 権限リクエスト終了 ==========\n');
    } catch (e, stackTrace) {
      print('❌❌❌ 権限リクエスト中に例外が発生しました');
      print('エラー: $e');
      print('スタックトレース: $stackTrace');
      
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
      // Get current time in local timezone (JST)
      final now = DateTime.now();
      
      // Get today's midnight in local timezone
      // Use local timezone explicitly
      final midnight = DateTime(now.year, now.month, now.day, 0, 0, 0).toLocal();
      final endTime = now.toLocal();
      
      // デバッグログ: クエリの時間範囲を出力
      print('=== Health Connect クエリ開始 ===');
      print('現在時刻: $now');
      print('ローカルタイムゾーン: ${now.timeZoneName} (UTC${now.timeZoneOffset})');
      print('クエリ開始時刻 (midnight): $midnight');
      print('クエリ終了時刻 (now): $endTime');
      print('クエリ期間: ${endTime.difference(midnight).inHours}時間');
      
      // 方法1: 個別データポイントの取得を試みる
      print('\n--- 方法1: getHealthDataFromTypes ---');
      print('Health Connectにデータをリクエスト中...');
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: _dataTypes,
        startTime: midnight,
        endTime: endTime,
      );
      
      // デバッグログ: 取得したデータポイントの詳細を出力
      print('取得したデータポイント数: ${healthData.length}');
      
      if (healthData.isEmpty) {
        print('⚠️ データポイントが0件です。');
      } else {
        print('--- 取得した生データの詳細 ---');
        for (int i = 0; i < healthData.length; i++) {
          var data = healthData[i];
          print('データ[$i]:');
          print('  タイプ: ${data.type}');
          print('  値: ${data.value}');
          print('  開始時刻: ${data.dateFrom}');
          print('  終了時刻: ${data.dateTo}');
          print('  ソース: ${data.sourceId} (${data.sourceName})');
          print('  ユニット: ${data.unit}');
        }
      }

      // Calculate total steps from individual data points
      int totalSteps = 0;
      for (var data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          int stepValue = (data.value as num).toInt();
          totalSteps += stepValue;
          print('歩数を加算: +$stepValue (累計: $totalSteps)');
        }
      }
      
      // 方法2: データポイントが0件の場合、集計データを試す
      if (healthData.isEmpty || totalSteps == 0) {
        print('\n--- 方法2: getTotalStepsInInterval (集計データ) ---');
        try {
          int? aggregateSteps = await _health.getTotalStepsInInterval(midnight, endTime);
          print('集計データから取得した歩数: $aggregateSteps');
          
          if (aggregateSteps != null && aggregateSteps > 0) {
            totalSteps = aggregateSteps;
            print('✅ 集計データを使用します: $totalSteps 歩');
          } else {
            print('⚠️ 集計データも0件または取得失敗');
          }
        } catch (aggregateError) {
          print('❌ 集計データ取得エラー: $aggregateError');
        }
      }
      
      print('\n=== 最終結果: 合計歩数 = $totalSteps 歩 ===');
      print('');

      setState(() {
        _stepCount = totalSteps;
        _isLoading = false;
        _statusMessage = '本日の歩数: $totalSteps 歩\n(データポイント数: ${healthData.length}件)';
      });
    } catch (e, stackTrace) {
      print('❌ エラー発生: $e');
      print('スタックトレース: $stackTrace');
      
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
