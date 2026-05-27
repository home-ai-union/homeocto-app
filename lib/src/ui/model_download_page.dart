import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homeocto_app/src/generated/l10n/app_localizations.dart';

/// 模型数据类
class ModelInfo {
  final String id;
  final String displayName;
  final String description;
  final String ggufFileName;
  final String mmprojFileName;
  final String? hfRepo;
  final String? msRepo;
  final String ggufMd5;
  final String mmprojMd5;
  final int version;

  const ModelInfo({
    required this.id,
    required this.displayName,
    required this.description,
    required this.ggufFileName,
    required this.mmprojFileName,
    this.hfRepo,
    this.msRepo,
    required this.ggufMd5,
    required this.mmprojMd5,
    this.version = 0,
  });

  static const List<ModelInfo> availableModels = [
    ModelInfo(
      id: 'minicpm-v-4_6-instruct',
      displayName: 'MiniCPM-V-4.6 (Q4_K_M)',
      description: 'Next-gen multimodal model, image/text understanding (1.2B)',
      ggufFileName: 'MiniCPM-V-4_6-Q4_K_M.gguf',
      mmprojFileName: 'mmproj-model-f16.gguf',
      hfRepo: 'openbmb/MiniCPM-V-4.6-gguf',
      msRepo: 'OpenBMB/MiniCPM-V-4.6-gguf',
      ggufMd5: 'fd778481dd56b6036dd8f9cf7c1519cf',
      mmprojMd5: '54aea6e04d752f47309a48f12795a1a3',
      version: 46,
    ),
    ModelInfo(
      id: 'minicpm-v-4',
      displayName: 'MiniCPM-V-4 (Q4_K_M)',
      description:
          'Lightweight multimodal model, image/text understanding (4.1B)',
      ggufFileName: 'ggml-model-Q4_K_M.gguf',
      mmprojFileName: 'mmproj-model-f16.gguf',
      hfRepo: 'openbmb/MiniCPM-V-4-gguf',
      msRepo: 'OpenBMB/MiniCPM-V-4-gguf',
      ggufMd5: '',
      mmprojMd5: '',
      version: 5,
    ),
  ];

  static ModelInfo get defaultModel => availableModels.first;

  static ModelInfo? findById(String id) {
    return availableModels.firstWhere(
      (model) => model.id == id,
      orElse: () => defaultModel,
    );
  }
}

/// 下载状态枚举
enum DownloadStatus { idle, downloading, completed, failed, cancelled }

/// 下载进度数据
class DownloadProgress {
  final String modelId;
  final String fileName;
  final double progress; // 0.0 to 1.0
  final DownloadStatus status;
  final String? errorMessage;

  const DownloadProgress({
    required this.modelId,
    required this.fileName,
    required this.progress,
    required this.status,
    this.errorMessage,
  });
}

/// 模型下载管理页面
class ModelDownloadPage extends StatefulWidget {
  const ModelDownloadPage({super.key});

  @override
  State<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends State<ModelDownloadPage> {
  ModelInfo _selectedModel = ModelInfo.defaultModel;
  DownloadStatus _downloadStatus = DownloadStatus.idle;
  double _downloadProgress = 0.0;
  String _modelStatus = '未初始化';
  bool _isModelLoaded = false;
  bool _modelFileExists = false;

  @override
  void initState() {
    super.initState();
    _checkModelFiles();
    _updateModelStatus();
  }

  /// 检查模型文件是否存在
  Future<void> _checkModelFiles() async {
    // TODO: 实现文件检查逻辑
    // 这里应该检查本地是否存在模型文件
    setState(() {
      _modelFileExists = false; // 临时值
    });
  }

  /// 更新模型状态显示
  void _updateModelStatus() {
    if (_isModelLoaded) {
      _modelStatus = '模型已加载';
    } else if (_downloadStatus == DownloadStatus.downloading) {
      _modelStatus = '正在下载...';
    } else if (_modelFileExists) {
      _modelStatus = '模型文件已存在，点击加载';
    } else {
      _modelStatus = '未初始化';
    }
  }

  /// 开始下载
  void _startDownload() {
    if (_downloadStatus == DownloadStatus.downloading) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正在下载中...')));
      return;
    }

    if (_modelFileExists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('模型文件已存在，无需重复下载')));
      return;
    }

    setState(() {
      _downloadStatus = DownloadStatus.downloading;
      _downloadProgress = 0.0;
      _updateModelStatus();
    });

    // TODO: 调用实际的下载服务
    _simulateDownload();
  }

  /// 模拟下载进度（用于测试）
  Future<void> _simulateDownload() async {
    for (int i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      setState(() {
        _downloadProgress = i / 100.0;
      });
    }

    if (!mounted) return;
    setState(() {
      _downloadStatus = DownloadStatus.completed;
      _modelFileExists = true;
      _updateModelStatus();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('下载完成！请点击加载模型')));
  }

  /// 加载模型
  void _loadModel() {
    if (!_modelFileExists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('模型文件不存在，请先下载')));
      return;
    }

    setState(() {
      _isModelLoaded = true;
      _updateModelStatus();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('模型加载成功！')));
  }

  /// 删除模型文件
  void _deleteModelFiles() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模型文件'),
        content: Text(
          '确定要删除 ${_selectedModel.displayName} 的模型文件吗？\n\n'
          '这将删除:\n'
          '• ${_selectedModel.ggufFileName}\n'
          '• ${_selectedModel.mmprojFileName}\n\n'
          '删除后需要重新下载才能使用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performDelete();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 执行删除操作
  Future<void> _performDelete() async {
    // TODO: 实现实际的删除逻辑
    setState(() {
      _modelFileExists = false;
      _isModelLoaded = false;
      _updateModelStatus();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('模型文件已删除')));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '模型管理',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模型选择列表
            Text(
              '选择模型',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...ModelInfo.availableModels.map(
              (model) => _ModelCard(
                model: model,
                isSelected: model.id == _selectedModel.id,
                onTap: () {
                  setState(() {
                    _selectedModel = model;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已选择: ${model.displayName}')),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // 模型状态和操作卡片
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _modelStatus,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 下载和加载按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _downloadStatus == DownloadStatus.downloading
                                ? null
                                : _startDownload,
                            child: const Text('下载'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _modelFileExists ? _loadModel : null,
                            child: Text(_isModelLoaded ? '重新加载' : '加载模型'),
                          ),
                        ),
                      ],
                    ),

                    // 删除按钮
                    if (_modelFileExists) ...[
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _deleteModelFiles,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error),
                        ),
                        child: const Text('删除模型文件'),
                      ),
                    ],

                    // 下载进度条
                    if (_downloadStatus == DownloadStatus.downloading) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        minHeight: 4,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_downloadProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 模型卡片组件
class _ModelCard extends StatelessWidget {
  final ModelInfo model;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelCard({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 0,
      color: isSelected ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 选中指示器
              Radio<bool>(
                value: true,
                groupValue: isSelected,
                onChanged: (_) => onTap(),
              ),
              const SizedBox(width: 8),
              // 模型信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.displayName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
