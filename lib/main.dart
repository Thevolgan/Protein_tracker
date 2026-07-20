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
  bool _editingGoal = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      goal = p.getInt(_goalKey) ?? 140;
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
    _save();
  }

  void _remove(String id) {
    setState(() => entries.removeWhere((e) => e.id == id));
    _save();
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

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
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
                      onPressed: () => setState(() => _editingGoal = !_editingGoal),
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
                              controller: TextEditingController(text: goal.toString()),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E5EA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              onSubmitted: (v) {
                                setState(() => goal = int.tryParse(v) ?? goal);
                                _save();
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
                        decoration: const BoxDecoration(),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: CupertinoTextField(
                        controller: _grams,
                        placeholder: '30',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              ],
            ),
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
