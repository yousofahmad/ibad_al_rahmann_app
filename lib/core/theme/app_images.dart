class AppImages {
  // Images
  static const imagesAyaFrame = "assets/images/aya_frame.png";
  static const imagesBasmala = "assets/images/basmala.png";
  static const imagesEveningBackground = "assets/images/night.jpg";
  static const imagesFullWhiteBackground =
      "assets/images/full_white_background.png";
  static const imagesGreenBackground = "assets/images/green_background.jpg";
  static const imagesGreenColor = "assets/images/green_color.webp";
  static const imagesIcLauncher = "assets/images/ic_launcher.jpg";
  static const imagesKaaba = "assets/images/kaaba.png";
  static const imagesMoonIcon = "assets/images/moon_icon.png";
  static const imagesMorningBackground = "assets/images/morning.jpg";
  static const imagesPlayIcon = "assets/images/play_icon.png";
  static const imagesQuranIcLauncher = "assets/images/quran_ic_launcher.png";
  static const imagesSplash = "assets/images/splash.png";
  static const imagesSunIcon = "assets/images/sun_icon.png";
  static const imagesVerseFrame = "assets/images/verse_frame.png";
  static const imagesWhiteBackground = "assets/images/white_background.png";

  // Aliases for compatibility if needed (renaming mapped calls)
  static const ayaFrame = imagesAyaFrame;
  static const basmala = imagesBasmala;
  static const greenBackground = imagesGreenBackground;
  // ... add others as aliases if strictly needed, but better to stick to one convention.
  // Code we've seen uses 'AppImages.ayaFrame' (in header_widget) AND 'AppImages.imagesGreenColor' (in reciter_widget).
  // I will include BOTH versions for commonly used ones to be safe.

  static const verseFrame = imagesVerseFrame;

  // Lottie
  static const lottiesCircularIndicator =
      "assets/lotties/circular_indicator.json";

  // SVGs
  static const svgsBookmark = "assets/svgs/bookmark.svg";
  static const svgsLocation = "assets/svgs/location.svg";
  static const svgsMenu = "assets/svgs/menu.svg";
  static const svgsMoonIcon = "assets/svgs/moon_icon.svg";
  static const svgsPrayersTitle = "assets/svgs/prayers_title.svg";
  static const svgsSearch = "assets/svgs/search.svg";
  static const svgsSearchIcon = "assets/svgs/search_icon.svg";
  static const svgsSettings = "assets/svgs/settings.svg";
  static const svgsStar = "assets/svgs/star.svg";
  static const svgsSunIcon = "assets/svgs/sun_icon.svg";

  // Sections (SVG)
  static const sectionsAzkarLight = "assets/sections/azkar_light.svg";
  static const sectionsAzkarDark = "assets/sections/azkar_dark.svg";
  static const sectionsPrayer = "assets/sections/prayer.svg";
  static const sectionsQiblah = "assets/sections/qiblah.svg";
  static const sectionsQuranLight = "assets/sections/quran_light.svg";
  static const sectionsQuranDark = "assets/sections/quran_dark.svg";
  static const sectionsReciters = "assets/sections/reciters.svg";

  // Aliases for compatibility
  static const sectionsQuran = sectionsQuranLight;
  static const sectionsAzkar = sectionsAzkarLight;
}
