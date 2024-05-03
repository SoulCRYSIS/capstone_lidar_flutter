import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  static const platform = MethodChannel('lidar_channel');
  final dataPathsBox = Hive.box<String>("dataPaths");
  Uint8List? imageData;
  Image? image;
  List<List<double>>? depthData;
  bool captureVideo = false;

  Future<void> getCaptureDepthData() async {
    await platform.invokeMethod('captureLidar');
    // final result = (await platform.invokeMethod<List<Object?>>('captureLidar'))
    //     ?.map((e) => (e as List).map((e) => e as double).toList())
    //     .toList();
    // if (result == null) {
    //   throw Exception('Can\'t rethreive depth data');
    // }
    // return result;
  }

  String toCSV(List<List<double>> data) {
    return data.map((e) => e.join(",")).join("\n");
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onFrameUpdate') {
      try {
        late final Map<Object?, Object?> args;
        args = call.arguments as Map;
        depthData = (args['depthData'] as List)
            .map((e) => (e as List).map((e) => e as double).toList())
            .toList();
        imageData = args['imageData'] as Uint8List;
        if (captureVideo) {
          capture();
        }
        image = Image.memory(
          imageData!,
          gaplessPlayback: true,
        );
      } catch (e) {
        print(e);
      }
      setState(() {});
    }
  }

  Future<void> capture() async {
    final directory = await getApplicationDocumentsDirectory();
    final timeString = DateTime.now().toIso8601String();
    final depthDir = Directory("${directory.path}/depthData");
    if (!await depthDir.exists()) {
      await depthDir.create();
    }
    final file = File("${directory.path}/depthData/$timeString.csv");
    await file.writeAsString(toCSV(depthData!));
    final imageDir = Directory("${directory.path}/image");
    if (!await imageDir.exists()) {
      await imageDir.create();
    }
    final imageFile = File("${directory.path}/image/$timeString.jpg");
    await imageFile.writeAsBytes(imageData!);
    await dataPathsBox.put(imageFile.path, file.path);
  }

  Future<void> listFiles() async {
    // Documents Directory
    // final documentsDir = await getApplicationDocumentsDirectory();
    // final imagesDir = Directory('${documentsDir.path}/camera/pictures');
    // final depthsDir = Directory('${documentsDir.path}/depthData');
    // final imagesFile = await imagesDir.list().toList();
    // print('Images:');
    // for (var file in imagesFile) {
    //   print(file.path);
    // }
    // final depthsFile = await depthsDir.list().toList();
    // print('Depth:');
    // for (var file in depthsFile) {
    //   print(file.path);
    // }
    for (var i in dataPathsBox.keys) {
      print(i);
      print(dataPathsBox.get(i));
    }
  }

  Future<void> share(String image, String depthData, Rect position) async {
    try {
      await Share.shareXFiles(
        [XFile(image), XFile(depthData)],
        sharePositionOrigin: position,
      );
      // ignore: empty_catches
    } catch (e) {}
  }

  Future<void> shareAll() async {
    try {
      await Share.shareXFiles(
        [
          for (var image in dataPathsBox.keys) XFile(image),
          for (var depthData in dataPathsBox.values) XFile(depthData)
        ],
        sharePositionOrigin: const Rect.fromLTWH(100, 100, 100, 100),
      );
      // ignore: empty_catches
    } catch (e) {}
  }

  @override
  void initState() {
    // availableCameras().then((value) async {
    //   final controller = CameraController(value.first, ResolutionPreset.medium);
    //   await controller.initialize();
    //   await controller.setFlashMode(FlashMode.off);
    //   setState(() {
    //     cameraController = controller;
    //   });
    // });
    platform.setMethodCallHandler(_handleMethodCall);
    Future.delayed(const Duration(seconds: 1)).then((value) {
      Timer.periodic(const Duration(milliseconds: 200), (timer) {
        getCaptureDepthData();
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      drawer: Drawer(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: shareAll,
              child: const Text("Export All"),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: ValueListenableBuilder(
                  valueListenable: dataPathsBox.listenable(),
                  builder: (context, value, _) => Column(
                    children: value.keys.map((e) {
                      return TextButton(
                          onPressed: () => share(e, value.get(e)!,
                              const Rect.fromLTWH(100, 100, 100, 100)),
                          child: Text(value.get(e)!.split("/").last));
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: image == null
            ? const CircularProgressIndicator()
            : Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  image!,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: capture,
                        child: const Text("capture"),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() {
                          captureVideo = !captureVideo;
                        }),
                        child: Text(captureVideo ? "stop" : "burst"),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
