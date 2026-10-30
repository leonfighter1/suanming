{{flutter_js}}
{{flutter_build_config}}

// Always load a fresh build (owner request: clear cache on every page open,
// debug included). Each load fetches main.dart.js with a new query string, and
// no service worker is registered.
const bust = Date.now().toString(36);
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath += "?v=" + bust;
}
_flutter.loader.load();
