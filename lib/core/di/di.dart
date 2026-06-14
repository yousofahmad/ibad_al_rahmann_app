import 'package:get_it/get_it.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';
import 'package:just_audio/just_audio.dart';

final getIt = GetIt.instance;

Future<void> serviceLocatorInit() async {
  await setupGetIt();
}

Future<void> setupGetIt() async {
  // Services
  getIt.registerLazySingleton<CacheService>(() => CacheService());
  await getIt<CacheService>().init();

  getIt.registerLazySingleton<AudioPlayer>(() => AudioPlayer());
}
