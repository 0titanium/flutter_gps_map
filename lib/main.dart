import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GpsMapApp(),
    );
  }
}

class GpsMapApp extends StatefulWidget {
  const GpsMapApp({super.key});

  @override
  State<GpsMapApp> createState() => GpsMapAppState();
}

class GpsMapAppState extends State<GpsMapApp> {
  // _controller = Completer<GoogleMapController>();로 하니깐 안됨
  final Completer<GoogleMapController> _controller = Completer();

  CameraPosition? _initialCameraPosition;

  int _polylineIdCounter = 0;
  Set<Polyline> _polylines = {};
  LatLng? _prevPosition;

  // CameraPosition : 어느 위치를 비출지에 대한 객체
  // LatLng : 위도 경도 객체
  // zoom : 얼마나 줌 할지
  // tilt : 회전?

  @override
  void initState() {
    super.initState();

    init();
  }

  Future<void> init() async {
    // 위치 값 얻기
    final position = await _determinePosition();

    _initialCameraPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 17,
    );

    setState(() {});

    // 위치 정보를 얼마나 정밀하게 할 건지 조절
    const locationSettings = LocationSettings();
    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      _polylineIdCounter++;
      final polylineId = PolylineId('$_polylineIdCounter');
      final Polyline polyline = Polyline(
        polylineId: polylineId,
        color: Colors.red,
        width: 3,
        // 전 위도 경도 값도 알고 새로 바뀐 값도 알아야 함
        points: [
          _prevPosition ?? _initialCameraPosition!.target,
          LatLng(position.latitude, position.longitude),
        ],
      );
      setState(() {
        _polylines.add(polyline);
        _prevPosition = LatLng(position.latitude, position.longitude);
      });

      _moveCamera(position);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _initialCameraPosition == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : GoogleMap(
              mapType: MapType.normal,
              // 맵을 켜면 서울역으로
              initialCameraPosition: _initialCameraPosition!,
              onMapCreated: (GoogleMapController controller) {
                // controller를 통해서 지도를 조작할 수 있다
                _controller.complete(controller);
              },
              polylines: _polylines,
            ),
    );
  }

  Future<void> _moveCamera(Position position) async {
    final GoogleMapController controller = await _controller.future;
    // final position = await Geolocator.getCurrentPosition();
    final cameraPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 17,
    );
    await controller
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  // 위치값 얻기
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    // 위치 기능을 꺼놨는지
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    // 사용자 동의
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }
}
