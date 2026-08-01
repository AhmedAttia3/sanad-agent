import 'package:flutter_driver/flutter_driver.dart';
import 'dart:io';

void main() async {
  final serviceUrl = Platform.environment['VM_SERVICE_URL'];
  if (serviceUrl == null || serviceUrl.isEmpty) {
    print('Error: VM_SERVICE_URL environment variable is not set.');
    exit(1);
  }

  print('Connecting to Flutter Driver...');
  final driver = await FlutterDriver.connect();
  print('Connected successfully!');

  try {
    await driver.runUnsynchronized(() async {
      // 1. Select the workspace first to prevent send blocks
      print('Tapping workspace selector chip...');
      await driver.tap(find.byValueKey('workspace_selector_btn'));
      await Future<void>.delayed(const Duration(seconds: 1));

      final workspaceKey = 'workspace_item_${Directory.current.parent.path}';
      print('Selecting workspace with key: $workspaceKey');
      await driver.tap(find.byValueKey(workspaceKey));
      await Future<void>.delayed(const Duration(seconds: 1));

      // 2. Trigger the clarifying question tool from the agent
      print('Tapping chat input field...');
      await driver.tap(find.byValueKey('chat_input'));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final triggerMessage =
          'Ask me exactly 3 clarifying questions using system_ask_user, each with exactly 3 predefined options, to test the new step-by-step UI.';
      print('Entering message: "$triggerMessage"');
      await driver.enterText(triggerMessage);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      print('Tapping send button...');
      await driver.tap(find.byValueKey('send_message_btn'));
      print('Send tapped successfully!');

      // 3. Wait for the agent/daemon to run and suspend at system_ask_user
      print('Waiting 18 seconds for agent to compile and suspend at system_ask_user...');
      await Future<void>.delayed(const Duration(seconds: 18));

      // 4. Answer Question 1 (1 of 3) using Option 1
      print('Tapping predefined option 1 for Question 1...');
      await driver.tap(find.byValueKey('predefined_option_1'));
      await Future<void>.delayed(const Duration(seconds: 1));

      // 5. Answer Question 2 (2 of 3) using Option 2
      print('Tapping predefined option 2 for Question 2...');
      await driver.tap(find.byValueKey('predefined_option_2'));
      await Future<void>.delayed(const Duration(seconds: 1));

      // 6. Answer Question 3 (3 of 3) using Custom Answer input
      print('Tapping custom answer option for Question 3...');
      await driver.tap(find.byValueKey('custom_answer_option'));
      await Future<void>.delayed(const Duration(milliseconds: 500));

      print('Locating clarifying question text field...');
      await driver.tap(find.byValueKey('clarifying_question_input'));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final answerText = 'Yes, the multi-step UI works completely flawlessly!';
      print('Entering custom answer: "$answerText"');
      await driver.enterText(answerText);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      print('Tapping submit custom answer button...');
      await driver.tap(find.byValueKey('submit_question_answer_btn'));
      print('Submit answer tapped successfully!');

      // 7. Wait for the daemon to resume LangGraph and get the final agent answer
      print('Waiting 15 seconds for agent execution to resume and complete...');
      await Future<void>.delayed(const Duration(seconds: 15));
    });

    print('Interactive UI Test flow completed successfully!');
  } catch (e) {
    print('Error during interactive UI test flow: $e');
  } finally {
    print('Closing driver connection...');
    await driver.close();
    print('Driver closed.');
  }
}
