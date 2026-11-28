import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'auth_session.dart';
import 'listing_api.dart';
import 'listing_model.dart';
import 'styles.dart';

/// The "post a listing" form, also used to EDIT a listing (SCRUM-24).
/// Pass [listing] to edit it; leave it out to post a new one.
/// Pops with `true` when the listing was posted / saved.
class CreateListingScreen extends StatefulWidget {
  final ListingApi? api; // tests can pass a fake one
  final Listing? listing; // the listing being edited, or null for a new one
  const CreateListingScreen({super.key, this.api, this.listing});

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

  bool get _isEditing => widget.listing != null;

  @override
  void initState() {
    super.initState();
    final old = widget.listing;
    if (old != null) {
      // Edit mode: fill the form with what is saved now.
      _titleController.text = old.name;
      _descriptionController.text = old.description;
      _rateController.text = _rateText(old.hourlyRate);
      _conditionController.text = old.condition;
      _durationController.text = old.maxDuration.toString();
      _negotiable = old.negotiable;
      _campus = campuses.contains(old.campus) ? old.campus : null;
    }
  }

  /// 20.0 -> "20", 20.5 -> "20.50" (fits the 2-decimal rule on the field).
  static String _rateText(double rate) {
    return rate == rate.roundToDouble()
        ? rate.toInt().toString()
        : rate.toStringAsFixed(2);
  }

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
    // A new listing needs a photo. When editing, no new photo = keep the old one.
    final photoMissing = !_isEditing && _photoBytes == null;
    setState(() {
      _photoError = photoMissing ? 'Please add a photo' : null;
      _serverError = null;
    });
    if (!formOk || photoMissing) return; // stop, errors are on screen

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
      if (_isEditing) {
        await _api.updateListing(
          token: token,
          listingId: widget.listing!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          hourlyRate: _rateController.text,
          condition: _conditionController.text,
          maxDuration: _durationController.text,
          negotiable: _negotiable,
          campus: _campus!,
          photoBytes: _photoBytes, // null = keep the old photo
          photoName: _photoName,
        );
      } else {
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
      }
      if (!mounted) return;
      Navigator.pop(context, true); // tell the page that opened us it worked
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
        title: Text(_isEditing ? 'Edit Listing' : 'Post a Listing',
            style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    initialValue: _campus, // filled in when editing
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
                        : Text(_isEditing ? 'Save changes' : 'Post Listing'),
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
            child: _photoPreview(),
          ),
        ),
        if (_isEditing)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 12),
            child: Text('Tap the photo to change it',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
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

  /// What shows inside the photo box:
  /// the new photo if one was picked, else the current photo (edit mode),
  /// else the "Tap to add a photo" hint.
  Widget _photoPreview() {
    if (_photoBytes != null) {
      return Image.memory(_photoBytes!, fit: BoxFit.cover);
    }
    final oldUrl = widget.listing?.imageUrl ?? '';
    if (oldUrl.isNotEmpty) {
      return Image.network(
        oldUrl,
        key: const Key('current_photo'),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text('Tap to add a photo'),
        ],
      ),
    );
  }
}