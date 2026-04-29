import 'package:flutter/material.dart';

// ─── Topkapı Sarayı El Yazması — Aydınlık Palet ──────────────────────────────

const kBg        = Color(0xFFF3E8CE); // parşömen sarısı
const kParchment = Color(0xFFFBF4E6); // levha iç rengi
const kGreen     = Color(0xFF1B4B3E); // zümrüt yeşili
const kDarkBg    = Color(0xFF071912); // gece siyahı
const kGold      = Color(0xFFC9A84C); // Osmanlı altını
const kIndigo    = Color(0xFF1A3A5C); // lapis lazuli mavi

const kIvory     = Color(0xFFFAF3E0); // fildişi — kart ve levha iç rengi
const kInk       = Color(0xFF1A0800); // mürekkep siyahı — metafor metin rengi

// ─── Karanlık Mod — Lapis Lazuli + Altın Paleti ───────────────────────────────

const kDarkSurface  = Color(0xFF0D2018); // koyu zümrüt yüzey
const kDarkPanel    = Color(0xFF112A1E); // panel arka planı
const kDarkText     = Color(0xFFF3E8CE); // parşömen metin (kBg = light bg olarak kullanılır)
const kDarkSubtext  = Color(0xFFD4B97A); // soluk altın alt metin

// ─── Animasyon Süreleri ───────────────────────────────────────────────────────

const kShutterDuration   = Duration(milliseconds: 350);
const kMysticDuration    = Duration(milliseconds: 3200);
const kWaveDuration      = Duration(milliseconds: 1600);
const kWaveEnterDuration = Duration(milliseconds: 900);
const kAmbientDuration   = Duration(seconds: 7);
const kTesbihDuration    = Duration(milliseconds: 9000);
const kSwitchDuration    = Duration(milliseconds: 700);
const kMinAnalysisPause  = Duration(milliseconds: 2200);
const kInkSplashDuration = Duration(milliseconds: 600);

// ─── Layout ───────────────────────────────────────────────────────────────────

const kScreenPaddingH = 20.0;
const kButtonPaddingV = 16.0;
const kTezhipBandH    = 36.0;
const kMuqarnasH      = 48.0;
const kTesbihH        = 90.0;
const kMosqueSilH     = 130.0;
const kCameraFrameSize = 280.0; // dairesel kamera çerçevesi çapı

// ─── API ──────────────────────────────────────────────────────────────────────

const kApiTimeout   = Duration(seconds: 10);
const kMaxRetries   = 3;
const kRetryBackoff = Duration(seconds: 2);
