/// 首页可自定义卡片。
///
/// 今日概览与日历固定存在；这里只管理它们之间的月汇总卡。
/// id 写入 SharedPreferences，不能随显示文案变化。
abstract final class DashboardCardIds {
  static const monthQuantity = 'month_quantity';
  static const monthSalary = 'month_salary';
  static const ledgerBalance = 'ledger_balance';
  static const todayLedger = 'today_ledger';

  static const defaults = <String>[monthQuantity, monthSalary, todayLedger];

  static const all = <String>{
    monthQuantity,
    monthSalary,
    ledgerBalance,
    todayLedger,
  };

  static List<String> sanitize(Iterable<String> input) {
    final seen = <String>{};
    return [
      for (final id in input)
        if (all.contains(id) && seen.add(id)) id,
    ];
  }

  static bool sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
