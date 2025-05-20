import 'package:flutter/material.dart';
import '../../../../../core/theme/theme_constants.dart';
import '../../../../global_widgets/custom_text_field.dart';

class SignUpStep3College extends StatelessWidget {
  final TextEditingController collegeController;
  final List<String> collegeSuggestions; // Original 'colleges' list
  final Function(String)
      onCollegeSelectedFromChip; // Callback when chip is selected

  const SignUpStep3College({
    Key? key,
    required this.collegeController,
    required this.collegeSuggestions,
    required this.onCollegeSelectedFromChip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Center(
            child: Text("Select Your College",
                style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: 20),
        CustomTextField(
          controller: collegeController,
          labelText: 'College/University Name *',
          prefixIcon: const Icon(Icons.school_outlined),
          validator: (v) =>
              v!.trim().isEmpty ? 'College/University required' : null,
        ),
        const SizedBox(height: 20),
        Text("Or quick select:", style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: collegeSuggestions.map((college) {
            // Selection state will be managed by the parent based on controller's text
            // or a dedicated _selectedCollege string if preferred for chip state.
            // For simplicity, the controller's text can drive chip selection for now.
            final isSelected = collegeController.text == college;
            return ChoiceChip(
              label: Text(college),
              selected: isSelected,
              onSelected: (_) => onCollegeSelectedFromChip(college),
              selectedColor: primaryColor.withOpacity(0.8),
              labelStyle: TextStyle(color: isSelected ? Colors.white : null),
              checkmarkColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          }).toList(),
        ),
      ],
    );
  }
}
