import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';

import '../utils/color_helper.dart';

class TimerPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const TimerPage({
    Key? key,
    required this.themeMode,
    required this.onThemeModeChanged,
  }) : super(key: key);

  @override
  _TimerPageState createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> with TickerProviderStateMixin {
  Timer? _timer;
  Timer? _stopwatchTimer;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  int _stopwatchSeconds = 0;
  bool _isRunning = false;
  bool _isStopwatchMode = false;
  bool _isPaused = false;

  int _totalWorkTimeSeconds = 0;
  int _totalRestTimeSeconds = 0;
  int _restMinutesFor50Work = 10;

  late AnimationController _flipController;
  late AnimationController _progressController;
  late Animation<double> _flipAnimation;
  late Animation<double> _progressAnimation;

  Color _selectedColor = Colors.blue;
  List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
  ];

  bool _isFirstTime = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _setupAnimations();
  }

  void _setupAnimations() {
    _flipController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );
  }

  Future<void> _initializeApp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      _totalWorkTimeSeconds = prefs.getInt('totalWorkTime') ?? 0;
      _totalRestTimeSeconds = prefs.getInt('totalRestTime') ?? 0;
      _restMinutesFor50Work = prefs.getInt('restFor50Work') ?? 10;
      _isFirstTime = prefs.getBool('isFirstTime') ?? true;
      int colorIndex = prefs.getInt('selectedColor') ?? 0;
      _selectedColor = _availableColors[colorIndex];
    });

    if (_isFirstTime) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFirstTimeDialog();
      });
    }
  }

  void _showFirstTimeDialog() {
    TextEditingController controller = TextEditingController(text: '10');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Welcome to Productivity Timer!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How many minutes of rest do you deserve for 50 minutes of work?',
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Rest minutes',
                border: OutlineInputBorder(),
                suffixText: 'minutes',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              int restMinutes = int.tryParse(controller.text) ?? 10;
              if (restMinutes <= 0) restMinutes = 10;
              _setRestMinutes(restMinutes);
              Navigator.of(context).pop();
            },
            child: Text('Set'),
          ),
        ],
      ),
    );
  }

  Future<void> _setRestMinutes(int minutes) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('restFor50Work', minutes);
    await prefs.setBool('isFirstTime', false);

    setState(() {
      _restMinutesFor50Work = minutes;
      _isFirstTime = false;
    });

    Fluttertoast.showToast(
      msg: "Rest time set to $minutes minutes for 50 minutes of work!",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _startTimer(int minutes) {
    if (_isRunning && !_isPaused) return;

    if (_isPaused) {
      // Resume
      setState(() {
        _isPaused = false;
      });
      _startCounting();
      Fluttertoast.showToast(
        msg: "Timer resumed!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    setState(() {
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
      _isRunning = true;
      _isStopwatchMode = false;
      _isPaused = false;
    });

    _flipController.forward();
    _progressController.forward();

    _startCounting();

    Fluttertoast.showToast(
      msg: "Timer started for $minutes minutes!",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _startCounting() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isPaused) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _completeTimer();
        }
      });
    });
  }

  void _startStopwatch() {
    if (_isRunning && !_isPaused) return;

    if (_isPaused) {
      // Resume stopwatch
      setState(() {
        _isPaused = false;
      });
      _startStopwatchCounting();
      Fluttertoast.showToast(
        msg: "Stopwatch resumed!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    setState(() {
      _stopwatchSeconds = 0;
      _isRunning = true;
      _isStopwatchMode = true;
      _isPaused = false;
    });

    _flipController.forward();
    _progressController.forward();

    _startStopwatchCounting();

    Fluttertoast.showToast(
      msg: "Stopwatch started!",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _startStopwatchCounting() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isPaused) return;
      setState(() {
        _stopwatchSeconds++;
        if (_stopwatchSeconds > 50 * 60) {
          _progressController.stop();
        }
      });
    });
  }

  void _pauseTimer() {
    if (!_isRunning || _isPaused) return;
    setState(() {
      _isPaused = true;
    });
    Fluttertoast.showToast(
      msg: "Timer paused!",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _stopwatchTimer?.cancel();

    if (_isRunning) {
      int workedSeconds = _isStopwatchMode
          ? _stopwatchSeconds
          : (_totalSeconds - _remainingSeconds);
      _updateWorkTime(workedSeconds);
    }

    setState(() {
      _isRunning = false;
      _remainingSeconds = 0;
      _stopwatchSeconds = 0;
      _isPaused = false;
    });

    _flipController.reverse();
    _progressController.reset();

    Fluttertoast.showToast(
      msg: "Timer stopped!",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _completeTimer() {
    _timer?.cancel();
    _updateWorkTime(_totalSeconds);

    int restTime = (_totalSeconds / (50 * 60) * _restMinutesFor50Work * 60)
        .round();
    _updateRestTime(restTime);

    setState(() {
      _isRunning = false;
      _remainingSeconds = 0;
      _isPaused = false;
    });

    _flipController.reverse();
    _progressController.reset();

    Fluttertoast.showToast(
      msg: "Timer completed! You earned ${_formatTime(restTime)} of rest!",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
    );
  }

  Future<void> _updateWorkTime(int seconds) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalWorkTimeSeconds += seconds;
    });
    await prefs.setInt('totalWorkTime', _totalWorkTimeSeconds);
  }

  Future<void> _updateRestTime(int seconds) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalRestTimeSeconds += seconds;
    });
    await prefs.setInt('totalRestTime', _totalRestTimeSeconds);
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  double get _progressValue {
    if (_isStopwatchMode) {
      double progress = _stopwatchSeconds / (50 * 60);
      return progress > 1.0 ? 1.0 : progress;
    } else if (_totalSeconds > 0) {
      return (_totalSeconds - _remainingSeconds) / _totalSeconds;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    Color timerTextColor = _isRunning
        ? getTextColorForBackground(_selectedColor)
        : _selectedColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Focus Flow'),
        centerTitle: true,
        backgroundColor: _selectedColor,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTimeStats(),
              SizedBox(height: 20),
              _buildProgressContainer(),
              SizedBox(height: 30),
              _buildTimerDisplay(timerTextColor),
              SizedBox(height: 30),
              _buildControlButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeStats() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Icon(Icons.work, color: _selectedColor, size: 30),
              SizedBox(height: 8),
              Text(
                'Total Work Time',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                _formatTime(_totalWorkTimeSeconds),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Column(
            children: [
              Icon(Icons.hotel, color: Colors.green, size: 30),
              SizedBox(height: 8),
              Text(
                'Total Rest Earned',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                _formatTime(_totalRestTimeSeconds),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressContainer() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Row(
          children: [
            Expanded(
              flex: 50,
              child: Container(
                height: double.infinity,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.grey[300],
                    ),
                    Container(
                      width: double
                          .infinity, // set parent width, controlled by parent Expanded flex
                      height: double.infinity,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progressValue.clamp(0.0, 1.0),
                        child: Container(color: _selectedColor),
                      ),
                    ),
                    Center(
                      child: Text(
                        'WORK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: _restMinutesFor50Work,
              child: Container(
                height: double.infinity,
                color: Colors.green[300],
                child: Center(
                  child: Text(
                    'REST',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

  Widget _buildTimerDisplay(Color timerTextColor) {
    return AnimatedBuilder(
      animation: _flipController,
      builder: (context, child) {
        if (_flipAnimation.value < 0.5) {
          return _buildCircularTimer(timerTextColor);
        } else {
          return _buildRectangularTimer(timerTextColor);
        }
      },
    );
  }

  Widget _buildCircularTimer(Color timerTextColor) {
    String displayTime = _isStopwatchMode
        ? _formatTime(_stopwatchSeconds)
        : _formatTime(_remainingSeconds);

    return GestureDetector(
      onTap: () {
        if (!_isRunning && !_isPaused) {
          _showTimerOptionsDialog();
        }
      },
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _selectedColor.withOpacity(0.1),
          border: Border.all(color: _selectedColor, width: 4),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayTime,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: timerTextColor,
                ),
              ),
              if (!_isRunning && !_isPaused)
                Text(
                  'Tap to start',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRectangularTimer(Color timerTextColor) {
    String displayTime = _isStopwatchMode
        ? _formatTime(_stopwatchSeconds)
        : _formatTime(_remainingSeconds);

    return Container(
      width: 250,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _selectedColor, width: 3),
      ),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Container(
                width: 250 * _progressValue,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(9),
                ),
              );
            },
          ),
          Center(
            child: Text(
              displayTime,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: timerTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    if (!_isRunning && !_isPaused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () => _startTimer(50),
            style: ElevatedButton.styleFrom(backgroundColor: _selectedColor),
            child: Text('50 min'),
          ),
          ElevatedButton(
            onPressed: () => _startTimer(25),
            style: ElevatedButton.styleFrom(backgroundColor: _selectedColor),
            child: Text('25 min'),
          ),
          ElevatedButton(
            onPressed: _startStopwatch,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Stopwatch'),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (!_isPaused)
            ElevatedButton(
              onPressed: _pauseTimer,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: Text('Pause', style: TextStyle(fontSize: 16)),
            )
          else
            ElevatedButton(
              onPressed: () {
                if (_isStopwatchMode) {
                  _startStopwatch();
                } else {
                  _startTimer(_remainingSeconds ~/ 60);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Resume', style: TextStyle(fontSize: 16)),
            ),
          ElevatedButton(
            onPressed: _stopTimer,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Stop', style: TextStyle(fontSize: 16)),
          ),
        ],
      );
    }
  }

  void _showTimerOptionsDialog() {
    TextEditingController customController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Timer Duration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('50 minutes'),
                onTap: () {
                  Navigator.pop(context);
                  _startTimer(50);
                },
              ),
              ListTile(
                title: Text('40 minutes'),
                onTap: () {
                  Navigator.pop(context);
                  _startTimer(40);
                },
              ),
              ListTile(
                title: Text('25 minutes'),
                onTap: () {
                  Navigator.pop(context);
                  _startTimer(25);
                },
              ),
              ListTile(title: Text('Custom Duration'), onTap: () {}),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: customController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Enter minutes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              int? customMinutes = int.tryParse(customController.text);
              if (customMinutes != null && customMinutes > 0) {
                Navigator.pop(context);
                _startTimer(customMinutes);
              } else {
                Fluttertoast.showToast(
                  msg: "Please enter a valid number of minutes.",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.CENTER,
                );
              }
            },
            child: Text('Start Custom'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    TextEditingController restController = TextEditingController(
      text: _restMinutesFor50Work.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Settings'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: restController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Rest minutes for 50 min work',
                      border: OutlineInputBorder(),
                      suffixText: 'minutes',
                    ),
                  ),
                  SizedBox(height: 20),

                  Text('Choose App Color:'),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 15,
                    runSpacing: 10,
                    children: _availableColors.map((color) {
                      return GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            _selectedColor = color;
                          });
                          _saveSelectedColor(color);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: _selectedColor == color
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 30),

                  Text('Theme Mode:'),
                  SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Radio<ThemeMode>(
                          value: ThemeMode.light,
                          groupValue: widget.themeMode,
                          onChanged: (val) {
                            if (val != null) {
                              widget.onThemeModeChanged(val);
                              setStateDialog(() {});
                            }
                          },
                        ),
                        title: Text('Light'),
                        onTap: () {
                          widget.onThemeModeChanged(ThemeMode.light);
                          setStateDialog(() {});
                        },
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Radio<ThemeMode>(
                          value: ThemeMode.dark,
                          groupValue: widget.themeMode,
                          onChanged: (val) {
                            if (val != null) {
                              widget.onThemeModeChanged(val);
                              setStateDialog(() {});
                            }
                          },
                        ),
                        title: Text('Dark'),
                        onTap: () {
                          widget.onThemeModeChanged(ThemeMode.dark);
                          setStateDialog(() {});
                        },
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Radio<ThemeMode>(
                          value: ThemeMode.system,
                          groupValue: widget.themeMode,
                          onChanged: (val) {
                            if (val != null) {
                              widget.onThemeModeChanged(val);
                              setStateDialog(() {});
                            }
                          },
                        ),
                        title: Text('System'),
                        onTap: () {
                          widget.onThemeModeChanged(ThemeMode.system);
                          setStateDialog(() {});
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // New Reset Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    onPressed: () async {
                      bool confirm =
                          await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Confirm Reset'),
                              content: Text(
                                'Are you sure you want to reset total work time and rest time earned? This cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text('Yes, Reset'),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (confirm) {
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.remove('totalWorkTime');
                        await prefs.remove('totalRestTime');
                        setStateDialog(() {
                          _totalWorkTimeSeconds = 0;
                          _totalRestTimeSeconds = 0;
                        });
                        setState(() {
                          _totalWorkTimeSeconds = 0;
                          _totalRestTimeSeconds = 0;
                        });
                        Fluttertoast.showToast(
                          msg: "Work time and rest time reset.",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                        );
                      }
                    },
                    child: Text('Reset Work and Rest Times'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  int newRestMinutes =
                      int.tryParse(restController.text) ??
                      _restMinutesFor50Work;
                  if (newRestMinutes <= 0) newRestMinutes = 10;
                  _setRestMinutes(newRestMinutes);
                  Navigator.pop(context);
                },
                child: Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveSelectedColor(Color color) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int colorIndex = _availableColors.indexOf(color);
    await prefs.setInt('selectedColor', colorIndex);
    setState(() {
      _selectedColor = color;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatchTimer?.cancel();
    _flipController.dispose();
    _progressController.dispose();
    super.dispose();
  }
}
