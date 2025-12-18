class AppErrors {
  // Network errors
  static const String networkError =
      'Please check your internet connection and try again';
  static const String serverError = 'Server error. Please try again later';
  static const String timeoutError = 'Request timed out. Please try again';

  // Database errors
  static const String databaseError = 'Failed to save data. Please try again';
  static const String loadDataError = 'Failed to load data. Please try again';
  static const String deleteError = 'Failed to delete. Please try again';
  static const String updateError = 'Failed to update. Please try again';

  // Validation errors
  static String validationError(String field) => 'Please enter a valid $field';
  static String requiredError(String field) => '$field is required';

  // Permission errors
  static const String cameraPermissionError = 'Camera permission is required';
  static const String storagePermissionError = 'Storage permission is required';
  static const String locationPermissionError =
      'Location permission is required';

  // Feature errors
  static const String ocrError = 'Failed to extract text from image';
  static const String exportError = 'Failed to export data';
  static const String importError = 'Failed to import data';
  static const String backupError = 'Failed to create backup';
  static const String restoreError = 'Failed to restore backup';

  // Generic errors
  static const String unknownError = 'An unexpected error occurred';
  static const String notFoundError = 'Item not found';
}

class AppMessages {
  // Success messages
  static const String saveSuccess = 'Saved successfully';
  static const String updateSuccess = 'Updated successfully';
  static const String deleteSuccess = 'Deleted successfully';
  static const String exportSuccess = 'Exported successfully';
  static const String importSuccess = 'Imported successfully';

  // Confirmation messages
  static const String deleteConfirm = 'Are you sure you want to delete?';
  static const String discardChanges = 'Discard changes?';

  // Info messages
  static const String noData = 'No data available';
  static const String loading = 'Loading...';
  static const String syncing = 'Syncing data...';
}
