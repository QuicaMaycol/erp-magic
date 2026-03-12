import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/upload_service.dart';

class UploadProgressOverlay extends StatelessWidget {
  final Function(UploadTask)? onTaskTap;
  const UploadProgressOverlay({super.key, this.onTaskTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UploadService(),
      builder: (context, _) {
        final tasks = UploadService().tasks;
        if (tasks.isEmpty) return const SizedBox.shrink();

        return Positioned(
          right: 20,
          bottom: 100, // Arriba de la barra de navegación en móviles
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'SUBIDAS ACTIVAS',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (tasks.any((t) => t.status != UploadStatus.uploading))
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white38, size: 14),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => UploadService().clearCompleted(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: tasks.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final task = tasks[index];
                                return _UploadItem(
                                  task: task,
                                  onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UploadItem extends StatelessWidget {
  final UploadTask task;
  final VoidCallback? onTap;
  const _UploadItem({required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    Color statusColor = const Color(0xFF7C3AED);
    IconData icon = Icons.cloud_upload_outlined;

    if (task.status == UploadStatus.success) {
      statusColor = Colors.greenAccent;
      icon = Icons.check_circle_outline;
    } else if (task.status == UploadStatus.error) {
      statusColor = Colors.redAccent;
      icon = Icons.error_outline;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.fileName,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(task.progress * 100).toInt()}%',
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                if (task.status != UploadStatus.uploading)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38, size: 12),
                    padding: const EdgeInsets.only(left: 8),
                    constraints: const BoxConstraints(),
                    onPressed: () => UploadService().removeTask(task.id),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: task.progress,
                backgroundColor: Colors.white.withOpacity(0.05),
                color: statusColor,
                minHeight: 3,
              ),
            ),
            if (task.status == UploadStatus.error)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  task.error ?? 'Error desconocido',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 8),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Orden #${task.orderId} - ${task.clientName}',
                style: const TextStyle(color: Colors.white24, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
