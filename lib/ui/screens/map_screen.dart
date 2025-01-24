import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 引入 Riverpod
import '../../services/valhalla_service.dart';
import 'campus_map_screen.dart';
import 'settings_screen.dart';
import 'package:flutter/services.dart';
import 'navigation_screen.dart';
import '../../services/route_drawer.dart'; // 引入 RouteDrawer

class MapScreen extends ConsumerStatefulWidget {
  static const String route = '/map';
  final Function(ThemeMode) onThemeChanged;

  const MapScreen({super.key, required this.onThemeChanged});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends ConsumerState<MapScreen> {
  int _selectedIndex = 0; // 当前选中的页面索引
  late final RouteDrawer _routeDrawer;

  // 保持每个页面的实例，以便保持其状态
  late final CampusMapScreen _campusMapScreen;
  late final NavigationScreen _navigationScreen;
  late final SettingsScreen _settingsScreen;

  @override
  void initState() {
    super.initState();
    // 创建 RouteDrawer 实例
    _routeDrawer = RouteDrawer(valhallaService: ValhallaService());

    // 初始化各个页面
    _campusMapScreen = CampusMapScreen(
      onMapLoaded: _onMapLoaded,
      //routeDrawer: _routeDrawer,
    );
    _navigationScreen = NavigationScreen(
      onMapLoaded: _onMapLoaded,
      routeDrawer: _routeDrawer,
    );
    _settingsScreen = SettingsScreen(onThemeChanged: widget.onThemeChanged);
  }

  // 当用户点击底部导航栏时切换页面
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 地图加载完成后的回调
  void _onMapLoaded() {
    // 这里我们不再处理全局的加载状态
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    // 根据当前选中的索引，决定显示哪个页面
    Widget currentScreen;
    switch (_selectedIndex) {
      case 0:
        currentScreen = _campusMapScreen;
        break;
      case 1:
        currentScreen = _navigationScreen;
        break;
      case 2:
        currentScreen = _settingsScreen;
        break;
      default:
        currentScreen = _campusMapScreen;
    }

    return Scaffold(
      body: Stack(
        children: [
          // 仅渲染当前选中的页面
          currentScreen,

          // 自定义底部导航栏
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    height: 80,
                    width: screenWidth > 600
                        ? screenWidth * 0.7
                        : screenWidth * 0.9,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.withOpacity(0.2)
                              : Colors.white.withOpacity(0.2),
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.3)
                              : const Color.fromARGB(255, 105, 105, 105)
                                  .withOpacity(0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(40.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 5,
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavBarItem(
                          icon: Icons.map,
                          isSelected: _selectedIndex == 0,
                          onTap: () => _onItemTapped(0),
                        ),
                        _buildNavBarItem(
                          icon: Icons.navigation,
                          isSelected: _selectedIndex == 1,
                          onTap: () => _onItemTapped(1),
                        ),
                        _buildNavBarItem(
                          icon: Icons.settings,
                          isSelected: _selectedIndex == 2,
                          onTap: () => _onItemTapped(2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建导航栏项
  Widget _buildNavBarItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: isSelected ? 30 : 24,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
