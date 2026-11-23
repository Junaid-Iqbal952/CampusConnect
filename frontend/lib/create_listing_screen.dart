import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'auth_session.dart';
import 'listing_api.dart';
import 'styles.dart';

/// The "post a listing" form. Pops with `true` when the listing was posted.
class CreateListingScreen extends StatefulWidget {
  final ListingApi? api; // tests can pass a fake one
  const CreateListingScreen({super.key, this.api});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  // Keep these the same as ALLOWED_CAMPUSES in backend/listings.py
  static const campuses = ['Main', 'City'];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rateController = TextEditingController();
  final _conditionController = TextEditingController();
  final _durationController = TextEditingController();

  late final ListingApi _api = widget.api ?? ListingApi();

  Uint8List? _photoBytes;
  String _photoName = 'photo.jpg';
  String? _campus;
  bool _negotiable = false;
  bool _isSubmitting = false;
  String? _photoError;
  String? _serverError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rateController.dispose();
    _conditionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600, // shrink big photos so the upload is fast
      imageQuality: 85,
    );
    if (picked == null) return; // user closed the picker
    final bytes = await picked.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (!mounted) return;
      setState(() => _photoError = 'Photo must be 2 MB or smaller');
      return;
    }
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoName = picked.name;
      _photoError = null;
    });
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    setState(() {
      _photoError = _photoBytes == null ? 'Please add a photo' : null;
      _serverError = null;
    });
    if (!formOk || _photoBytes == null) return; // stop, errors are on screen

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      if (!mounted) return;
      await clearSessionAndGoToWelcome(context,
          message: 'Session expired. Please log in again');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _api.createListing(
        token: token,
        title: _titleController.text,
        description: _descriptionController.text,
        hourlyRate: _rateController.text,
        condition: _conditionController.text,
        maxDuration: _durationController.text,
        negotiable: _negotiable,
        campus: _campus!,
        photoBytes: _photoBytes!,
        photoName: _photoName,
      );
      if (!mounted) return;
      Navigator.pop(context, true); // tell the listings page it worked
    } on SessionExpiredException catch (e) {
      // must come BEFORE AuthException (it is a child of it)
      if (!mounted) return;
      await clearSessionAndGoToWelcome(context, message: e.message);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverError = e.message;
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Post a Listing',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppStyles.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _photoPicker(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    maxLength: 100,
                    decoration: const InputDecoration(
                        labelText: 'Item name', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                        labelText: 'Description', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter a description'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      // digits, then an optional dot, then up to 2 decimals
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Hourly rate (Rs)', border: OutlineInputBorder()),
                    validator: (v) {
                      final rate = double.tryParse((v ?? '').trim());
                      return (rate == null || rate <= 0)
                          ? 'Enter an hourly rate above 0'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _conditionController,
                    maxLength: 50,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      hintText: 'e.g. Good, Like new',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please describe the condition'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        labelText: 'Max rental duration (days)',
                        border: OutlineInputBorder()),
                    validator: (v) {
                      final days = int.tryParse((v ?? '').trim());
                      return (days == null || days < 1)
                          ? 'Enter a duration of at least 1 day'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: 'Campus', border: OutlineInputBorder()),
                    items: campuses
                        .map((c) => DropdownMenuItem(value: c, child: Text('$c Campus')))
                        .toList(),
                    onChanged: (value) => setState(() => _campus = value),
                    validator: (v) => v == null ? 'Please choose a campus' : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Price negotiable'),
                    value: _negotiable,
                    activeThumbColor: AppStyles.primaryColor,
                    onChanged: (value) => setState(() => _negotiable = value),
                  ),
                  const SizedBox(height: 8),
                  AuthErrorText(_serverError), // red message from the server
                  ElevatedButton(
                    key: const Key('post_button'),
                    style: AppStyles.primaryButtonStyle,
                    onPressed: _isSubmitting ? null : _submit, // null = disabled
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Post Listing'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The big box: tap it to pick a photo, shows a preview after.
  Widget _photoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('photo_picker'),
          onTap: _pickPhoto,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                  color: _photoError == null ? Colors.grey : Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: _photoBytes == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Tap to add a photo'),
                      ],
                    ),
                  )
                : Image.memory(_photoBytes!, fit: BoxFit.cover),
          ),
        ),
        if (_photoError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(_photoError!,
                key: const Key('photo_error'),
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }
}