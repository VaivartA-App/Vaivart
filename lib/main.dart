/// The entry point for the Vaivart application.
/// 
/// This file initializes the application, sets up the window manager for desktop platforms,
/// and delegates execution to either the graphical UI [FileConverterApp] or the TUI.
import 'dart:io';
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  runApp(const FileConverterApp());
}
