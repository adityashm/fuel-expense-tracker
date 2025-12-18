import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../providers/expense_provider.dart';
import '../services/voice_entry_service.dart';
import '../utils/app_design_system.dart';
import '../utils/haptic_helper.dart';
import 'add_expense_v2_screen.dart';

/// V2.5 Voice Entry Screen
/// Hands-free expense entry using speech recognition
class VoiceEntryScreen extends StatefulWidget {
  const VoiceEntryScreen({super.key});

  @override
  State<VoiceEntryScreen> createState() => _VoiceEntryScreenState();
}

class _VoiceEntryScreenState extends State<VoiceEntryScreen>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final VoiceEntryService _voiceService = VoiceEntryService.instance;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _hasError = false;
  String _recognizedText = '';
  String _errorMessage = '';
  ParsedVoiceExpense? _parsedExpense;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _setupAnimation();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );

      if (mounted) {
        setState(() {
          _isInitialized = available;
          if (!available) {
            _hasError = true;
            _errorMessage = 'Speech recognition not available on this device';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize speech recognition';
        });
      }
    }
  }

  void _onSpeechStatus(String status) {
    debugPrint('Speech status: $status');
    if (status == 'done' && _recognizedText.isNotEmpty) {
      _processRecognizedText();
    }
  }

  void _onSpeechError(Object error) {
    debugPrint('Speech error: $error');
    if (mounted) {
      setState(() {
        _isListening = false;
        _hasError = true;
        _errorMessage = 'Could not recognize speech. Please try again.';
      });
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized) return;

    HapticHelper.mediumImpact();

    setState(() {
      _isListening = true;
      _hasError = false;
      _recognizedText = '';
      _parsedExpense = null;
    });

    await _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN', // Indian English
    );
  }

  Future<void> _stopListening() async {
    HapticHelper.lightImpact();
    await _speech.stop();

    if (mounted) {
      setState(() => _isListening = false);
    }

    if (_recognizedText.isNotEmpty) {
      _processRecognizedText();
    }
  }

  void _onSpeechResult(Object? result) {
    if (!mounted || result == null) return;

    // ignore: avoid_dynamic_calls
    final words = (result as dynamic).recognizedWords as String? ?? '';
    setState(() {
      _recognizedText = words;
    });

    // Parse in real-time for preview
    if (words.isNotEmpty) {
      _parsedExpense = _voiceService.parseVoiceText(words);
    }
  }

  void _processRecognizedText() {
    if (_recognizedText.isEmpty) return;

    final parsed = _voiceService.parseVoiceText(_recognizedText);

    // Check if it's a query instead of an expense
    final queryType = _voiceService.parseQuery(_recognizedText);
    if (queryType != null) {
      _handleQuery(queryType);
      return;
    }

    setState(() => _parsedExpense = parsed);

    if (parsed.isValid) {
      HapticHelper.success();
    }
  }

  Future<void> _handleQuery(VoiceQueryType queryType) async {
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);
    String message = '';

    switch (queryType) {
      case VoiceQueryType.todayTotal:
        final total = await expenseProvider.getTotalFuelExpensesFromDb() +
            await expenseProvider.getTotalGeneralExpensesFromDb() +
            await expenseProvider.getTotalHouseholdExpensesFromDb();
        message = 'Total spent today: \$${total.toStringAsFixed(2)}';
        break;
      case VoiceQueryType.monthTotal:
        final fuel = await expenseProvider.getTotalFuelExpensesFromDb();
        final general = await expenseProvider.getTotalGeneralExpensesFromDb();
        final household =
            await expenseProvider.getTotalHouseholdExpensesFromDb();
        message =
            'Monthly total: \$${(fuel + general + household).toStringAsFixed(2)}';
        break;
      case VoiceQueryType.categoryTotal:
        final fuel = await expenseProvider.getTotalFuelExpensesFromDb();
        message = 'Fuel expenses: \$${fuel.toStringAsFixed(2)}';
        break;
      case VoiceQueryType.weekTotal:
        message = 'Calculating weekly expenses...';
        break;
      case VoiceQueryType.showExpenses:
        message = 'Showing recent expenses...';
        break;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _confirmAndSave() {
    if (_parsedExpense == null || !_parsedExpense!.isValid) return;

    HapticHelper.mediumImpact();

    // Navigate to add expense screen with pre-filled data
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AddExpenseV2Screen(
          initialAmount: _parsedExpense!.amount,
          initialCategory: _parsedExpense!.category,
        ),
      ),
    );
  }

  void _reset() {
    HapticHelper.lightImpact();
    setState(() {
      _recognizedText = '';
      _parsedExpense = null;
      _hasError = false;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Voice Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: _buildContent(theme),
              ),
              _buildBottomActions(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_hasError) {
      return _buildErrorState(theme);
    }

    if (_parsedExpense != null && _parsedExpense!.isValid) {
      return _buildParsedResult(theme);
    }

    return _buildListeningState(theme);
  }

  Widget _buildListeningState(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Microphone button with pulse animation
        GestureDetector(
          onTapDown: (_) => _startListening(),
          onTapUp: (_) => _stopListening(),
          onTapCancel: _stopListening,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isListening ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: _isListening ? AppColors.primaryGradient : null,
                    color: _isListening
                        ? null
                        : theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_rounded,
                    size: 48,
                    color:
                        _isListening ? Colors.white : theme.colorScheme.primary,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),

        // Status text
        Text(
          _isListening ? 'Listening...' : 'Hold to speak',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isListening
              ? 'Say something like "Add 500 for groceries"'
              : 'Tap and hold the microphone to start',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),

        // Recognized text preview
        if (_recognizedText.isNotEmpty) ...[
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _recognizedText,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_parsedExpense != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildParsePreview(theme),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildParsePreview(ThemeData theme) {
    final parsed = _parsedExpense!;

    return Row(
      children: [
        if (parsed.amount != null)
          _buildChip(
            theme,
            '₹${parsed.amount!.toStringAsFixed(0)}',
            AppColors.success,
          ),
        if (parsed.category != null)
          _buildChip(theme, parsed.category!, AppColors.info),
        if (parsed.merchant != null)
          _buildChip(theme, parsed.merchant!, AppColors.warning),
      ],
    );
  }

  Widget _buildChip(ThemeData theme, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildParsedResult(ThemeData theme) {
    final parsed = _parsedExpense!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Success icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Got it!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),

        // Parsed expense card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Amount
                Text(
                  '₹${parsed.amount!.toStringAsFixed(0)}',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // Category
                if (parsed.category != null)
                  _buildDetailRow(
                    theme,
                    Icons.category_rounded,
                    'Category',
                    parsed.category!,
                  ),

                // Merchant
                if (parsed.merchant != null)
                  _buildDetailRow(
                    theme,
                    Icons.store_rounded,
                    'Merchant',
                    parsed.merchant!,
                  ),

                // Date
                _buildDetailRow(
                  theme,
                  Icons.calendar_today_rounded,
                  'Date',
                  _formatDate(parsed.date),
                ),

                // Split indicator
                if (parsed.isSplit)
                  _buildDetailRow(
                    theme,
                    Icons.people_rounded,
                    'Split',
                    'With family',
                  ),

                const SizedBox(height: 16),

                // Confidence indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      parsed.isHighConfidence
                          ? Icons.verified_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: parsed.isHighConfidence
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      parsed.isHighConfidence
                          ? 'High confidence'
                          : 'Please verify details',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: parsed.isHighConfidence
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Oops!',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
        ),
      ],
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    if (_parsedExpense != null && _parsedExpense!.isValid) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _confirmAndSave,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _reset,
            child: const Text('Try again'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  void _showHelp() {
    final suggestions = _voiceService.getSuggestedCommands();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice Commands',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try saying:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            ...suggestions.map(
              (cmd) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.format_quote_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '"$cmd"',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == today.subtract(const Duration(days: 1))) return 'Yesterday';

    return '${date.day}/${date.month}/${date.year}';
  }
}
