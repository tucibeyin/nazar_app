import 'package:flutter/material.dart';

// ─── Topkapı Sarayı El Yazması Renk Paleti ────────────────────────────────────

const kBg        = Color(0xFFF3E8CE); // parşömen sarısı
const kParchment = Color(0xFFFBF4E6); // levha iç rengi
const kGreen     = Color(0xFF1B4B3E); // zümrüt yeşili
const kDarkBg    = Color(0xFF071912); // gece siyahı
const kGold      = Color(0xFFC9A84C); // Osmanlı altını
const kIndigo    = Color(0xFF1A3A5C); // lapis lazuli mavi

// ─── Animasyon Süreleri ───────────────────────────────────────────────────────

const kShutterDuration   = Duration(milliseconds: 350);
const kMysticDuration    = Duration(milliseconds: 3200);
const kWaveDuration      = Duration(milliseconds: 1600);
const kWaveEnterDuration = Duration(milliseconds: 900);
const kAmbientDuration   = Duration(seconds: 7);
const kTesbihDuration    = Duration(milliseconds: 9000);
const kSwitchDuration    = Duration(milliseconds: 700);
const kMinAnalysisPause  = Duration(milliseconds: 2200);

// ─── Layout ───────────────────────────────────────────────────────────────────

const kScreenPaddingH = 20.0;
const kButtonPaddingV = 16.0;
const kTezhipBandH    = 36.0;
const kMuqarnasH      = 48.0;
const kTesbihH        = 62.0;
const kMosqueSilH     = 130.0;

// ─── API ──────────────────────────────────────────────────────────────────────

const kApiTimeout   = Duration(seconds: 10);
const kMaxRetries   = 3;
const kRetryBackoff = Duration(seconds: 2);
