import 'dart:async';
// import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission();
  final token = await fcm.getToken();

  if (kDebugMode) {
    print('Token device $token');
  }

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PushNotification(),
    ),
  );

  // // Create a FlutterIsolate
  // final ReceivePort receivePort = ReceivePort();
  // final isolate = await FlutterIsolate.spawn(
  //   _backgroundIsolate,
  //   receivePort.sendPort,
  // );

  // receivePort.listen((message) {
  //   if (message == null) {
  //     receivePort.close();
  //   }
  // });

  // // Send a message to the isolate
  // isolate.controlPort?.send(null);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
  await _showLocalNotification(message);
}

// void _backgroundIsolate(SendPort mainSendPort) {
//   final ReceivePort isolateReceivePort = ReceivePort();
//   mainSendPort.send(isolateReceivePort.sendPort);

//   isolateReceivePort.listen((message) {
//     if (message is SendPort) {
//       final SendPort send = message;
//       send.send('message from isolate');
//     } else {
//       if (kDebugMode) {
//         print(message);
//       }
//     }
//   });

//   FirebaseMessaging.onBackgroundMessage((RemoteMessage message) async {
//     // Handle background messages here
//     await Firebase.initializeApp(); // Initialize Firebase in the isolate
//     if (kDebugMode) {
//       print('Handling a background message: ${message.messageId}');
//     }
//     await _showLocalNotification(message);
//     return Future<void>.value();
//   });
// }

Future<void> _showLocalNotification(RemoteMessage message) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    '2',
    'flutterEmbedding',
    importance: Importance.max,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound('notification'),
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0, // Notification ID
    message.notification?.title ?? '', // Notification title
    message.notification?.body ?? '', // Notification body
    platformChannelSpecifics,
    payload: 'item x', // Optional payload
  );
}

class PushNotification extends StatefulWidget {
  const PushNotification({Key? key}) : super(key: key);

  @override
  State<PushNotification> createState() => _PushNotificationState();
}

class _PushNotificationState extends State<PushNotification> {
  RemoteMessage? lastReceivedMessage;

  @override
  void initState() {
    super.initState();
    setupInteractedMessage();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        // When the app is in the foreground, show a custom dialog
        _showCustomDialog(message);
      }
      setState(() {
        lastReceivedMessage = message;
      });
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        showDialog(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: Text(notification.title ?? ''),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.body ?? ''),
                  ],
                ),
              ),
            );
          },
        );
      }
    });
  }

  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print('Initial message: ${initialMessage.data}');
      }
    }
  }

  Future<void> _showCustomDialog(RemoteMessage message) async {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(message.notification?.title ?? ''),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.notification?.body ?? ''),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Close the dialog
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notifications'),
        backgroundColor: Colors.teal,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (lastReceivedMessage != null)
                Text(
                  'Last Message: ${lastReceivedMessage!.notification?.title ?? ""} ${lastReceivedMessage!.notification?.body ?? ""}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.teal,
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                ),
                onPressed: () {
                  final flutterLocalNotificationsPlugin =
                      FlutterLocalNotificationsPlugin();
                  flutterLocalNotificationsPlugin.show(
                    0,
                    lastReceivedMessage!.notification?.title ?? '',
                    lastReceivedMessage!.notification?.body ?? '',
                    const NotificationDetails(
                      android: AndroidNotificationDetails(
                        '2',
                        'flutterEmbedding',
                        importance: Importance.max,
                        priority: Priority.high,
                        sound:
                            RawResourceAndroidNotificationSound('notification'),
                      ),
                    ),
                  );
                  _showLocalNotification(lastReceivedMessage!);
                },
                child: const Text(
                  'Chat Screen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
