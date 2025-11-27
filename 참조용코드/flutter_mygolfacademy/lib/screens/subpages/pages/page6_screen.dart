import 'package:flutter/material.dart';

class Page6Screen extends StatelessWidget {
  const Page6Screen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메뉴 6'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.help,
              size: 80,
              color: Colors.indigo,
            ),
            const SizedBox(height: 24),
            const Text(
              '메뉴 6',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '개발중입니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
} 