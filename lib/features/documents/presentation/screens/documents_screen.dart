import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/app_bar_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../models/document_model.dart';
import '../providers/documents_provider.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider);
    final profileAsync = ref.watch(profileProvider);
    final isManager = profileAsync.maybeWhen(
      data: (p) => p?.isManager ?? false,
      orElse: () => false,
    );

    return Scaffold(
      appBar: const DomovnikAppBar(title: 'Dokumenty', showBack: false),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => _uploadDocument(context, ref),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: const Text('Nahrať dokument',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
      body: docsAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.folder_outlined,
              message: 'Žiadne dokumenty',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(documentsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, i) => _DocumentCard(
                doc: docs[i],
                isManager: isManager,
                onDelete: isManager
                    ? () => _confirmDelete(context, ref, docs[i])
                    : null,
              ),
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => DomovnikErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(documentsProvider),
        ),
      ),
    );
  }

  Future<void> _uploadDocument(BuildContext context, WidgetRef ref) async {
    // Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg'],
      withData: true, // loads bytes on web too
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nepodarilo sa načítať súbor'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    // Ask for display name
    final nameController =
        TextEditingController(text: file.name.replaceAll(RegExp(r'\.\w+$'), ''));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Názov dokumentu'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Názov *',
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Zrušiť')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Nahrať')),
        ],
      ),
    );
    if (confirmed != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final mimeType = _mimeFromExtension(file.extension ?? 'pdf');

    try {
      await ref.read(uploadDocumentProvider.notifier).upload(
            name: name,
            bytes: bytes,
            mimeType: mimeType,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Dokument bol nahraný'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Chyba: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odstrániť dokument'),
        content: Text('Naozaj chcete odstrániť "${doc.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Zrušiť')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Odstrániť'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(deleteDocumentProvider.notifier).deleteDocument(doc);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }
  }

  String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'png':
        return 'image/png';
      default:
        return 'image/jpeg';
    }
  }
}

// ── Document Card ─────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final DocumentModel doc;
  final bool isManager;
  final VoidCallback? onDelete;

  const _DocumentCard({
    required this.doc,
    required this.isManager,
    this.onDelete,
  });

  Future<void> _open() async {
    final uri = Uri.parse(doc.fileUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData get _icon {
    if (doc.fileUrl.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (doc.fileUrl.endsWith('.doc') || doc.fileUrl.endsWith('.docx')) {
      return Icons.article_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withValues(alpha: 0.12),
          child: Icon(_icon, color: AppColors.accent),
        ),
        title: Text(doc.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${DateFormatter.formatDate(doc.createdAt)}'
          '${doc.fileSizeLabel.isNotEmpty ? ' · ${doc.fileSizeLabel}' : ''}',
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new, color: AppColors.primary),
              tooltip: 'Otvoriť',
              onPressed: _open,
            ),
            if (isManager)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Odstrániť',
                onPressed: onDelete,
              ),
          ],
        ),
        onTap: _open,
      ),
    );
  }
}
