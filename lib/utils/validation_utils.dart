import 'package:flutter/services.dart';

class ValidationUtils {
  // Phone number validation - only numbers, exactly 10 digits for Indian numbers
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a phone number';
    }
    
    // Remove all non-digit characters
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length != 10) {
      return 'Phone number must be exactly 10 digits';
    }
    
    // Validate Indian mobile number format (starts with 6, 7, 8, or 9)
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    if (!phoneRegex.hasMatch(digitsOnly)) {
      return 'Please enter a valid 10-digit phone number';
    }
    
    return null;
  }

  // Password validation - minimum 6 characters
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }

  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an email address';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  // Name validation - letters and spaces only, minimum 2 characters
  static String? validateName(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    
    // Allow letters, spaces, and common name characters
    final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
    if (!nameRegex.hasMatch(value.trim())) {
      return '$fieldName can only contain letters and spaces';
    }
    
    return null;
  }

  // Required field validation
  static String? validateRequired(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Minimum length validation
  static String? validateMinLength(String? value, int minLength, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.trim().length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    
    return null;
  }

  // Maximum length validation
  static String? validateMaxLength(String? value, int maxLength, {String fieldName = 'This field'}) {
    if (value != null && value.trim().length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }
    return null;
  }

  // Text input formatter for phone numbers - only allows digits
  static TextInputFormatter getPhoneNumberFormatter() {
    return FilteringTextInputFormatter.digitsOnly;
  }

  // Text input formatter for names - only allows letters and spaces
  static TextInputFormatter getNameFormatter() {
    return FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'));
  }

  // Text input formatter for alphanumeric with spaces
  static TextInputFormatter getAlphanumericWithSpacesFormatter() {
    return FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s]'));
  }

  // Text input formatter for numbers only
  static TextInputFormatter getNumbersOnlyFormatter() {
    return FilteringTextInputFormatter.digitsOnly;
  }

  // Text input formatter for letters and spaces only
  static TextInputFormatter getLettersAndSpacesFormatter() {
    return FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'));
  }
}
