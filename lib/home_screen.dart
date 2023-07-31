import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BluetoothDiscoveryResult> devices = [];
  final StreamController<List<BluetoothDiscoveryResult>> _devicesStreamController =
      StreamController<List<BluetoothDiscoveryResult>>.broadcast();
  FlutterBluetoothSerial flutterBluetoothSerial = FlutterBluetoothSerial.instance;
  BluetoothConnection? _bluetoothConnection;
  bool isBluetoothOn = false;

  //
  Stream<BluetoothDiscoveryResult> scannedDevices() {
    return flutterBluetoothSerial.startDiscovery();
  }

  // Start scanning for devices
  void startScan() {
    devices = [];
    _devicesStreamController.add(devices);
    // final state =  flutterBluetoothSerial.state.asStream();

    // state.listen((event) {
    //   setState(() {
    //     if (event == BluetoothState.STATE_ON) {
    //       isBluetoothOn = true;
    //       print("bluetooth is on");
    //     } else {
    //       isBluetoothOn = false;
    //       print("bluetooth is off");
    //     }
    //   });
    // });

    scannedDevices().listen((BluetoothDiscoveryResult result) {
      setState(() {
        if (!devices.contains(result)) {
          devices.add(result);
          _devicesStreamController.add(devices);
        } else {
          devices.remove(result);
          _devicesStreamController.add(devices);
        }
      });
    });
  }

  Stream<BluetoothState> stateStream() {
    return flutterBluetoothSerial.state.asStream();
  }

  initalization() async {
    final permissions = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ].request();

    _devicesStreamController.add(devices);
    stateStream().listen((event) {
      if (event == BluetoothState.STATE_ON) {
        setState(() {
          isBluetoothOn = true;
        });
        scannedDevices();
        startScan();
      }
    });

    flutterBluetoothSerial.onStateChanged().listen((event) {
      print("$event listening");
      if (event == BluetoothState.STATE_ON) {
        setState(() {
          isBluetoothOn = true;
          scannedDevices();
          startScan();
        });
      } else {
        setState(() {
          isBluetoothOn = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();

    initalization();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("devices"),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () async {
              await flutterBluetoothSerial.cancelDiscovery();
              startScan();
            },
            child: const Text("Scan"),
          ),
          const SizedBox(
            height: 10,
          ),
          FloatingActionButton(
            onPressed: () async {
              // devices = [];

              await flutterBluetoothSerial.cancelDiscovery();

              // await flutterBlue.stopScan();
            },
            child: const Text("Stop"),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isBluetoothOn)
            StreamBuilder<List<BluetoothDiscoveryResult>>(
              stream: _devicesStreamController.stream,
              initialData: devices,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Expanded(
                    child: Center(
                      child: Text("No Devices Found"),
                    ),
                  );
                } else if (snapshot.hasData) {
                  if (devices.isNotEmpty ?? false) {
                    print("$devices");

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: devices.length ?? 0,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: (_bluetoothConnection?.isConnected ?? false)
                              ? const CircleAvatar(
                                  backgroundColor: Colors.green,
                                )
                              : const SizedBox.shrink(),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("${devices[index].device.name}"),
                                    ],
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () {
                                        connectToDevice(devices[index].device);
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text("Connect"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        disconnectDevice(devices[index].device);
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text("Disconnect"),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          title: Text(
                            devices![index].device.name.toString(),
                            style: const TextStyle(color: Colors.black),
                          ),
                          trailing: Text(devices[index].device.type.stringValue),
                          subtitle: Text(devices[index].device.address),
                        );
                      },
                    );
                  } else {
                    return const Expanded(
                      child: Center(
                        child: Text("No Devices Found"),
                      ),
                    );
                  }
                } else {
                  return const CircularProgressIndicator();
                }
              },
            )
          else
            const Expanded(
                child: Center(
              child: Text("Please Turn on bluetooth"),
            )),
        ],
      ),
    );
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await flutterBluetoothSerial.removeDeviceBondWithAddress(device.address);
    } catch (e) {
      log("disconnect exception: $e");
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      print("${device.bondState.stringValue} ${device.isBonded}");

      if (!device.isBonded) {
        final bond = await flutterBluetoothSerial.bondDeviceAtAddress(
          device.address,
        );
        print("${bond} *** bond ");

        _bluetoothConnection = await BluetoothConnection.toAddress(device.address);
        print("${_bluetoothConnection?.isConnected} *** connection in if ");
      } else {
        print(" bonde : ${device.isBonded} ** connected : ${device.isConnected} ** address :  ${device.address}");

        _bluetoothConnection = await BluetoothConnection.toAddress(device.address);
        print("${_bluetoothConnection?.isConnected} *** connection ");
      }

      setState(() {});
    } catch (e) {
      print('Error connecting to the device: $e');
    }
  }
}
