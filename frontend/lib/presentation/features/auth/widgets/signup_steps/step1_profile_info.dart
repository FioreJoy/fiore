import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../../core/theme/theme_constants.dart';
import '../../../../global_widgets/custom_text_field.dart';
import '../../../../../app_constants.dart'; // For AppConstants.defaultAvatar if _profileImageData is null

class SignUpStep1ProfileInfo extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController locationController;
  final String? selectedGender;
  final Function(String?) onGenderChanged;
  final VoidCallback pickImage;
  final Uint8List? profileImageData; // For displaying the picked image

  const SignUpStep1ProfileInfo({
    Key? key,
    required this.nameController,
    required this.usernameController,
    required this.emailController,
    required this.locationController,
    required this.selectedGender,
    required this.onGenderChanged,
    required this.pickImage,
    this.profileImageData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    ImageProvider? displayImageProvider;
    if (profileImageData != null) {
      displayImageProvider = MemoryImage(profileImageData!);
    }
    // Default/placeholder can be handled by CircleAvatar's child if backgroundImage is null

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: pickImage,
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor:
                      isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  backgroundImage: displayImageProvider,
                  child: profileImageData == null
                      ? Icon(Icons.person_add_alt_1,
                          size: 50, color: Colors.grey.shade500)
                      : null,
                ),
              ),
              Material(
                color: primaryColor,
                shape: const CircleBorder(),
                elevation: 2.0,
                child: InkWell(
                  onTap: pickImage,
                  customBorder: const CircleBorder(),
                  splashColor: Colors.white.withOpacity(0.3),
                  child: const Padding(
                    padding: EdgeInsets.all(9.0),
                    child:
                        Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 24),
        CustomTextField(
          controller: nameController,
          labelText: 'Full Name',
          prefixIcon: const Icon(Icons.person_outline),
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: usernameController,
          labelText: 'Username',
          prefixIcon: const Icon(Icons.alternate_email),
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: emailController,
          labelText: 'Email Address',
          prefixIcon: const Icon(Icons.email_outlined),
          keyboardType: TextInputType.emailAddress,
          validator: (v) =>
              (v!.isEmpty || !v.contains('@')) ? 'Valid email required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: locationController,
          labelText: 'Location (Optional)',
          hintText: '(longitude,latitude)',
          prefixIcon: const Icon(Icons.location_on_outlined),
          validator: (v) {
            if (v != null &&
                v.isNotEmpty &&
                !RegExp(r'^\s*\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)\s*$')
                    .hasMatch(v)) {
              return 'Use (lon,lat) format or leave blank';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: selectedGender,
          hint: const Text('Select Gender *'),
          decoration: InputDecoration(
            labelText: 'Gender *',
            prefixIcon: const Icon(Icons.wc_outlined),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          ),
          items: ['Male', 'Female', 'Others']
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: onGenderChanged,
          validator: (v) => v == null ? 'Gender required' : null,
        ),
      ],
    );
  }
}
