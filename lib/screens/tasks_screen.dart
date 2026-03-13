import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../models/task_model.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_snackbar.dart';
import 'add_task_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load tasks on first paint
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllTasks());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTasks() async {
    final auth = context.read<AuthProvider>();
    final tasks = context.read<TaskProvider>();
    if (auth.user != null) {
      tasks.setupTaskListener(auth.user!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tasks & Notes'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'All Tasks'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAllTasks(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTaskScreen()),
          );
          if (result == true && authProvider.user != null) {
            _loadAllTasks();
            if (mounted) CustomSnackBar.showSuccess(context, 'Tasks refreshed');
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textInverse,
        child: const Icon(Icons.add),
      ),
      body: taskProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(taskProvider.todaysTasks, taskProvider, emptyLabel: 'No tasks for today'),
                _buildTaskList(taskProvider.allTasks, taskProvider, emptyLabel: 'No tasks yet. Add one!'),
              ],
            ),
    );
  }

  Widget _buildTaskList(
    List<TaskModel> tasks,
    TaskProvider taskProvider, {
    required String emptyLabel,
  }) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              emptyLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add a new task',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadAllTasks(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Dismissible(
            key: Key(task.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) => _showDeleteConfirmDialog(task),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: task.isCompleted
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Checkbox(
                  value: task.isCompleted,
                  activeColor: AppColors.primary,
                  onChanged: (_) => taskProvider.toggleTaskCompletion(task.id, task.isCompleted),
                ),
                title: Text(
                  task.title,
                  style: TextStyle(
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w600,
                    color: task.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: TextStyle(color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(task.date),
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('hh:mm a').format(task.date),
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        if (task.reminderSet) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.notifications_active, size: 14, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: task.isCompleted
                    ? IconButton(
                        icon: const Icon(Icons.undo, color: AppColors.textSecondary),
                        onPressed: () => taskProvider.toggleTaskCompletion(task.id, true),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(TaskModel task) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Provider.of<TaskProvider>(ctx, listen: false).deleteTask(task);
              Navigator.pop(ctx, true);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
