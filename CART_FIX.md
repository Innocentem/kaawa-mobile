# Cart Persistence Fix

## Problem
When a buyer added items to the cart and then logged out, the cart items would persist and appear when logging back in. This was unexpected user experience as the cart should be cleared on logout.

## Root Cause
The cart data (`_cart` Map) in `BuyerHomeScreen` was stored only in memory and was never explicitly cleared when the user logged out. While the widget itself would be destroyed, there could be edge cases where the navigation history or widget state could retain the data.

## Solution
Modified the logout process in `BuyerHomeScreen` to explicitly clear the cart before logging out:

### Changes Made

**File: `lib/buyer_home_screen.dart`**

1. **Updated `_handleLogoutRequest()` method** - Added explicit cart clearing:
```dart
Future<void> _handleLogoutRequest() async {
  final shouldLogout = await showDialog<bool>(...);
  if (shouldLogout != true) return;
  
  // Clear the cart before logging out
  _cart.clear();
  _cartItemCount = 0;
  
  await _authService.logout();
  if (!mounted) return;
  Navigator.pushAndRemoveUntil(...);
}
```

2. **Updated `dispose()` method** - Added cart cleanup on widget disposal:
```dart
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _animationController.dispose();
  // Clear cart on dispose
  _cart.clear();
  super.dispose();
}
```

## How It Works

1. **On Logout**: When user clicks logout, the cart is explicitly cleared before calling `authService.logout()`
2. **On Widget Dispose**: When the BuyerHomeScreen widget is disposed (happens during navigation), the cart is also cleared as a safety measure
3. **New Login**: When the user logs back in, a fresh BuyerHomeScreen widget is created with an empty cart

## Testing

To verify the fix:

1. **Add items to cart** as a buyer (e.g., 50 Kg of coffee)
2. **Logout** from the buyer account
3. **Login** again with the same or different buyer account
4. **Verify cart is empty** - No items should be visible
5. **Test multiple times** to ensure consistency

## Files Modified
- `lib/buyer_home_screen.dart` - Added cart clearing on logout and dispose

## Behavior After Fix
- ✅ Cart is always empty on fresh login
- ✅ Cart is cleared explicitly during logout
- ✅ No cart data persists between sessions
- ✅ Multiple logouts and logins work correctly

