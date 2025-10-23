// Stub that is used to build for non-web environment. otherwise build breaks.

import 'package:flutter/material.dart';

class NaverMapWeb extends StatelessWidget {
  final String clientId;
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final List<Place>? places;

  const NaverMapWeb({
    super.key,
    required this.clientId,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.initialZoom,
    this.places,
  });

  @override
  Widget build(BuildContext context) {
    throw UnsupportedError('Web-only');
  }
}

class Place {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}