import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/browse/browse_screen.dart';
import '../features/search/search_screen.dart';
import '../features/remote/remote_screen.dart';
import '../features/camera/camera_screen.dart';
import '../features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/camera',
        name: 'camera',
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: '/browse',
        name: 'browse',
        builder: (context, state) => const BrowseScreen(),
      ),
      GoRoute(
        path: '/remote/:modelId',
        name: 'remote',
        builder: (context, state) => RemoteScreen(
          modelId: state.pathParameters['modelId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
