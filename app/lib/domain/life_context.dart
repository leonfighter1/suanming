import 'places.dart';

const _keep = Object();

/// What the user tells us about their life, so readings relate the chart to their
/// real situation. Stored on the device with the profile; sent only with a report
/// request (POST /v1/reports `context`), never with the chart.
class LifeContext {
  const LifeContext({
    this.useName = true,
    this.residence,
    this.marital,
    this.children,
    this.occupation,
    this.family,
    this.concern,
  });

  factory LifeContext.fromJson(Map<String, dynamic>? j) => j == null
      ? const LifeContext()
      : LifeContext(
          useName: j['use_name'] as bool? ?? true,
          residence: j['residence'] == null ? null : BirthPlace.fromJson(j['residence'] as Map<String, dynamic>),
          marital: j['marital'] as String?,
          children: j['children'] as String?,
          occupation: j['occupation'] as String?,
          family: j['family'] as String?,
          concern: j['concern'] as String?,
        );

  /// Address the user by the profile name in readings.
  final bool useName;

  /// Where they live now (may differ from the birthplace).
  final BirthPlace? residence;

  /// single | dating | married | separated | divorced | widowed
  final String? marital;

  /// none | has
  final String? children;
  final String? occupation;
  final String? family;

  /// What they want to know.
  final String? concern;

  static const maritalValues = ['single', 'dating', 'married', 'separated', 'divorced', 'widowed'];
  static const childrenValues = ['none', 'has'];

  bool get isEmpty =>
      residence == null && marital == null && children == null && (occupation ?? '').isEmpty && (family ?? '').isEmpty && (concern ?? '').isEmpty;

  /// The request's `context`, or null when there is nothing to send.
  ///
  /// [birthplace] is the picked birthplace's label: the chart only receives its
  /// timezone and longitude, so this is how the reading knows where it is.
  Map<String, Object?>? toApi({required String name, required String locale, String? birthplace}) {
    String? t(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    final m = <String, Object?>{
      if (useName && name.trim().isNotEmpty) 'name': name.trim(),
      'birthplace': ?t(birthplace),
      if (residence != null) 'residence': residence!.label(locale),
      'marital': ?marital,
      'children': ?children,
      'occupation': ?t(occupation),
      'family': ?t(family),
      'concern': ?t(concern),
    };
    return m.isEmpty ? null : m;
  }

  Map<String, dynamic> toJson() => {
        'use_name': useName,
        if (residence != null) 'residence': residence!.toJson(),
        'marital': ?marital,
        'children': ?children,
        'occupation': ?occupation,
        'family': ?family,
        'concern': ?concern,
      };

  /// Pass `null` to clear a field; omit it to keep the current value.
  LifeContext copyWith({
    bool? useName,
    Object? residence = _keep,
    Object? marital = _keep,
    Object? children = _keep,
    Object? occupation = _keep,
    Object? family = _keep,
    Object? concern = _keep,
  }) =>
      LifeContext(
        useName: useName ?? this.useName,
        residence: identical(residence, _keep) ? this.residence : residence as BirthPlace?,
        marital: identical(marital, _keep) ? this.marital : marital as String?,
        children: identical(children, _keep) ? this.children : children as String?,
        occupation: identical(occupation, _keep) ? this.occupation : occupation as String?,
        family: identical(family, _keep) ? this.family : family as String?,
        concern: identical(concern, _keep) ? this.concern : concern as String?,
      );
}
