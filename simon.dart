// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// The "Simon" game for STM32 F7 Discovery board.
// https://en.wikipedia.org/wiki/Simon_(game)

import 'dart:dartino';

import 'package:gpio/gpio.dart';
import 'package:stm32/stm32f746g_disco.dart';
import 'package:stm32/gpio.dart';

const Pin_D0 = STM32Pin.PC7;
const Pin_D1 = STM32Pin.PC6;
const Pin_D2 = STM32Pin.PG6;
const Pin_D3 = STM32Pin.PB4;

const Pin_A0 = STM32Pin.PA0;
const Pin_A1 = STM32Pin.PF10;
const Pin_A2 = STM32Pin.PF9;
const Pin_A3 = STM32Pin.PF8;

main() {
  // Initialize STM32F746G Discovery board.
  STM32F746GDiscovery board = new STM32F746GDiscovery();

  // Array constant containing the GPIO pins of the connected LEDs.
  List<Pin> leds = [Pin_D0, Pin_D1, Pin_D2, Pin_D3];

  // Array constant containing the GPIO pins of the connected buttons.
  List<Pin> buttons = [Pin_A0, Pin_A1, Pin_A2, Pin_A3];

  // Initialize the lights controller class.
  Simon simon = new Simon(board.gpio, leds, buttons)..testLeds();

  // Introduction
  print('''

  Welcome to Simon.
  Press the buttons in the same order that the lights flash.

  ''');

  // Start the game
  int topScore = 0;
  while (true) {
    simon.resetPattern();
    while (true) {
      simon.showPattern();
      if (!simon.checkPattern()) break;
      simon.incrementPattern();
    }
    int score = simon.pattern.length - 1;
    if (topScore < score) topScore = score;
    print('Current score: $score');
    print('Top score:     $topScore');
    print('');
  }
}

class Simon {
  List<GpioOutputPin> outputPins = [];
  List<GpioInputPin> inputPins = [];
  List<int> pattern = [];

  static const int allOn = -1;
  static const int allOff = -2;

  Simon(Gpio gpio, List<Pin> leds, List<Pin> buttons) {
    for (Pin led in leds) {
      outputPins.add(gpio.initOutput(led));
    }
    for (Pin button in buttons) {
      inputPins.add(gpio.initInput(button,
          pullUpDown: GpioPullUpDown.pullDown,
          trigger: GpioInterruptTrigger.falling));
    }
  }

  /// Wait for the user to enter the pattern.
  /// If correct, return true.
  /// If incorrect, flash leds and return false.
  bool checkPattern() {
    for (int index = 0; index < pattern.length; ++index) {
      int expectedButton = pattern[index];
      int actualButton = waitForButton();
      if (actualButton != expectedButton) {
        flashLeds();
        return false;
      }
    }
    return true;
  }

  /// Add one pseudo-random element to the pattern.
  void incrementPattern() {
    pattern.add((new DateTime.now().millisecond >> 4) % inputPins.length);
  }

  /// Reset the pattern to have one element.
  void resetPattern() {
    pattern.clear();
    incrementPattern();
  }

  /// Display the pattern by blinking the corresponding LEDs.
  void showPattern() {
    sleep(500);
    for (int index = 0; index < pattern.length; ++index) {
      setLeds(pattern[index]);
      sleep(500);
      setLeds(allOff);
      sleep(500);
    }
  }

  void flashLeds([int count = 3]) {
    for (int index = 0; index < 3; ++index) {
      setLeds(allOn);
      sleep(250);
      setLeds(allOff);
      sleep(250);
    }
  }

  // Sets LED [ledToEnable] to true, and all others to false.
  void setLeds(int ledToEnable) {
    for (int index = 0; index < outputPins.length; index++) {
      outputPins[index].state = (index == ledToEnable || ledToEnable == allOn);
    }
  }

  /// Return the index of the button currently being pressed, or -1 if none.
  int getButton() {
    for (int index = 0; index < inputPins.length; ++index) {
      if (inputPins[index].state) return index;
    }
    return -1;
  }

  /// Flash each LED.
  void testLeds() {
    for (int index = 0; index < outputPins.length; index++) {
      setLeds(index);
      sleep(500);
    }
    flashLeds(1);
  }

  /// Wait for a button to be pressed then all buttons to be released.
  /// Return the index of the button pressed.
  int waitForButton() {
    int button = -1;
    while (button == -1) {
      sleep(50);
      button = getButton();
    }
    while (getButton() != -1) {
      sleep(50);
    }
    return button;
  }
}
