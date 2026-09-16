import 'package:get_it/get_it.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/core/networking/dio_consumer.dart';
import 'package:just_audio/just_audio.dart';

final getIt = GetIt.instance;

Future<void> serviceLocatorInit() async {
  await setupGetIt();
}

Future<void> setupGetIt() async {
  // Services
  await CacheHelper.init();

  getIt.registerLazySingleton<DioConsumer>(() => DioConsumer());
  getIt.registerLazySingleton<AudioPlayer>(() => AudioPlayer());
}
