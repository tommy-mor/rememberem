package com.rememberem.rememberem

/** One watched place, as the app last gave it (see PlaceFence.toJson). */
data class SavedFence(
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val radius: Double,
)
