import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_colors.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String? messageId;
  final String? mediaUrl;
  final int durationSeconds;
  final bool isOutgoing;

  // Global notifier to ensure only one audio message plays at a time
  static final ValueNotifier<String?> currentlyPlayingId = ValueNotifier<String?>(null);

  const VoiceMessagePlayer({
    super.key,
    this.messageId,
    this.mediaUrl,
    required this.durationSeconds,
    required this.isOutgoing,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  double _playbackProgress = 0.0;
  double _speed = 1.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _resolvedLocalPath;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  final List<double> _barHeights = [
    0.3, 0.6, 0.8, 0.4, 0.7, 1.0, 0.5, 0.3, 0.7, 0.9,
    0.4, 0.8, 0.6, 0.3, 0.7, 0.5, 0.9, 0.4, 0.6, 0.8,
    0.5, 0.3, 0.7, 0.4, 0.6, 0.8, 0.3, 0.5, 0.9, 0.4,
  ];

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(seconds: widget.durationSeconds > 0 ? widget.durationSeconds : 1);
    VoiceMessagePlayer.currentlyPlayingId.addListener(_onGlobalPlayingChanged);

    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed) {
          _playbackProgress = 0.0;
          _currentPosition = Duration.zero;
          if (VoiceMessagePlayer.currentlyPlayingId.value == widget.messageId) {
            VoiceMessagePlayer.currentlyPlayingId.value = null;
          }
        }
      });
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
        final totalMs = _totalDuration.inMilliseconds;
        if (totalMs > 0) {
          _playbackProgress = (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
        }
      });
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((dur) {
      if (!mounted) return;
      if (dur.inMilliseconds > 0) {
        setState(() {
          _totalDuration = dur;
        });
      }
    });
  }

  void _onGlobalPlayingChanged() {
    final activeId = VoiceMessagePlayer.currentlyPlayingId.value;
    if (activeId != null && activeId != widget.messageId && _isPlaying) {
      _stopPlayback();
    }
  }

  @override
  void dispose() {
    VoiceMessagePlayer.currentlyPlayingId.removeListener(_onGlobalPlayingChanged);
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _audioPlayer.dispose();
    if (VoiceMessagePlayer.currentlyPlayingId.value == widget.messageId) {
      VoiceMessagePlayer.currentlyPlayingId.value = null;
    }
    super.dispose();
  }

  Future<void> _stopPlayback() async {
    try {
      await _audioPlayer.pause();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<Source?> _resolveSource() async {
    final raw = widget.mediaUrl;
    if (raw == null || raw.isEmpty) return null;

    // Check if it's a data URI (base64 encoded audio)
    if (raw.startsWith('data:audio/') || raw.startsWith('data:application/')) {
      if (_resolvedLocalPath != null && await File(_resolvedLocalPath!).exists()) {
        return DeviceFileSource(_resolvedLocalPath!);
      }
      try {
        final commaIdx = raw.indexOf(',');
        final base64Str = commaIdx != -1 ? raw.substring(commaIdx + 1) : raw;
        final bytes = base64Decode(base64Str);
        final tempDir = await getTemporaryDirectory();
        final cacheFile = File('${tempDir.path}/cached_voice_${widget.messageId ?? DateTime.now().millisecondsSinceEpoch}.m4a');
        await cacheFile.writeAsBytes(bytes);
        _resolvedLocalPath = cacheFile.path;
        return DeviceFileSource(cacheFile.path);
      } catch (e) {
        debugPrint('Error decoding base64 voice message: $e');
        return null;
      }
    }

    // Check if it's an online HTTP/HTTPS URL
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return UrlSource(raw);
    }

    // Check if local file exists
    final localFile = File(raw);
    if (await localFile.exists()) {
      return DeviceFileSource(raw);
    }

    return null;
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _stopPlayback();
      if (VoiceMessagePlayer.currentlyPlayingId.value == widget.messageId) {
        VoiceMessagePlayer.currentlyPlayingId.value = null;
      }
    } else {
      if (widget.messageId != null) {
        VoiceMessagePlayer.currentlyPlayingId.value = widget.messageId;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final source = await _resolveSource();
        if (source == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Audio file is unavailable or corrupted.'),
                backgroundColor: AppColors.errorRed,
              ),
            );
          }
          return;
        }

        await _audioPlayer.setPlaybackRate(_speed);
        await _audioPlayer.play(source);

        if (mounted) {
          setState(() {
            _isLoading = false;
            _isPlaying = true;
          });
        }
      } catch (e) {
        debugPrint('Playback error: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isPlaying = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not play audio: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _seekTo(double progress) async {
    final clamped = progress.clamp(0.0, 1.0);
    final targetMs = (_totalDuration.inMilliseconds * clamped).round();
    final targetDur = Duration(milliseconds: targetMs);

    setState(() {
      _playbackProgress = clamped;
      _currentPosition = targetDur;
    });

    try {
      await _audioPlayer.seek(targetDur);
    } catch (_) {}
  }

  Future<void> _cycleSpeed() async {
    final nextSpeed = _speed == 1.0
        ? 1.5
        : (_speed == 1.5 ? 2.0 : 1.0);

    setState(() {
      _speed = nextSpeed;
    });

    try {
      await _audioPlayer.setPlaybackRate(_speed);
    } catch (_) {}
  }

  String _formatSeconds(int fallbackTotalSec) {
    if (_isPlaying || _currentPosition > Duration.zero) {
      final s = _currentPosition.inSeconds;
      final m = s ~/ 60;
      final rem = s % 60;
      return '$m:${rem.toString().padLeft(2, '0')}';
    }
    final effectiveTotalSec = _totalDuration.inSeconds > 0
        ? _totalDuration.inSeconds
        : fallbackTotalSec;
    final m = effectiveTotalSec ~/ 60;
    final s = effectiveTotalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = widget.isOutgoing
        ? (isDark ? Colors.white : AppColors.lightPrimary)
        : AppColors.teal;
    final inactiveColor = (isDark ? Colors.white24 : Colors.black12);

    return SizedBox(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Play / Pause Circle
              InkWell(
                onTap: _togglePlayPause,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.isOutgoing
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : AppColors.lightPrimary.withValues(alpha: 0.12))
                        : AppColors.teal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: activeColor,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 8),

              // Interactive Waveform bars with seeking
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        if (totalWidth > 0) {
                          _seekTo(details.localPosition.dx / totalWidth);
                        }
                      },
                      onHorizontalDragUpdate: (details) {
                        if (totalWidth > 0) {
                          _seekTo(details.localPosition.dx / totalWidth);
                        }
                      },
                      child: SizedBox(
                        height: 30,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(_barHeights.length, (index) {
                            final barProgress = index / _barHeights.length;
                            final isPassed = barProgress <= _playbackProgress;
                            return Container(
                              width: 3,
                              height: 24 * _barHeights[index],
                              decoration: BoxDecoration(
                                color: isPassed ? activeColor : inactiveColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Duration & Speed badge
          Padding(
            padding: const EdgeInsets.only(left: 46, right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatSeconds(widget.durationSeconds),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: _cycleSpeed,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_speed.toStringAsFixed(_speed == 1.0 || _speed == 2.0 ? 0 : 1)}x',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
