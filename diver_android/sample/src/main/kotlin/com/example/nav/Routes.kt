package com.example.nav

import com.diver.android.DiverRoute

// In a real app these would also be @Serializable and used as Navigation
// Compose destinations; the Diver processor only needs @DiverRoute.

@DiverRoute(name = "Home", description = "Landing screen")
data object Home

@DiverRoute(name = "Profile", description = "User profile")
data class Profile(val userId: String)

@DiverRoute(name = "Settings", description = "App settings")
data class Settings(val tab: String? = null, val verbose: Boolean = false)

// No metadata -> name falls back to the derived URL (host/path).
@DiverRoute
data class ProductDetails(val id: String, val ref: String? = null)

class Item

// A custom-typed parameter is not reachable by URL alone, so this route is
@DiverRoute(name = "Detail")
data class Detail(val item: Item)
