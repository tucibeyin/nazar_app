import 'package:flutter/material.dart';

class AnalyzingIndicator extends StatelessWidget {
  const AnalyzingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
      SizedBox(width: 10),
      Text(
        'Analiz ediliyor...',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ],
  );
}
