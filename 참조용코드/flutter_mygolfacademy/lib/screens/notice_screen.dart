import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:famd_clientapp/providers/notice_provider.dart';
import 'package:famd_clientapp/models/notice.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({Key? key}) : super(key: key);

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
      ),
      body: Consumer<NoticeProvider>(
        builder: (context, noticeProvider, child) {
          if (noticeProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (noticeProvider.notices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('공지사항이 없습니다.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await noticeProvider.loadNotices();
                    },
                    child: const Text('새로고침'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => noticeProvider.loadNotices(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: noticeProvider.notices.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notice = noticeProvider.notices[index];
                return _buildNoticeItem(notice);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoticeItem(Notice notice) {
    return InkWell(
      onTap: () {
        _showNoticeDetail(notice);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notice.isImportant)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8, top: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '중요',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: TextStyle(
                      fontWeight: notice.isImportant ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${notice.date.year}/${notice.date.month}/${notice.date.day}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notice.content,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoticeDetail(Notice notice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (notice.isImportant)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '중요',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                notice.title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${notice.date.year}/${notice.date.month}/${notice.date.day}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  notice.content,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
} 