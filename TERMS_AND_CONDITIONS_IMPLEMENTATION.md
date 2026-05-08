# Terms and Conditions Implementation - Complete Guide

## Overview
A comprehensive Terms and Conditions (T&C) acceptance step has been successfully integrated into the Rooks White Label app. Users must now read the T&C content and check a confirmation box before proceeding to the next step in their journey.

---

## Implementation Summary

### 📁 Files Created
1. **`lib/subscription/terms_and_conditions_screen.dart`**
   - New full-screen T&C widget
   - Handles user acceptance workflow
   - Integrates with Firestore for tracking acceptance

### 📝 Files Modified
1. **`lib/subscription/transaction_completed_screen.dart`**
   - Updated navigation flow to route through T&C screen
   - Passes all subscription data to T&C screen
   
2. **`lib/services/firestore_service.dart`**
   - Added 3 new methods for T&C tracking
   - Stores acceptance data in Firestore user documents

---

## Feature Details

### 🎨 TermsAndConditionsScreen Features

#### Content Sections (Editable)
The screen displays 10 detailed sections:
1. **Acceptance of Terms** - Agreement to terms
2. **Use License** - Proper usage guidelines
3. **Disclaimer** - Liability disclaimers
4. **Limitations** - Service limitations
5. **Accuracy of Materials** - Data accuracy
6. **Links** - Third-party link policy
7. **Modifications** - T&C modification rights
8. **Governing Law** - Legal jurisdiction
9. **Subscription Terms** - Subscription-specific terms
10. **User Responsibilities** - User obligations

**Note:** You can easily edit the content in the `_buildSection()` calls within the widget.

#### User Experience Features
- ✅ **Scroll-to-Unlock Pattern**: "Scroll to end" indicator that disappears once user reaches bottom
- ✅ **Mandatory Checkbox**: Users must check the confirmation box to proceed
- ✅ **Accept/Decline Options**: Clear action buttons with appropriate styling
- ✅ **Loading State**: Spinner during Firestore save
- ✅ **Error Handling**: User-friendly error messages
- ✅ **Confirmation Dialog**: Warns users before declining
- ✅ **Professional UI**: Consistent with existing app design

### 📊 Data Tracking

#### Firestore Storage
T&C acceptance data is stored in the `users` collection under each tenant:

```
{tenantId}
  └─ data (doc)
      └─ users (collection)
          └─ {userId} (doc)
              ├─ termsAndConditionsAccepted: boolean (true)
              ├─ termsAcceptedAt: "2024-01-15T10:30:00.000Z"
              └─ termsAcceptedTimestamp: <Firestore Timestamp>
```

#### New Firestore Methods

**1. Save T&C Acceptance**
```dart
Future<void> saveTermsAndConditionsAcceptance({
  required String uid,
  required String tenantId,
  required DateTime timestamp,
  String? appId,
})
```
Saves the user's T&C acceptance with timestamp.

**2. Check T&C Acceptance**
```dart
Future<bool> hasAcceptedTermsAndConditions({
  required String uid,
  required String tenantId,
  String? appId,
})
```
Returns `true` if user has accepted T&C.

**3. Get T&C Details**
```dart
Future<Map<String, dynamic>?> getTermsAndConditionsDetails({
  required String uid,
  required String tenantId,
  String? appId,
})
```
Retrieves full T&C acceptance details (acceptance status, dates).

---

## User Flow

### New User Registration Path
```
1. SignUp/Register
   ↓
2. Choose Subscription Plan
   ↓
3. Make Payment
   ↓
4. TransactionCompletedScreen (NEW!)
   ↓
5. TermsAndConditionsScreen (NEW!)  ← Mandatory acceptance
   ↓
   ├─ Accept → BrandingCustomizationScreen → Dashboard
   └─ Decline → Warning Dialog → Back to Payment
```

### Existing User Upgrade Path
```
1. AdminDashboard
   ↓
2. Upgrade Plan (if applicable)
   ↓
3. PaymentScreen
   ↓
4. TransactionCompletedScreen
   ↓
5. TermsAndConditionsScreen (NEW!)  ← Mandatory acceptance
   ↓
   ├─ Accept → Dashboard
   └─ Decline → Warning Dialog → Back to Payment
```

---

## Navigation Parameters

The T&C screen accepts and passes through the following parameters:

```dart
TermsAndConditionsScreen(
  isFirstTimeRegistration: bool,      // Determines next screen
  planName: String?,                  // Plan details
  isYearly: bool?,
  isSixMonths: bool?,
  price: int?,
  originalPrice: int?,
  paymentMethod: String?,
  transactionId: String?,
  limits: Map<String, dynamic>?,      // Plan limits
  geoLocation: bool?,
  attendance: bool?,
  barcode: bool?,
  reportExport: bool?,
  onAccept: VoidCallback?,            // Optional callbacks
  onDecline: VoidCallback?,
)
```

---

## Customization Guide

### 🎨 Styling

#### Colors
Modify colors in `lib/subscription/terms_and_conditions_screen.dart`:
- **Header Background**: `Colors.white`
- **Checkbox Active**: `Colors.green`
- **Accept Button**: `Colors.green.shade600`
- **Decline Button**: `Colors.red.shade600`
- **Scroll Indicator**: `Colors.orange`

#### Typography
- **Title**: 20px, FontWeight.w900
- **Section Headers**: 15px, FontWeight.w800
- **Body Text**: 13px, FontWeight.w400

### 📝 Content Updates

**To edit T&C content**, modify the `_buildSection()` calls:

```dart
_buildSection(
  'YOUR TITLE',
  'Your detailed content here...',
),
```

### 🔧 Advanced Customization

**Show scroll indicator only after certain threshold:**
```dart
// Modify _onScroll() method
if (_scrollController.position.pixels >= _desiredThreshold) {
  setState(() { _canAccept = true; });
}
```

**Make checkbox optional:**
```dart
// Change condition in _handleAccept()
if (!_agreedToTerms) {
  // Either show warning or allow anyway
}
```

**Auto-accept on first login:**
```dart
// Add flag to skip T&C screen for returning users
bool termsAlreadyAccepted = await FirestoreService.instance
  .hasAcceptedTermsAndConditions(uid, tenantId);
if (termsAlreadyAccepted) {
  // Skip directly to next screen
}
```

---

## Testing Checklist

- [ ] **Happy Path**: User scrolls → checks box → accepts → data saved ✓
- [ ] **Incomplete Flow**: User doesn't scroll → accept button disabled
- [ ] **Unchecked Box**: User can't accept without checking box
- [ ] **Decline**: Shows confirmation dialog → returns to payment
- [ ] **Data Persistence**: Firestore records acceptance correctly
- [ ] **First-time Users**: Routes to BrandingCustomizationScreen
- [ ] **Existing Users**: Routes to AdminDashboard
- [ ] **Error Handling**: Shows snackbar on Firestore errors
- [ ] **Loading State**: Shows spinner during save
- [ ] **Responsive UI**: Works on different screen sizes

---

## Future Enhancements

### Possible Additions
1. **Multi-language Support**: Translate T&C to multiple languages
2. **Version Control**: Track T&C version acceptance
3. **Audit Trail**: Log all T&C acceptances with IP address
4. **Email Notification**: Send confirmation email on acceptance
5. **PDF Export**: Let users download signed T&C
6. **Digital Signature**: Integration with e-signature services
7. **Conditional T&Cs**: Different T&C based on subscription plan
8. **Auto-renewal Notification**: Warn about subscription renewal in T&C
9. **Data Retention Policy**: Include GDPR/privacy policy
10. **Third-party Agreement**: Integrate payment processor terms

---

## Troubleshooting

### Issue: T&C Not Saving to Firestore
**Solution**: Check that user UID and tenantId are correctly retrieved
```dart
// Debug logging
debugPrint('UID: ${AuthStateService.instance.currentUser?.uid}');
debugPrint('TenantId: ${ThemeService.instance.databaseName}');
```

### Issue: Scroll Detection Not Working
**Solution**: Ensure SingleChildScrollView has sufficient content
```dart
// Add more content or reduce screen padding if needed
const SizedBox(height: 32), // Add spacers
```

### Issue: Checkbox Not Responding
**Solution**: Verify setState is being called and widget is StatefulWidget ✓ (Already implemented)

### Issue: Navigation Failing
**Solution**: Ensure all required parameters are passed through T&C constructor
```dart
TermsAndConditionsScreen(
  isFirstTimeRegistration: true,  // Must pass this!
  // ... other params
)
```

---

## File Locations
- **T&C Screen**: `lib/subscription/terms_and_conditions_screen.dart`
- **Updated Payment Screen**: `lib/subscription/transaction_completed_screen.dart`
- **Firestore Methods**: `lib/services/firestore_service.dart`

---

## Integration Notes
- ✅ Uses existing auth services (AuthStateService)
- ✅ Uses existing theme services (ThemeService)
- ✅ Integrates with existing Firestore structure
- ✅ Follows app's navigation patterns
- ✅ Maintains consistent styling

---

## Support & Questions
For questions about implementation or customization, refer to the inline comments in the source files or check the Firestore integration documentation.

**Last Updated**: April 20, 2026
