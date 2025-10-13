import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class CollegeAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const CollegeAutocomplete({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.onChanged,
  });

  @override
  State<CollegeAutocomplete> createState() => _CollegeAutocompleteState();
}

class _CollegeAutocompleteState extends State<CollegeAutocomplete> {
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  final FocusNode _focusNode = FocusNode();

  // Mock college data - you can replace this with a real API call
  final List<String> _allColleges = [
    'Delhi University',
    'Jawaharlal Nehru University',
    'Banaras Hindu University',
    'Aligarh Muslim University',
    'Jamia Millia Islamia',
    'University of Mumbai',
    'University of Calcutta',
    'University of Madras',
    'Osmania University',
    'Punjab University',
    'Gujarat University',
    'Karnataka University',
    'Andhra University',
    'Kerala University',
    'Rajasthan University',
    'Madhya Pradesh University',
    'Bihar University',
    'Assam University',
    'Manipur University',
    'Tripura University',
    'Mizoram University',
    'Nagaland University',
    'Arunachal Pradesh University',
    'Sikkim University',
    'Goa University',
    'Pondicherry University',
    'Jammu and Kashmir University',
    'Himachal Pradesh University',
    'Uttarakhand University',
    'Chhattisgarh University',
    'Jharkhand University',
    'Uttar Pradesh University',
    'Haryana University',
    'Punjab Technical University',
    'Guru Nanak Dev University',
    'Panjab University',
    'Kurukshetra University',
    'Maharshi Dayanand University',
    'Chaudhary Charan Singh University',
    'Dr. Bhimrao Ambedkar University',
    'Bundelkhand University',
    'Veer Bahadur Singh Purvanchal University',
    'Mahatma Gandhi Kashi Vidyapith',
    'Sampurnanand Sanskrit University',
    'Dr. Ram Manohar Lohia Avadh University',
    'Dr. Shakuntala Misra National Rehabilitation University',
    'Baba Saheb Bhimrao Ambedkar University',
    'Gautam Buddha University',
    'Shiv Nadar University',
    'Amity University',
    'Manipal University',
    'BITS Pilani',
    'VIT University',
    'SRM University',
    'LPU University',
    'Chandigarh University',
    'Thapar University',
    'PEC University',
    'NIT Kurukshetra',
    'NIT Jalandhar',
    'NIT Hamirpur',
    'NIT Srinagar',
    'NIT Calicut',
    'NIT Warangal',
    'NIT Trichy',
    'NIT Surathkal',
    'NIT Rourkela',
    'NIT Durgapur',
    'NIT Silchar',
    'NIT Agartala',
    'NIT Patna',
    'NIT Raipur',
    'NIT Jamshedpur',
    'NIT Meghalaya',
    'NIT Manipur',
    'NIT Mizoram',
    'NIT Nagaland',
    'NIT Arunachal Pradesh',
    'NIT Sikkim',
    'NIT Goa',
    'NIT Puducherry',
    'NIT Delhi',
    'NIT Uttarakhand',
    'NIT Himachal Pradesh',
    'NIT Punjab',
    'NIT Haryana',
    'NIT Rajasthan',
    'NIT Gujarat',
    'NIT Maharashtra',
    'NIT Madhya Pradesh',
    'NIT Chhattisgarh',
    'NIT Jharkhand',
    'NIT Bihar',
    'NIT Uttar Pradesh',
    'NIT West Bengal',
    'NIT Odisha',
    'NIT Andhra Pradesh',
    'NIT Telangana',
    'NIT Karnataka',
    'NIT Tamil Nadu',
    'NIT Kerala',
    'NIT Assam',
    'NIT Tripura',
    'NIT Manipur',
    'NIT Mizoram',
    'NIT Nagaland',
    'NIT Arunachal Pradesh',
    'NIT Sikkim',
    'NIT Goa',
    'NIT Puducherry',
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  void _onTextChanged() {
    if (widget.controller.text.length > 2) {
      _getCollegeSuggestions(widget.controller.text);
    } else {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  void _getCollegeSuggestions(String query) {
    if (query.length < 3) return;

    final lowercaseQuery = query.toLowerCase();
    final filteredColleges = _allColleges
        .where((college) => college.toLowerCase().contains(lowercaseQuery))
        .take(8)
        .toList();

    setState(() {
      _suggestions = filteredColleges;
      _showSuggestions = filteredColleges.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText ?? 'College Name',
            hintText: widget.hintText ?? 'Enter college name',
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon)
                : null,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              borderSide: const BorderSide(color: AppColors.textSecondary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              borderSide: const BorderSide(color: AppColors.textSecondary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.paddingM,
              vertical: AppSizes.paddingM,
            ),
          ),
          validator: widget.validator,
          onChanged: widget.onChanged,
          onTap: () {
            if (widget.controller.text.length > 2) {
              setState(() {
                _showSuggestions = _suggestions.isNotEmpty;
              });
            }
          },
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final college = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.school, size: 20),
                  title: Text(college, style: const TextStyle(fontSize: 14)),
                  onTap: () {
                    widget.controller.text = college;
                    setState(() {
                      _showSuggestions = false;
                    });
                    if (widget.onChanged != null) {
                      widget.onChanged!(college);
                    }
                    _focusNode.unfocus();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
