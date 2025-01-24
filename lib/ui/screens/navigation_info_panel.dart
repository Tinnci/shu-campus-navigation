// lib/ui/screens/navigation_info_panel.dart
import 'dart:ui'; // 需要引入 dart:ui 用于 BackdropFilter
import 'package:flutter/material.dart';

class NavigationInfoPanel extends StatelessWidget {
  final List<Map<String, dynamic>> instructions;
  final bool isPortrait;
  final VoidCallback onClose; // 用于关闭面板

  const NavigationInfoPanel({
    super.key,
    required this.instructions,
    required this.isPortrait,
    required this.onClose,
  });

  // 根据 maneuver 类型选择合适的图标
  Icon _getTurnIcon(int maneuverType) {
    switch (maneuverType) {
      case 1:
        return const Icon(Icons.straight); // 直行
      case 2:
        return const Icon(Icons.turn_right); // 右转
      case 3:
        return const Icon(Icons.turn_left); // 左转
      default:
        return const Icon(Icons.navigation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    final double panelHeight = isPortrait ? screenHeight * 0.4 : screenHeight * 0.5;
    final double panelWidth = isPortrait ? screenWidth * 0.9 : screenWidth * 0.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // 模糊效果
        child: Container(
          width: panelWidth,
          height: panelHeight,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30.0),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '导航信息',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: instructions.length,
                  itemBuilder: (context, index) {
                    final step = instructions[index];
                    return ListTile(
                      leading: _getTurnIcon(step['type']),
                      title: Text(
                        step['instruction'],
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                      ),
                      subtitle: Text(
                        '距下一步 ${step['distance']} 米, 街道: ${step['street_name'] ?? '未知街道'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
