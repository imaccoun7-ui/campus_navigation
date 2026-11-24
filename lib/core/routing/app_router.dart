import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/arrival/arrival_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/map/campus_map_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/review/review_screen.dart';
import '../../features/room/room_details_screen.dart';
import '../../features/route/route_screen.dart';
import '../../features/scan/scanning_screen.dart';
import '../../features/schedule/create_class_screen.dart';
import '../../features/schedule/schedule_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/start/start_point_screen.dart';
import '../../features/upload/upload_screen.dart';

/// The app's navigation graph.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/upload',
        builder: (context, state) => const UploadScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanningScreen(),
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) => const ReviewScreen(),
      ),
      GoRoute(
        path: '/schedule',
        builder: (context, state) => const ScheduleScreen(),
      ),
      GoRoute(
        path: '/schedule/create',
        builder: (context, state) => const CreateClassScreen(),
      ),
      GoRoute(
        path: '/schedule/edit/:id',
        builder: (context, state) => CreateClassScreen(
          editItemId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/room/:buildingId/:roomIndex',
        builder: (context, state) => RoomDetailsScreen(
          buildingId: state.pathParameters['buildingId'] ?? '',
          roomIndex: int.tryParse(state.pathParameters['roomIndex'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/start',
        builder: (context, state) => const StartPointScreen(),
      ),
      GoRoute(path: '/route', builder: (context, state) => const RouteScreen()),
      GoRoute(
        path: '/arrival',
        builder: (context, state) => const ArrivalScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return CampusMapScreen(
            initialBuildingId: query['building'],
            initialRoomName: query['room'],
            pickStartPoint: query['pick'] == 'start',
          );
        },
      ),
    ],
  );
});
