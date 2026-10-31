/// Not on the web: no other tab to take turns with.
Future<T> oneAtATime<T>(String name, Future<T> Function() body) => body();
