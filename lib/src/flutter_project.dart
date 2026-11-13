/// App source written by `quds create flutter`.
///
/// Platform folders stay as `flutter create` made them. This file is the
/// program that `quds run` compiles and launches.
const flutterApp = r'''
use package:flutter/material.dart

main():
  runApp(MyApp())

class MyApp extends StatelessWidget:
  build(context: BuildContext) -> Widget:
    app = MaterialApp:
      home: Home()
    return app

class Home extends StatefulWidget:
  createState() -> State<Home>:
    return HomeState()

class HomeState extends State<Home>:
  var count: int = 0
  build(context: BuildContext) -> Widget:
    add = () -> :
      tick = () -> :
        count = count + 1
      setState(tick)
    button = ElevatedButton:
      onPressed: add
      child: Text "Add"
    column = Column:
      children:
        Text "{count}"
        button
    page = Scaffold:
      body: Center(child: column)
    return page
''';
