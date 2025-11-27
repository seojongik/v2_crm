class SideBarState {
  static final SideBarState _instance = SideBarState._internal();
  factory SideBarState() => _instance;
  SideBarState._internal();

  Map<String, bool> expandedMenus = {};
  bool isCollapsed = false; // 사이드바 축소 상태 추가

  void setExpanded(String menuKey, bool isExpanded) {
    expandedMenus[menuKey] = isExpanded;
  }

  bool isExpanded(String menuKey) {
    return expandedMenus[menuKey] ?? false;
  }

  void clearAll() {
    expandedMenus.clear();
  }

  void clearExcept(String menuKey) {
    final currentExpanded = expandedMenus[menuKey] ?? false;
    expandedMenus.clear();
    if (currentExpanded) {
      expandedMenus[menuKey] = true;
    }
  }
}