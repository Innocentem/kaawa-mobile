# Kaawa Mobile ☕

Kaawa is a professional, direct-to-consumer coffee marketplace application designed to bridge the gap between local coffee farmers and buyers. The platform focuses on technical stability, real-time synchronization, and a high-contrast UI for excellent visibility in various environments.

## 🚀 Project Overview

Kaawa provides a streamlined ecosystem for the coffee trade:
- **Farmers** can list their harvests, manage stock levels, and track buyer interest in real-time.
- **Buyers** can discover local farmers, browse high-quality coffee listings, and communicate directly to finalize purchases.
- **Admins** maintain the integrity of the marketplace through user management and platform oversight.

## 🌱 The Inspiration

Kaawa was born out of a personal mission. Growing up as the son of a coffee farmer, I witnessed firsthand the challenges of the traditional market. For too long, the coffee trade has suffered from a "monogamous" market structure—where farmers are often restricted to a very limited number of buyers within their immediate reach. 

This lack of choice and market transparency frequently leads to exploitation, as farmers are forced to accept unfavorable terms simply because they have no other viable options. Kaawa is designed to break this cycle by digitizing the connection, empowering farmers with a broader audience and giving buyers direct access to quality coffee straight from the source.

## ✨ Key Features

### 🚜 For Farmers
- **Inventory Management**: Effortlessly add, edit, and track coffee stock levels.
- **Mark as Sold**: A robust lifecycle for managing quantity remaining and marking listings as sold.
- **Real-time Interest**: Instant notification badges when buyers show interest, powered by Supabase real-time streams.
- **Optimized Dashboard**: A high-contrast "Home" interface designed for clarity.

### 🛍️ For Buyers
- **Discovery**: Browse coffee listings with distance-based filtering and search capabilities.
- **Direct Communication**: Integrated chat system to coordinate with farmers.
- **Purchase History**: Keep track of previous requests and completed transactions.
- **Flexible UI**: Seamlessly switch between Light and Dark modes with adaptive branding.

### 🛡️ Administration
- **User Governance**: Suspend or activate accounts to ensure platform safety.
- **Security**: Manage password resets and secure authentication flows.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (3.0.0+)
- **Backend & Database**: [Supabase](https://supabase.com/) (PostgreSQL, Auth, Real-time)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Local Storage**: [sqflite](https://pub.dev/packages/sqflite) & [shared_preferences](https://pub.dev/packages/shared_preferences)
- **Geospatial**: [geolocator](https://pub.dev/packages/geolocator) for proximity-based search.

## 🎨 Design & Branding
Kaawa utilizes a high-contrast branding system:
- **Primary Color Scheme**: Deep coffee tones with high-contrast foregrounds for accessibility.
- **Adaptive Visuals**: 
    - Light Mode: `seeds_light.jpg` banner.
    - Dark Mode: `seeds.jpg` banner.
- **Consistent UI**: Standardized App Bars with 0.9 opacity and semantic headers.

## 👨‍💻 Developer
**Innocentem**
- 📧 **Email**: [mwbzinno@gmail.com](mailto:mwbzinno@gmail.com)
- 📞 **Mobile**: [+256 751 433 267](tel:+256751433267)
- 🐙 **GitHub**: [Innocentem](https://github.com/Innocentem)

---
*Built with passion for the coffee community.*
