import 'package:hive_ce/hive_ce.dart';

import '../models/budget_item.dart';
import '../models/entry.dart';
import '../models/month_budget.dart';

/// Hand-written adapters, so the project needs no `build_runner` step.
///
/// Each adapter writes a leading field count. New fields must be **appended**
/// and guarded by that count, so a box written by an older build still reads.
abstract final class HiveTypeIds {
  static const entry = 1;
  static const budgetItem = 2;
  static const monthBudget = 3;
}

class EntryAdapter extends TypeAdapter<Entry> {
  @override
  final int typeId = HiveTypeIds.entry;

  @override
  Entry read(BinaryReader reader) {
    final fields = reader.readByte();
    final id = reader.readString();
    final amountPaise = reader.readInt();
    final isCredit = reader.readBool();
    final category = reader.readString();
    final date = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final note = fields > 5 ? reader.readString() : '';
    final createdAt = fields > 6
        ? DateTime.fromMillisecondsSinceEpoch(reader.readInt())
        : date;
    return Entry(
      id: id,
      amountPaise: amountPaise,
      isCredit: isCredit,
      category: category,
      date: date,
      note: note,
      createdAt: createdAt,
    );
  }

  @override
  void write(BinaryWriter writer, Entry obj) {
    writer
      ..writeByte(7)
      ..writeString(obj.id)
      ..writeInt(obj.amountPaise)
      ..writeBool(obj.isCredit)
      ..writeString(obj.category)
      ..writeInt(obj.date.millisecondsSinceEpoch)
      ..writeString(obj.note)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}

class BudgetItemAdapter extends TypeAdapter<BudgetItem> {
  @override
  final int typeId = HiveTypeIds.budgetItem;

  @override
  BudgetItem read(BinaryReader reader) {
    reader.readByte(); // field count
    return BudgetItem(
      id: reader.readString(),
      name: reader.readString(),
      amountPaise: reader.readInt(),
      pinned: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, BudgetItem obj) {
    writer
      ..writeByte(4)
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeInt(obj.amountPaise)
      ..writeBool(obj.pinned);
  }
}

class MonthBudgetAdapter extends TypeAdapter<MonthBudget> {
  @override
  final int typeId = HiveTypeIds.monthBudget;

  @override
  MonthBudget read(BinaryReader reader) {
    reader.readByte(); // field count
    return MonthBudget(
      monthKey: reader.readString(),
      salaryPaise: reader.readInt(),
      items: reader.readList().cast<BudgetItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, MonthBudget obj) {
    writer
      ..writeByte(3)
      ..writeString(obj.monthKey)
      ..writeInt(obj.salaryPaise)
      ..writeList(obj.items);
  }
}
