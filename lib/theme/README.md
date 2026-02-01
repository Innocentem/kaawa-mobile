# Kaawa Mobile Design System

This directory contains the design system for the Kaawa Mobile application, providing a cohesive coffee-industry aesthetic throughout the app.

## Overview

The design system is built around three main components:

1. **Color Palette** (`app_colors.dart`) - Coffee-inspired colors
2. **Typography** (`app_typography.dart`) - Modern, readable fonts
3. **Theme Configuration** (`app_theme.dart`) - Complete Material Design 3 theme

## Color Palette

### Primary Colors (Coffee Browns)
- **Primary Brown** `#6F4E37` - Main brand color, used for primary actions and app bars
- **Dark Brown** `#3E2723` - Dark roast, used for emphasis
- **Light Brown** `#8D6E63` - Light roast, used for subtle highlights
- **Medium Brown** `#5D4037` - Medium roast, used in gradients

### Accent Colors (Coffee Plant Greens)
- **Primary Green** `#4CAF50` - Fresh coffee leaf, used for success states and secondary actions
- **Dark Green** `#388E3C` - Deep leaf, used for hover states
- **Light Green** `#81C784` - Young leaf, used for light backgrounds

### Neutral Tones (Cream & Beige)
- **Cream** `#F5F5DC` - Coffee with cream, used for backgrounds
- **Light Cream** `#FFFAF0` - Foam, used for card backgrounds
- **Warm White** `#FAF9F6` - Warm background alternative
- **Beige** `#D7CCC8` - Latte, used for dividers and borders

### Functional Colors
- **Text Dark** `#212121` - Primary text
- **Text Medium** `#757575` - Secondary text
- **Text Light** `#9E9E9E` - Hint text
- **Error** `#D32F2F` - Error states
- **Success** `#388E3C` - Success states
- **Warning** `#F57C00` - Warning states

## Typography

The design system uses two Google Fonts:

### Poppins (Primary Font)
Used for headings, titles, and buttons. Characteristics:
- Modern, geometric sans-serif
- High readability
- Strong visual presence
- Weights: Regular (400), SemiBold (600), Bold (700)

### Lato (Secondary Font)
Used for body text and labels. Characteristics:
- Clean, humanist sans-serif
- Excellent readability at small sizes
- Friendly and approachable
- Weights: Regular (400), Medium (500)

### Text Styles

#### Display Styles (Page Titles)
- `displayLarge` - 32px, Bold
- `displayMedium` - 28px, Bold
- `displaySmall` - 24px, SemiBold

#### Headline Styles (Section Headers)
- `headlineLarge` - 22px, SemiBold
- `headlineMedium` - 20px, SemiBold
- `headlineSmall` - 18px, SemiBold

#### Title Styles (Card Titles, List Items)
- `titleLarge` - 16px, SemiBold
- `titleMedium` - 14px, SemiBold
- `titleSmall` - 12px, SemiBold

#### Body Styles (Content Text)
- `bodyLarge` - 16px, Regular
- `bodyMedium` - 14px, Regular
- `bodySmall` - 12px, Regular

#### Label Styles (Form Labels, Tags)
- `labelLarge` - 14px, Medium
- `labelMedium` - 12px, Medium
- `labelSmall` - 11px, Medium

#### Button Style
- 14px, SemiBold, 1.25px letter spacing

## Theme Configuration

### Components

#### App Bar
- Background: Primary Brown
- Foreground: White
- Elevation: 0
- Center aligned titles

#### Buttons

**Elevated Button**
- Background: Primary Brown
- Foreground: White
- Border radius: 12px
- Padding: 24px horizontal, 12px vertical

**Outlined Button**
- Border: Primary Brown, 2px
- Foreground: Primary Brown
- Border radius: 12px

**Text Button**
- Foreground: Primary Brown

#### Text Fields
- Filled: White background
- Border radius: 12px
- Border: Beige (normal), Primary Brown (focused)
- Padding: 16px

#### Cards
- Background: White
- Border radius: 16px
- Elevation: 2
- Margin: 8px vertical, 16px horizontal

#### Floating Action Button
- Background: Primary Green
- Foreground: White
- Border radius: 16px
- Elevation: 4

### Animations

The theme includes two types of page transitions:

1. **Slide & Fade Transition** - For main navigation
   - Slides from right with fade effect
   - Duration: 300ms
   - Easing: Cubic ease-in-out

2. **Fade Transition** - For modals and overlays
   - Simple fade effect
   - Duration: 200ms

## Usage

### Importing

```dart
import 'package:kaawa_mobile/theme/app_colors.dart';
import 'package:kaawa_mobile/theme/app_typography.dart';
import 'package:kaawa_mobile/theme/app_theme.dart';
```

### Applying Theme

In `main.dart`:

```dart
MaterialApp(
  theme: AppTheme.lightTheme,
  // ...
)
```

### Using Colors

```dart
Container(
  color: AppColors.primaryBrown,
  // or
  decoration: BoxDecoration(
    gradient: AppColors.coffeeGradient,
  ),
)
```

### Using Typography

```dart
Text(
  'Hello World',
  style: AppTypography.headlineMedium,
)

// Or with color override
Text(
  'Hello World',
  style: AppTypography.bodyLarge.copyWith(color: AppColors.primaryGreen),
)
```

### Using Transitions

```dart
Navigator.push(
  context,
  AppTheme.createRoute(NextScreen()),
);

// For modals
Navigator.push(
  context,
  AppTheme.createFadeRoute(ModalScreen()),
);
```

## Design Principles

1. **Consistency** - Use the defined colors and typography throughout the app
2. **Hierarchy** - Use different text styles to establish clear information hierarchy
3. **Spacing** - Use consistent padding (16px, 24px) and spacing
4. **Readability** - Ensure sufficient contrast and appropriate font sizes
5. **Coffee Theme** - Incorporate coffee-related colors, icons, and imagery
6. **Modern** - Use rounded corners (12px-16px), subtle shadows, and Material Design 3 principles

## Icon Usage

Throughout the app, use coffee-related icons where appropriate:

- `Icons.coffee` - For coffee type, listings
- `Icons.agriculture` - For farmers
- `Icons.shopping_bag` - For buyers
- `Icons.inventory` - For stock management
- `Icons.local_cafe` - For coffee-related features

## Future Enhancements

Potential improvements to the design system:

1. Dark theme variant
2. Custom coffee bean illustrations
3. Coffee origin badges
4. Animated loading indicators with coffee theme
5. Custom splash screen with coffee imagery
