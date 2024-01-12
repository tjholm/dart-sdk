import 'dart:convert';

import 'package:dart_sdk/src/nitric/google/protobuf/duration.pb.dart' as $d;
import 'package:dart_sdk/src/nitric/google/protobuf/struct.pb.dart';
import 'package:dart_sdk/src/nitric/proto/topics/v1/topics.pbgrpc.dart' as $p;
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

class Message {}

class Topic {
  String name;
  late $p.TopicsClient _topicsClient;

  Topic(this.name) {
    final channel = ClientChannel('localhost',
        port: 50051,
        options: ChannelOptions(credentials: ChannelCredentials.insecure()));

    _topicsClient = $p.TopicsClient(channel);
  }

  /// Publish a [message] to the topic. Optional [delay] (in seconds) can be set to delay the message publish time.
  Future<void> publish(Map<String, dynamic> message, [int delay = 0]) async {
    // Convert the message to a proto struct wrapped in an event message

    final messageStruct = Struct.create();
    messageStruct.mergeFromJsonMap(message);

    var req = $p.TopicPublishRequest(
      topicName: name,
      message: $p.Message(structPayload: messageStruct),
      delay: $d.Duration(seconds: Int64(delay)),
    );

    await _topicsClient.publish(req);
  }
}
