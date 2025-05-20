import 'package:flutter/material.dart';
import '../../../../../core/theme/theme_constants.dart';

class SignUpStep4Interests extends StatelessWidget {
  final List<String> selectedInterests;
  final List<Map<String, dynamic>>
      availableInterestsData; // Original 'interests' list
  final Function(String, bool) onInterestToggled;

  const SignUpStep4Interests({
    Key? key,
    required this.selectedInterests,
    required this.availableInterestsData,
    required this.onInterestToggled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Center(
            child: Text("Select Your Interests",
                style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: 10),
        Text("Choose a few things you like (optional).",
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 15),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: availableInterestsData.length,
            itemBuilder: (context, index) {
              String name = availableInterestsData[index]["name"];
              IconData icon = availableInterestsData[index]["icon"];
              bool isSelected = selectedInterests.contains(name);

              return GestureDetector(
                onTap: () => onInterestToggled(name, !isSelected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : (isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100),
                    borderRadius:
                        BorderRadius.circular(ThemeConstants.borderRadius),
                    border: Border.all(
                        color: isSelected ? primaryColor : Colors.grey.shade300,
                        width: isSelected ? 2 : 1),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 5)
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          size: 30,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? Colors.grey.shade200
                                    : Colors.black87),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
