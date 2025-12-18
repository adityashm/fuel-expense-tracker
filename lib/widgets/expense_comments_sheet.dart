import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense_comment.dart';
import '../providers/collaboration_provider.dart';
import '../providers/device_provider.dart';

class ExpenseCommentsSheet extends StatefulWidget {
  const ExpenseCommentsSheet({
    super.key,
    required this.type,
    required this.expenseId,
  });
  final ExpenseType type;
  final int expenseId;

  @override
  State<ExpenseCommentsSheet> createState() => _ExpenseCommentsSheetState();
}

class _ExpenseCommentsSheetState extends State<ExpenseCommentsSheet> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CollaborationProvider>(context, listen: false)
          .loadComments(widget.type, widget.expenseId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments =
        context.select<CollaborationProvider, List<ExpenseComment>>(
      (provider) => provider.commentsFor(widget.type, widget.expenseId),
    );

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Text('Comments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (comments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No comments yet. Start the conversation!'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(comment.message),
                      subtitle: Text(
                        comment.createdAt.toLocal().toString().substring(0, 16),
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _isSending ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    final device =
        Provider.of<DeviceProvider>(context, listen: false).currentDevice;
    if (device == null) return;

    setState(() => _isSending = true);
    final provider = Provider.of<CollaborationProvider>(context, listen: false);
    await provider.addComment(
      ExpenseComment(
        type: widget.type,
        expenseId: widget.expenseId,
        deviceId: device.deviceId,
        message: _controller.text.trim(),
      ),
    );
    _controller.clear();
    setState(() => _isSending = false);
  }
}
