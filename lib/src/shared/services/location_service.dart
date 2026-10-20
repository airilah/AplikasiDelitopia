import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/branch_model.dart';

class LocationService {
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check and request location permissions
  Future<LocationPermission> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Get current user position
  Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permissions
      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Calculate distance between two coordinates in kilometers
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    ) / 1000; // Convert meters to kilometers
  }

  /// Get branches sorted by distance from user's location
  Future<List<BranchWithDistance>> getBranchesByDistance(
    List<Branch> branches,
    Position userPosition,
  ) async {
    final branchesWithDistance = <BranchWithDistance>[];

    for (var branch in branches) {
      if (!branch.hasValidCoordinates) {
        branchesWithDistance.add(BranchWithDistance(
          branch: branch,
          distance: double.infinity,
        ));
        continue;
      }

      final distance = calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        branch.lat,
        branch.lng);

      branchesWithDistance.add(BranchWithDistance(
        branch: branch,
        distance: distance,
      ));
    }

    // Sort by distance (nearest first)
    branchesWithDistance.sort((a, b) => a.distance.compareTo(b.distance));

    return branchesWithDistance;
  }

  /// Get nearest branches within a specific radius (in km)
  Future<List<BranchWithDistance>> getNearbyBranches(
    List<Branch> branches,
    Position userPosition, {
    double radiusKm = 10.0,
  }) async {
    final branchesWithDistance = await getBranchesByDistance(
      branches,
      userPosition);

    // Filter by radius
    return branchesWithDistance
        .where((b) => b.distance <= radiusKm)
        .toList();
  }

  /// Format distance for display
  String formatDistance(double distanceKm) {
    if (distanceKm.isInfinite) {
      return 'Jarak belum tersedia';
    }

    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }
}

/// Model to hold branch with calculated distance
class BranchWithDistance {
  final Branch branch;
  final double distance; // in kilometers

  BranchWithDistance({
    required this.branch,
    required this.distance,
  });

  String get formattedDistance {
    if (distance.isInfinite) {
      return 'Jarak belum tersedia';
    }

    if (distance < 1) {
      return '${(distance * 1000).round()} m';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }
}
