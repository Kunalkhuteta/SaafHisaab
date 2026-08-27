class AppCache {
  static final Map<String, dynamic> _cache = {};

  static List<Map<String, dynamic>>? brokerList;
  static List<Map<String, dynamic>>? transportList;
  static List<Map<String, dynamic>>? stationList;
  static List<Map<String, dynamic>>? userItemGroups;
  static List<Map<String, dynamic>>? salesRepresentatives;

  static bool hasPartyList(String key) {
    return _cache.containsKey('party_$key');
  }

  static List<Map<String, dynamic>> getPartyList(String key) {
    return List<Map<String, dynamic>>.from(_cache['party_$key'] ?? []);
  }

  static void setPartyList(String key, List<Map<String, dynamic>> list) {
    _cache['party_$key'] = list;
  }

  static void clearOrderTypeCache(String orderType) {
    _cache.remove('party_$orderType');
    _cache.remove('items_$orderType');
  }

  static bool hasItems(String key) {
    return _cache.containsKey('items_$key');
  }

  static List<Map<String, dynamic>> getItems(String key) {
    return List<Map<String, dynamic>>.from(_cache['items_$key'] ?? []);
  }

  static void setItems(String key, List<dynamic> list) {
    _cache['items_$key'] = list;
  }

  static List<Map<String, dynamic>> get partyList {
    return List<Map<String, dynamic>>.from(_cache['party_SALES'] ?? _cache['party_PURCHASE'] ?? []);
  }
}
