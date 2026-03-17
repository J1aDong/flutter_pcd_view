import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'file_select_screen.dart';
import 'settings_screen.dart';
import '../config/viewer_config_notifier.dart';

class TabScreen extends HookWidget {
  const TabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 2);
    final configNotifier = useMemoized(() => ViewerConfigNotifier());
    final isLoading = useState(true);

    useEffect(() {
      configNotifier.loadSettings().then((_) {
        isLoading.value = false;
      });
      return null;
    }, []);

    if (isLoading.value) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PCD Viewer Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(icon: Icon(Icons.folder), text: '文件选择'),
            Tab(icon: Icon(Icons.settings), text: '查看器设置'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          FileSelectScreen(configNotifier: configNotifier),
          SettingsScreen(configNotifier: configNotifier),
        ],
      ),
    );
  }
}
