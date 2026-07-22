import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const ProteinApp());

class ProteinApp extends StatelessWidget {
  const ProteinApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Protein',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFF0A84FF),
        scaffoldBackgroundColor: Color(0xFFF2F2F7),
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            color: Color(0xFF1C1C1E),
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
      ),
      home: HomePage(),
    );
  }
}

class Entry {
  final String id;
  final String name;
  final int grams;
  final DateTime at;
  Entry({required this.id, required this.name, required this.grams, required this.at});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'grams': grams, 'at': at.millisecondsSinceEpoch};

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'],
        name: j['name'],
        grams: j['grams'],
        at: DateTime.fromMillisecondsSinceEpoch(j['at']),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _goalKey = 'protein.goal';
  static const _entriesKey = 'protein.entries';

  int goal = 140;
  List<Entry> entries = [];
  final _name = TextEditingController();
  final _grams = TextEditingController();
  final _goalCtrl = TextEditingController();
  final _gramsFocus = FocusNode();
  bool _editingGoal = false;

  @override
  void initState() {
    super.initState();
    _goalCtrl.text = goal.toString();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _grams.dispose();
    _goalCtrl.dispose();
    _gramsFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      goal = p.getInt(_goalKey) ?? 140;
      _goalCtrl.text = goal.toString();
      final raw = p.getString(_entriesKey);
      if (raw != null) {
        entries = (jsonDecode(raw) as List)
            .map((e) => Entry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_goalKey, goal);
    await p.setString(_entriesKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  List<Entry> get todayEntries {
    final now = DateTime.now();
    return entries.where((e) =>
        e.at.year == now.year && e.at.month == now.month && e.at.day == now.day).toList();
  }

  void _add() {
    final n = _name.text.trim();
    final g = int.tryParse(_grams.text.trim());
    if (n.isEmpty || g == null || g <= 0) return;
    setState(() {
      entries.insert(
        0,
        Entry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: n,
          grams: g,
          at: DateTime.now(),
        ),
      );
      _name.clear();
      _grams.clear();
    });
    FocusScope.of(context).unfocus();
    _save();
  }

  void _remove(String id) {
    setState(() => entries.removeWhere((e) => e.id == id));
    _save();
  }

  void _openHistory() {
    showCupertinoModalPopup(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: _CalendarModal(
          entries: entries,
          goal: goal,
          onDelete: (id) {
            setState(() => entries.removeWhere((e) => e.id == id));
            _save();
          },
        ),
      ),
    );
  }

  /// Parses whatever is currently in the goal field, saves it if valid,
  /// and returns whether the save succeeded.
  bool _commitGoal() {
    final parsed = int.tryParse(_goalCtrl.text.trim());
    if (parsed == null || parsed <= 0) {
      // Invalid input: revert the field to the last known-good goal
      // instead of silently losing the user's progress.
      _goalCtrl.text = goal.toString();
      return false;
    }
    setState(() => goal = parsed);
    _save();
    return true;
  }

  void _toggleGoalEditing() {
    if (_editingGoal) {
      // Currently editing -> this tap is "Done": commit and close.
      _commitGoal();
      setState(() => _editingGoal = false);
      FocusScope.of(context).unfocus();
    } else {
      // Entering edit mode -> make sure the field shows the live goal.
      _goalCtrl.text = goal.toString();
      setState(() => _editingGoal = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = todayEntries;
    final total = today.fold<int>(0, (s, e) => s + e.grams);
    final pct = ((total / goal) * 100).clamp(0, 100).round();
    final remaining = math.max(0, goal - total);
    final now = DateTime.now();
    const weekdays = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    final dateStr = '${weekdays[now.weekday-1]}, ${months[now.month-1]} ${now.day}';

    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateStr.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                letterSpacing: 1.2, color: Color(0xFF8E8E93))),
                          const SizedBox(height: 4),
                          const Text('Protein',
                              style: TextStyle(
                                fontSize: 34, fontWeight: FontWeight.w700,
                                letterSpacing: -0.8, color: Color(0xFF1C1C1E))),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(100),
                      onPressed: _toggleGoalEditing,
                      child: Text(_editingGoal ? 'Done' : 'Goal',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: Color(0xFF1C1C1E))), minimumSize: Size(0, 0),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Ring card
                _Card(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 208, height: 208,
                        child: Stack(alignment: Alignment.center, children: [
                          CustomPaint(
                            size: const Size(208, 208),
                            painter: _RingPainter(progress: pct / 100),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('TODAY',
                                  style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    letterSpacing: 1.4, color: Color(0xFF8E8E93))),
                              const SizedBox(height: 4),
                              Text('$total',
                                  style: const TextStyle(
                                    fontSize: 56, fontWeight: FontWeight.w700,
                                    height: 1, letterSpacing: -1.5,
                                    color: Color(0xFF1C1C1E))),
                              const SizedBox(height: 6),
                              Text('of $goal g',
                                  style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500,
                                    color: Color(0xFF8E8E93))),
                            ],
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      if (_editingGoal)
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('Daily goal',
                              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            child: CupertinoTextField(
                              controller: _goalCtrl,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              textAlign: TextAlign.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E5EA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              onSubmitted: (v) {
                                if (_commitGoal()) {
                                  setState(() => _editingGoal = false);
                                }
                                FocusScope.of(context).unfocus();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('g', style: TextStyle(color: Color(0xFF8E8E93))),
                        ])
                      else
                        Row(children: [
                          Expanded(child: _Stat(label: 'PROGRESS', value: '$pct%')),
                          Container(width: 1, height: 32, color: const Color(0xFFE5E5EA)),
                          Expanded(child: _Stat(label: 'REMAINING', value: '$remaining g')),
                        ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Add form
                _Card(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _name,
                        placeholder: 'Chicken breast',
                        textInputAction: TextInputAction.next,
                        decoration: const BoxDecoration(),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(_gramsFocus),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: CupertinoTextField(
                        controller: _grams,
                        focusNode: _gramsFocus,
                        placeholder: '30',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        textAlign: TextAlign.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _add,
                      child: Container(
                        width: 44, height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1C1C1E), shape: BoxShape.circle),
                        child: const Icon(CupertinoIcons.add,
                            color: CupertinoColors.white, size: 20),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),

                // List header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("TODAY'S LOG",
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          letterSpacing: 1.2, color: Color(0xFF8E8E93))),
                    Text('${today.length} ${today.length == 1 ? "entry" : "entries"}',
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: Color(0xFF8E8E93))),
                  ]),
                ),
                const SizedBox(height: 8),

                if (today.isEmpty)
                  _Card(
                    padding: const EdgeInsets.all(36),
                    child: const Center(
                      child: Text('No entries yet. Add your first meal above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
                    ),
                  )
                else
                  _Card(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (int i = 0; i < today.length; i++) ...[
                          if (i != 0) Container(height: 1, color: const Color(0xFFE5E5EA), margin: const EdgeInsets.only(left: 66)),
                          _EntryTile(entry: today[i], onDelete: () => _remove(today[i].id)),
                        ]
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          // Fixed "Previous days" button, always pinned to the bottom of
          // the screen regardless of how far the list above is scrolled.
          // Hidden while the keyboard is open so it can't drift up over
          // the text fields.
          if (!keyboardOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 20 + MediaQuery.of(context).padding.bottom,
              child: Center(
                child: GestureDetector(
                  onTap: _openHistory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(CupertinoIcons.calendar, size: 18, color: CupertinoColors.white),
                        SizedBox(width: 8),
                        Text('Previous days',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600,
                                color: CupertinoColors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

class _CalendarModal extends StatefulWidget {
  final List<Entry> entries;
  final int goal;
  final void Function(String id) onDelete;
  const _CalendarModal({
    required this.entries,
    required this.goal,
    required this.onDelete,
  });

  @override
  State<_CalendarModal> createState() => _CalendarModalState();
}

class _CalendarModalState extends State<_CalendarModal> {
  late List<Entry> _entries;
  late DateTime _month; // first day of the displayed month
  late DateTime _selected;
  double _dragOffset = 0;
  bool _dragging = false;

  static const _weekdaysShort = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _weekdays = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  static const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  @override
  void initState() {
    super.initState();
    _entries = List.of(widget.entries);
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _onHandleDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragging = true;
      _dragOffset = math.max(0, _dragOffset + d.delta.dy);
    });
  }

  void _onHandleDragEnd(DragEndDetails d) {
    final velocity = d.velocity.pixelsPerSecond.dy;
    if (_dragOffset > 120 || velocity > 700) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragging = false;
        _dragOffset = 0;
      });
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Entry> _entriesFor(DateTime day) =>
      _entries.where((e) => _sameDay(e.at, day)).toList()
        ..sort((a, b) => b.at.compareTo(a.at));

  Set<String> get _daysWithEntries =>
      _entries.map((e) => '${e.at.year}-${e.at.month}-${e.at.day}').toSet();

  void _delete(String id) {
    setState(() => _entries.removeWhere((e) => e.id == id));
    widget.onDelete(id);
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  String _labelFor(DateTime d, DateTime now) {
    if (_sameDay(d, now)) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_sameDay(d, yesterday)) return 'Yesterday';
    return '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
  }

  Widget _buildGrid(DateTime now) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekdayOffset = _month.weekday % 7; // Sunday = 0
    final totalCells = firstWeekdayOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final daysWithEntries = _daysWithEntries;

    int dayCounter = 1;
    final rowWidgets = <Widget>[];
    for (int r = 0; r < rows; r++) {
      final cells = <Widget>[];
      for (int c = 0; c < 7; c++) {
        final cellIndex = r * 7 + c;
        if (cellIndex < firstWeekdayOffset || dayCounter > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 44)));
        } else {
          final date = DateTime(_month.year, _month.month, dayCounter);
          final isToday = _sameDay(date, now);
          final isSelected = _sameDay(date, _selected);
          final hasEntries = daysWithEntries.contains('${date.year}-${date.month}-${date.day}');
          cells.add(Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selected = date),
              child: Container(
                height: 44,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1C1C1E) : const Color(0x00000000),
                  shape: BoxShape.circle,
                  border: (isToday && !isSelected)
                      ? Border.all(color: const Color(0xFF0A84FF), width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$dayCounter',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: isSelected ? CupertinoColors.white : const Color(0xFF1C1C1E))),
                    if (hasEntries)
                      Container(
                        width: 4, height: 4,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? CupertinoColors.white : const Color(0xFF0A84FF),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ));
          dayCounter++;
        }
      }
      rowWidgets.add(Row(children: cells));
    }
    return Column(children: rowWidgets);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayEntries = _entriesFor(_selected);
    final total = dayEntries.fold<int>(0, (s, e) => s + e.grams);
    final pct = widget.goal > 0 ? ((total / widget.goal) * 100).clamp(0, 999).round() : 0;

    return AnimatedContainer(
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
      transform: Matrix4.translationValues(0, _dragOffset, 0),
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _onHandleDragUpdate,
                onVerticalDragEnd: _onHandleDragEnd,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Container(
                      width: 36, height: 5,
                      decoration: BoxDecoration(
                          color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                      onPressed: () => _changeMonth(-1),
                      child: const Icon(CupertinoIcons.chevron_left, size: 20),
                    ),
                    Text('${_months[_month.month - 1]} ${_month.year}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                      onPressed: () => _changeMonth(1),
                      child: const Icon(CupertinoIcons.chevron_right, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: _weekdaysShort
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(d,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: Color(0xFF8E8E93))),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildGrid(now),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFE5E5EA), margin: const EdgeInsets.symmetric(horizontal: 20)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_labelFor(_selected, now),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('$total g · $pct%',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (dayEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No entries for this day',
                      style: TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final e in dayEntries)
                        _EntryTile(entry: e, onDelete: () => _delete(e.id)),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: child,
      );
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                letterSpacing: 1.2, color: Color(0xFF8E8E93))),
      ]);
}

class _EntryTile extends StatelessWidget {
  final Entry entry;
  final VoidCallback onDelete;
  const _EntryTile({required this.entry, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final h = entry.at.hour, m = entry.at.minute;
    final hh = ((h % 12) == 0 ? 12 : h % 12);
    final ampm = h >= 12 ? 'PM' : 'AM';
    final time = '$hh:${m.toString().padLeft(2, '0')} $ampm';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF64A6FF), Color(0xFF7B5CFF)],
            ),
          ),
          child: Text('${entry.grams}',
              style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$time · ${entry.grams} g protein',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
            ],
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onDelete,
          child: const Icon(CupertinoIcons.delete, size: 18, color: Color(0xFF8E8E93)), minimumSize: Size(36, 36),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    final bg = Paint()
      ..color = const Color(0xFFE5E5EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawCircle(center, radius, bg);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final fg = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF64A6FF), Color(0xFF7B5CFF)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.progress != progress;
}
