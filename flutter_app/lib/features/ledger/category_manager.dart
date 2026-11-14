import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_tokens.dart';
import '../../data/constants.dart';
import '../../data/ledger.dart';
import '../../data/models.dart';
import '../../state/app_controller.dart';
import '../../ui/dialog.dart';
import '../../ui/sheet.dart';
import '../../ui/widgets.dart';

/// 分类管理：默认分类只读，自定义分类可增删（使用中禁止删除）。
Future<void> showCategoryManager(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => const CategoryManagerSheet(),
  );
}

class CategoryManagerSheet extends ConsumerStatefulWidget {
  const CategoryManagerSheet({super.key});

  @override
  ConsumerState<CategoryManagerSheet> createState() =>
      _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends ConsumerState<CategoryManagerSheet> {
  final TextEditingController _name = TextEditingController();
  LedgerType _type = LedgerType.expense;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _add() {
    final ok = ref
        .read(appControllerProvider.notifier)
        .addCustomCategory(_type, _name.text);
    setState(() {
      _message = ok ? null : '名称为空、重复或与默认分类冲突';
    });
    if (ok) _name.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(appControllerProvider);
    final custom = state.customCategories;
    return SheetScaffold(
      title: '分类管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Segmented<LedgerType>(
            values: const [LedgerType.expense, LedgerType.income],
            selected: _type,
            labelOf: (type) => type == LedgerType.expense ? '支出分类' : '收入分类',
            onChanged: (type) => setState(() => _type = type),
          ),
          const SizedBox(height: Gaps.lg),
          Text(
            '默认分类',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.text2,
            ),
          ),
          const SizedBox(height: Gaps.sm),
          Wrap(
            spacing: Gaps.sm,
            runSpacing: Gaps.sm,
            children: [
              for (final name in defaultCategoriesOf(_type))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: ShapeDecoration(
                    color: colors.block,
                    shape: Radii.pillShape,
                  ),
                  child: Text(
                    name,
                    style: TextStyle(fontSize: 12, color: colors.text2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gaps.xl),
          Text(
            '自定义分类',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.text2,
            ),
          ),
          const SizedBox(height: Gaps.sm),
          if (custom.where((c) => c.type == _type).isEmpty)
            Text(
              '还没有自定义分类',
              style: TextStyle(fontSize: 13, color: colors.text2),
            )
          else
            for (final category in custom.where((c) => c.type == _type))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        style: TextStyle(fontSize: 14, color: colors.text),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: '删除${category.name}',
                      onTap: () {
                        _delete(category);
                      },
                      excludeSemantics: true,
                      child: Pressable(
                        onTap: () {
                          _delete(category);
                        },
                        shape: Radii.shape(12),
                        pressedScale: 0.90,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: colors.text2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: Gaps.lg),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  maxLength: maxCategoryNameLength,
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '新分类名称',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: Gaps.sm),
              GhostButton(label: '添加', onPressed: _add),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: Gaps.sm),
            Text(
              _message!,
              style: TextStyle(fontSize: 12, color: colors.expense),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _delete(CustomLedgerCategory category) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除「${category.name}」？',
      description: '已被账目使用的分类不能删除。',
      confirmLabel: '删除',
      danger: true,
    );
    if (confirmed != true || !mounted) return;

    final ok = ref
        .read(appControllerProvider.notifier)
        .deleteCustomCategory(category.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('该分类已被账目使用，不能删除')));
    }
  }
}
