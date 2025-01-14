import 'dart:io';

import 'package:flutter/material.dart';
import 'package:maid/settings.dart';
import 'package:maid/theme.dart';
import 'package:maid/widgets/drawer_widget.dart';
import 'package:maid/widgets/chat_widgets.dart';

class MaidHomePage extends StatefulWidget {
  const MaidHomePage({super.key, required this.title});

  final String title;

  @override
  State<MaidHomePage> createState() => _MaidHomePageState();
}

class _MaidHomePageState extends State<MaidHomePage> {
  final ScrollController _consoleScrollController = ScrollController();
  List<Widget> chatWidgets = [];
  ResponseMessage newResponse = ResponseMessage();

  int historyLength = 0;
  int responseLength = 0;
  Lib? lib;

  int characterMatch = 0;
  int lineBreakMatch = 0;

  bool busy = false;

  void execute() {
    //close the keyboard if on mobile
    if (Platform.isAndroid || Platform.isIOS) {
      FocusScope.of(context).unfocus();
    }
    setState(() {
      busy = true;
      settings.saveAll();
      chatWidgets
          .add(UserMessage(message: settings.promptController.text.trim()));
      settings.promptController.text +=
          '\n${settings.responseAliasController.text}';
      settings.compilePrePrompt();
      historyLength = settings.promptController.text.trim().length + 1;
      historyLength += (responseLength == 0) ? settings.prePrompt.length : 0;
      responseLength = 0;
      settings.inProgress = true;
    });
    if (lib == null) {
      lib = Lib.instance;
      lib?.butlerStart(responseCallback);
    } else {
      lib?.butlerContinue();
    }
    setState(() {
      newResponse = ResponseMessage();
      chatWidgets.add(newResponse);
      settings.promptController.text = ""; // Clear the input field
    });
  }

  void scrollDown() {
    _consoleScrollController.animateTo(
      _consoleScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 50),
      curve: Curves.easeOut,
    );
  }

  void responseCallback(String message) {
    String alias = settings.userAliasController.text;
    int i = 0;

    if (!settings.inProgress || message.isEmpty) {
      return;
    }

    while (i < message.length) {
      responseLength++;

      if (responseLength > historyLength) {
        // If the current character matches the expected character in the model text
        if (alias.isNotEmpty && message[i] == alias[characterMatch]) {
          characterMatch++;

          // If the entire model text is matched, reset the match position
          if (characterMatch >= alias.length) {
            settings.inProgress = false;
            break;
          }
        } else if (message[i] == '\n') {
          lineBreakMatch++;

          if (lineBreakMatch >= 3) {
            settings.inProgress = false;
            break;
          }
        } else {
          // If there's a mismatch, add the remaining message to newResponse
          newResponse.addMessage(message.substring(i - characterMatch));
          scrollDown();
          characterMatch = 0;
          return;
        }
      }

      i++;
    }

    if (!settings.inProgress) {
      characterMatch = 0;
      lineBreakMatch = 0;
      lib?.butlerStop();
      newResponse.trim();
      newResponse.finalise();
      setState(() {
        busy = false;
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
          ),
        ),
        title: Text(widget.title),
      ),
      drawer: const MaidDrawer(),
      body: Builder(
        builder: (BuildContext context) => GestureDetector(
          onHorizontalDragEnd: (details) {
            // Check if the drag is towards right with a certain velocity
            if (details.primaryVelocity! > 100) {
              // Open the drawer
              Scaffold.of(context).openDrawer();
            }
          },
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                ),
              ),
              Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _consoleScrollController,
                      itemCount: chatWidgets.length,
                      itemBuilder: (BuildContext context, int index) {
                        return chatWidgets[index];
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                              keyboardType: TextInputType.multiline,
                              onSubmitted: (value) {
                                if (!busy) {
                                  execute();
                                }
                              },
                              controller: settings.promptController,
                              cursorColor:
                                  Theme.of(context).colorScheme.secondary,
                              decoration: roundedInput('Prompt', context)),
                        ),
                        IconButton(
                            onPressed: busy ? null : execute,
                            iconSize: 50,
                            icon: Icon(
                              Icons.arrow_circle_right,
                              color: busy
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.secondary,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
