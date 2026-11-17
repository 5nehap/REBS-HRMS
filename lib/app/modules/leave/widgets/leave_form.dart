import 'package:flutter/material.dart';

class LeaveForm extends StatelessWidget {
  final TextEditingController? reasonController;
  final VoidCallback? onSubmit;

  const LeaveForm({super.key, this.reasonController, this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason for Leave',
              hintText: 'Enter reason...',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onSubmit,
            child: const Text('Submit Application'),
          ),
        ],
      ),
    );
  }
}
