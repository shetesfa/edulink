import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LAB WEBVIEW SCREEN — loads local HTML assets for 3D science labs
// ─────────────────────────────────────────────────────────────────────────────
class LabWebViewScreen extends StatefulWidget {
  final String labId;
  final String title;
  final String subject;
  final String assetPath;        // e.g. "web_assets/chemistry/molecules/viewer.html"
  final List<LabTab>? extraTabs; // optional extra tabs for the same subject

  const LabWebViewScreen({
    super.key,
    required this.labId,
    required this.title,
    required this.subject,
    required this.assetPath,
    this.extraTabs,
  });

  @override
  State<LabWebViewScreen> createState() => _LabWebViewScreenState();
}

class _LabWebViewScreenState extends State<LabWebViewScreen>
    with SingleTickerProviderStateMixin {
  late WebViewController _controller;
  bool _loading = true;
  bool _hasError = false;
  int _activeTab = 0;
  late TabController _tabController;

  // Subject accent colors
  static const _colors = {
    'Chemistry': Color(0xFF7C3AED),
    'Biology':   Color(0xFF059669),
    'Physics':   Color(0xFFD97706),
    'Mathematics': Color(0xFF2563EB),
  };

  Color get _accent => _colors[widget.subject] ?? const Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    final List<LabTab> tabs = _allTabs;
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
        _loadTab(_tabController.index);
      }
    });
    _initWebView(tabs[0].assetPath);
  }

  List<LabTab> get _allTabs {
    final main = LabTab(label: widget.title.split(' ').last, assetPath: widget.assetPath);
    return [main, ...?widget.extraTabs];
  }

  void _initWebView(String assetPath) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A1A))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() { _loading = true; _hasError = false; }),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (err) {
          // Ignore sub-resource errors (fonts etc.) — only flag navigation errors
          if (err.isForMainFrame == true) {
            setState(() { _loading = false; _hasError = true; });
          }
        },
      ))
      ..loadFlutterAsset(assetPath);
  }

  void _loadTab(int index) {
    setState(() { _loading = true; _hasError = false; });
    _controller.loadFlutterAsset(_allTabs[index].assetPath);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _allTabs;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: _buildAppBar(tabs),
      body: Stack(
        children: [
          // WebView
          WebViewWidget(controller: _controller),

          // Loading shimmer overlay
          if (_loading) _buildLoadingOverlay(),

          // Error overlay
          if (_hasError) _buildErrorOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(List<LabTab> tabs) {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D24),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_accent, _accent.withValues(alpha: 0.6)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(_subjectIcon, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
            Text(widget.subject,
              style: TextStyle(fontSize: 10, color: _accent)),
          ]),
        ),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          onPressed: () => _loadTab(_activeTab),
          tooltip: 'Reload',
        ),
        if (!Platform.isAndroid && !Platform.isIOS)
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded, size: 20),
            onPressed: () {}, // desktop: could open in external browser
          ),
        const SizedBox(width: 4),
      ],
      bottom: tabs.length > 1
          ? TabBar(
              controller: _tabController,
              indicatorColor: _accent,
              indicatorWeight: 3,
              labelColor: _accent,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: tabs.map((t) => Tab(text: t.label)).toList(),
            )
          : null,
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: const Color(0xFF0A0A1A),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 56, height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading ${widget.subject} Lab...',
            style: TextStyle(color: _accent, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Interactive 3D content',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
          ),
        ]),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: const Color(0xFF0A0A1A),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.science_outlined, size: 64, color: _accent.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('Could not load lab content',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('The lab files may not be in the app assets yet.',
            style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadTab(_activeTab),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }

  String get _subjectIcon {
    switch (widget.subject) {
      case 'Chemistry':    return '⚗️';
      case 'Biology':      return '🧬';
      case 'Physics':      return '⚡';
      case 'Mathematics':  return '📐';
      default:             return '🔬';
    }
  }
}

class LabTab {
  final String label;
  final String assetPath;
  const LabTab({required this.label, required this.assetPath});
}
