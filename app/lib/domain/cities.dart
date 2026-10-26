/// Launch-market birthplaces. Longitude drives 真太陽時; timezone drives historical DST.
class City {
  const City(this.key, this.names, this.timezone, this.longitude);
  final String key;
  final Map<String, String> names;
  final String timezone;
  final double longitude;
  String name(String apiLocale) => names[apiLocale] ?? names['en']!;
}

const cities = [
  City('hk', {'zh-Hant': '香港', 'zh-Hans': '香港', 'en': 'Hong Kong'}, 'Asia/Hong_Kong', 114.1694),
  City('taipei', {'zh-Hant': '台北', 'zh-Hans': '台北', 'en': 'Taipei'}, 'Asia/Taipei', 121.5654),
  City('singapore', {'zh-Hant': '新加坡', 'zh-Hans': '新加坡', 'en': 'Singapore'}, 'Asia/Singapore', 103.8198),
  City('kl', {'zh-Hant': '吉隆坡', 'zh-Hans': '吉隆坡', 'en': 'Kuala Lumpur'}, 'Asia/Kuala_Lumpur', 101.6869),
  City('shanghai', {'zh-Hant': '上海', 'zh-Hans': '上海', 'en': 'Shanghai'}, 'Asia/Shanghai', 121.4737),
  City('guangzhou', {'zh-Hant': '廣州', 'zh-Hans': '广州', 'en': 'Guangzhou'}, 'Asia/Shanghai', 113.2644),
  City('nyc', {'zh-Hant': '紐約', 'zh-Hans': '纽约', 'en': 'New York'}, 'America/New_York', -74.006),
  City('vancouver', {'zh-Hant': '溫哥華', 'zh-Hans': '温哥华', 'en': 'Vancouver'}, 'America/Vancouver', -123.1207),
  City('toronto', {'zh-Hant': '多倫多', 'zh-Hans': '多伦多', 'en': 'Toronto'}, 'America/Toronto', -79.3832),
  City('london', {'zh-Hant': '倫敦', 'zh-Hans': '伦敦', 'en': 'London'}, 'Europe/London', -0.1278),
  City('sydney', {'zh-Hant': '悉尼', 'zh-Hans': '悉尼', 'en': 'Sydney'}, 'Australia/Sydney', 151.2093),
];

City cityByKey(String key) => cities.firstWhere((c) => c.key == key, orElse: () => cities.first);
