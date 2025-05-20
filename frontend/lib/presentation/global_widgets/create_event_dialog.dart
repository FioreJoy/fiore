import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// --- Core Imports ---
import '../../core/theme/theme_constants.dart';

// --- Global Widget Imports ---
import 'custom_text_field.dart';
import 'custom_button.dart';

class CreateEventDialog extends StatefulWidget {
  final String
      communityId; // This might need to become nullable or sourced differently
  final Function(
    String title,
    String description,
    String locationAddress,
    DateTime dateTime,
    int maxParticipants,
    File? imageFile,
    double? latitude,
    double? longitude,
  ) onSubmit;

  const CreateEventDialog({
    Key? key,
    required this.communityId,
    required this.onSubmit,
  }) : super(key: key);

  @override
  _CreateEventDialogState createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<CreateEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationAddressController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '50');
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  File? _pickedImageFile;

  @override
  void dispose() {
    /* ... controllers disposed ... */ _titleController.dispose();
    _descriptionController.dispose();
    _locationAddressController.dispose();
    _maxParticipantsController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    /* ... logic unchanged ... */ final DateTime? pickedDate =
        await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null && pickedDate != _selectedDate && mounted)
      setState(() => _selectedDate = pickedDate);
  }

  Future<void> _selectTime(BuildContext context) async {
    /* ... logic unchanged ... */ final TimeOfDay? pickedTime =
        await showTimePicker(context: context, initialTime: _selectedTime);
    if (pickedTime != null && pickedTime != _selectedTime && mounted)
      setState(() => _selectedTime = pickedTime);
  }

  Future<void> _pickEventImage() async {
    /* ... logic unchanged ... */ final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 75, maxWidth: 1200);
      if (pickedFile != null && mounted)
        setState(() => _pickedImageFile = File(pickedFile.path));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Error picking image.'),
            backgroundColor: Colors.red));
    }
  }

  void _removeImage() {
    if (mounted) setState(() => _pickedImageFile = null);
  }

  void _handleSubmit() {
    /* ... logic unchanged ... */
    if (_formKey.currentState?.validate() ?? false) {
      final DateTime eventDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute);
      final String latText = _latitudeController.text.trim();
      final String lonText = _longitudeController.text.trim();
      double? latitude;
      double? longitude;
      bool coordsValid = true;
      if (latText.isNotEmpty && lonText.isNotEmpty) {
        latitude = double.tryParse(latText);
        longitude = double.tryParse(lonText);
        if (latitude == null || longitude == null) coordsValid = false;
      } else if (latText.isNotEmpty || lonText.isNotEmpty) coordsValid = false;
      if (!coordsValid) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Valid Latitude & Longitude or leave both blank.'),
            backgroundColor: Colors.orangeAccent));
        return;
      }
      widget.onSubmit(
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _locationAddressController.text.trim(),
        eventDateTime,
        int.tryParse(_maxParticipantsController.text) ?? 50,
        _pickedImageFile,
        latitude,
        longitude,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    /* ... UI unchanged, path for CustomTextField, CustomButton checked via their global move ... */
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormatter = DateFormat('EEEE, MMM d, yyyy');
    final formattedDate = dateFormatter.format(_selectedDate);
    final formattedTime = _selectedTime.format(context);
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius)),
      elevation: 0,
      backgroundColor: isDark ? ThemeConstants.backgroundDark : Colors.white,
      child: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(ThemeConstants.cardBorderRadius)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                  padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                  decoration: BoxDecoration(
                    color: ThemeConstants.accentColor
                        .withOpacity(isDark ? 0.3 : 1.0),
                    borderRadius: const BorderRadius.only(
                        topLeft:
                            Radius.circular(ThemeConstants.cardBorderRadius),
                        topRight:
                            Radius.circular(ThemeConstants.cardBorderRadius)),
                  ),
                  child: Row(children: [
                    Icon(Icons.add_circle_outline_rounded,
                        color:
                            isDark ? Colors.white : ThemeConstants.primaryColor,
                        size: 22),
                    const SizedBox(width: 10),
                    Text('Create New Event',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : ThemeConstants.primaryColor))
                  ])),
              Padding(
                padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomTextField(
                          controller: _titleController,
                          labelText: 'Event Title*',
                          hintText: 'e.g. Study Group',
                          prefixIcon: const Icon(Icons.title_rounded),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null),
                      const SizedBox(height: 16),
                      CustomTextField(
                          controller: _locationAddressController,
                          labelText: 'Location Address*',
                          hintText: 'e.g. Library Room 2B',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: CustomTextField(
                                controller: _latitudeController,
                                labelText: 'Latitude (Opt)',
                                hintText: 'e.g. 40.71',
                                prefixIcon: const Icon(Icons.pin_drop_outlined,
                                    size: 20),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true),
                                validator: (v) {
                                  if (v != null &&
                                      v.trim().isNotEmpty &&
                                      double.tryParse(v.trim()) == null)
                                    return 'Invalid';
                                  return null;
                                })),
                        const SizedBox(width: 10),
                        Expanded(
                            child: CustomTextField(
                                controller: _longitudeController,
                                labelText: 'Longitude (Opt)',
                                hintText: 'e.g. -74.00',
                                prefixIcon: const Icon(Icons.pin_drop_outlined,
                                    size: 20),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true),
                                validator: (v) {
                                  if (v != null &&
                                      v.trim().isNotEmpty &&
                                      double.tryParse(v.trim()) == null)
                                    return 'Invalid';
                                  return null;
                                }))
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: InkWell(
                                onTap: () => _selectDate(context),
                                child: InputDecorator(
                                    decoration: const InputDecoration(
                                        labelText: 'Date*',
                                        prefixIcon: Icon(Icons.calendar_today)),
                                    child: Text(formattedDate)))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: InkWell(
                                onTap: () => _selectTime(context),
                                child: InputDecorator(
                                    decoration: const InputDecoration(
                                        labelText: 'Time*',
                                        prefixIcon: Icon(Icons.access_time)),
                                    child: Text(formattedTime))))
                      ]),
                      const SizedBox(height: 16),
                      CustomTextField(
                          controller: _maxParticipantsController,
                          labelText: 'Max Participants*',
                          hintText: 'e.g. 50',
                          prefixIcon: const Icon(Icons.people_outline),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Required';
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 1) return '>0';
                            return null;
                          }),
                      const SizedBox(height: 16),
                      CustomTextField(
                          controller: _descriptionController,
                          labelText: 'Description (Optional)',
                          hintText: 'Details, agenda, etc.',
                          prefixIcon: const Icon(Icons.description_outlined),
                          maxLines: 3,
                          minLines: 1),
                      const SizedBox(height: 20),
                      Text("Event Image (Optional)",
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54)),
                      const SizedBox(height: 8),
                      Container(
                        height: 130,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(
                                ThemeConstants.borderRadius),
                            color: isDark
                                ? Colors.grey.shade800.withOpacity(0.5)
                                : Colors.grey.shade100),
                        child: InkWell(
                          onTap: _pickEventImage,
                          borderRadius: BorderRadius.circular(
                              ThemeConstants.borderRadius),
                          child: _pickedImageFile == null
                              ? Center(
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                      Icon(Icons.add_a_photo_outlined,
                                          size: 36,
                                          color: Colors.grey.shade500),
                                      const SizedBox(height: 4),
                                      Text("Tap to add image",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500))
                                    ]))
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      ThemeConstants.borderRadius - 1),
                                  child: Image.file(_pickedImageFile!,
                                      fit: BoxFit.contain)),
                        ),
                      ),
                      if (_pickedImageFile != null)
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                                icon: const Icon(Icons.clear,
                                    size: 16, color: ThemeConstants.errorColor),
                                label: const Text("Remove",
                                    style: TextStyle(
                                        color: ThemeConstants.errorColor,
                                        fontSize: 11)),
                                onPressed: _removeImage)),
                      const SizedBox(height: 24),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel')),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            label: const Text('Create Event'),
                            onPressed: _handleSubmit,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeConstants.accentColor,
                                foregroundColor: ThemeConstants.primaryColor)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
