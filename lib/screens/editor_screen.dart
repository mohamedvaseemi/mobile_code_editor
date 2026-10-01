import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

import '../services/api_service.dart';
import '../services/git_service.dart';
import '../services/storage_service.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GitService _gitService = GitService();
  final TextEditingController _stdinController = TextEditingController();

  List<String> _fileList = [];
  String _activeFileName = 'main.py';
  final Map<String, CodeLineEditingController> _controllers = {};
  final Set<String> _dirtyFiles = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _stdinController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    setState(() => _isLoading = true);
    final files = await StorageService.listFiles();
    _fileList = files.map((f) => f.path.split('/').last).toList();

    if (_fileList.isEmpty) {
      await StorageService.createFile('main.py');
      _fileList = ['main.py'];
    }

    if (!_fileList.contains(_activeFileName)) {
      _activeFileName = _fileList.first;
    }

    for (final file in _fileList) {
      final content = await StorageService.readFile(file);
      final ctrl = CodeLineEditingController.fromText(content);
      ctrl.addListener(() => _handleContentChange(file, ctrl.text));
      _controllers[file] = ctrl;
    }

    setState(() => _isLoading = false);
  }

  void _handleContentChange(String fileName, String newText) {
    if (!_dirtyFiles.contains(fileName)) {
      setState(() => _dirtyFiles.add(fileName));
    }
  }

  Future<void> _saveActiveFile() async {
    if (_controllers.containsKey(_activeFileName)) {
      await StorageService.saveFile(
        _activeFileName,
        _controllers[_activeFileName]!.text,
      );
      setState(() => _dirtyFiles.remove(_activeFileName));
    }
  }

  dynamic _getLanguageGrammar(String fileName) {
    if (fileName.endsWith('.py')) return langPython;
    if (fileName.endsWith('.js')) return langJavascript;
    if (fileName.endsWith('.cpp') || fileName.endsWith('.cc')) return langCpp;
    if (fileName.endsWith('.go')) return langGo;
    if (fileName.endsWith('.json')) return langJson;
    return null;
  }

  String _getLanguageName(String fileName) {
    if (fileName.endsWith('.py')) return 'python';
    if (fileName.endsWith('.js')) return 'javascript';
    if (fileName.endsWith('.cpp') || fileName.endsWith('.cc')) return 'cpp';
    if (fileName.endsWith('.go')) return 'go';
    if (fileName.endsWith('.json')) return 'json';
    return 'plaintext';
  }

  Widget _buildFileIcon(String fileName) {
    if (fileName.endsWith('.py')) {
      return const Icon(Icons.code, size: 16, color: Color(0xFF4B8BBE));
    } else if (fileName.endsWith('.js')) {
      return const Icon(Icons.javascript, size: 16, color: Color(0xFFF7DF1E));
    } else if (fileName.endsWith('.cpp') || fileName.endsWith('.cc')) {
      return const Icon(Icons.memory, size: 16, color: Color(0xFF00599C));
    } else if (fileName.endsWith('.go')) {
      return const Icon(Icons.bolt, size: 16, color: Color(0xFF00ADD8));
    } else if (fileName.endsWith('.json')) {
      return const Icon(Icons.data_object, size: 16, color: Color(0xFFCBCB41));
    }
    return const Icon(Icons.text_snippet_outlined, size: 16, color: Colors.white54);
  }

  // --- Run Code & Interactive Terminal ---

  Future<void> _executeActiveFile() async {
    await _saveActiveFile();
    final lang = _getLanguageName(_activeFileName);

    if (lang == 'plaintext' || lang == 'json') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot execute this file format.')),
      );
      return;
    }

    _showTerminalModal(lang);
  }

  void _showTerminalModal(String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              height: 380,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.terminal, color: Color(0xFF61AFEF), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'TERMINAL ($lang)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  Expanded(
                    child: FutureBuilder<ExecutionResponse>(
                      future: ApiService.executeCode(
                        language: lang,
                        code: _controllers[_activeFileName]!.text,
                        stdin: _stdinController.text,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF007ACC)),
                                SizedBox(height: 12),
                                Text('Executing code...', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return SelectableText(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Color(0xFFFF6B68), fontFamily: 'monospace', fontSize: 13),
                          );
                        }

                        final res = snapshot.data!;
                        final hasError = res.stderr.isNotEmpty;

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Exit Code: ${res.exitCode} (${res.durationMs}ms) ${res.cached ? "[CACHE]" : ""}',
                                style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                hasError ? res.stderr : (res.stdout.isEmpty ? '[No output]' : res.stdout),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  color: hasError ? const Color(0xFFFF6B68) : const Color(0xFF98C379),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 12),
                  Row(
                    children: [
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF98C379)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _stdinController,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            hintText: 'Input for program (stdin)...',
                            hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay, color: Color(0xFF61AFEF), size: 18),
                        tooltip: 'Re-run with new input',
                        onPressed: () {
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Dialogs ---

  void _showNewFileDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252526),
        title: const Text('New File', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. script.py, main.cpp',
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007ACC)),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                await StorageService.createFile(name);
                final ctrl = CodeLineEditingController.fromText('');
                ctrl.addListener(() => _handleContentChange(name, ctrl.text));
                setState(() {
                  _fileList.add(name);
                  _controllers[name] = ctrl;
                  _activeFileName = name;
                });
                Navigator.pop(ctx);
                if (Scaffold.of(context).isDrawerOpen) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showGitDialog() async {
    await _saveActiveFile();
    final creds = await StorageService.getGitHubCredentials();
    final ownerCtrl = TextEditingController(text: creds['owner']);
    final repoCtrl = TextEditingController(text: creds['repo']);
    final commitCtrl = TextEditingController(text: 'feat: update $_activeFileName');
    final tokenCtrl = TextEditingController(text: creds['token']);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252526),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload, color: Color(0xFF007ACC)),
            SizedBox(width: 8),
            Text('Push to GitHub', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ownerCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'GitHub Username', labelStyle: TextStyle(color: Colors.white54)),
              ),
              TextField(
                controller: repoCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Repository Name', labelStyle: TextStyle(color: Colors.white54)),
              ),
              TextField(
                controller: commitCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Commit Message', labelStyle: TextStyle(color: Colors.white54)),
              ),
              TextField(
                controller: tokenCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Personal Access Token', labelStyle: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007ACC)),
            onPressed: () async {
              try {
                final owner = ownerCtrl.text.trim();
                final repo = repoCtrl.text.trim();
                final token = tokenCtrl.text.trim();

                await StorageService.saveGitHubCredentials(
                  owner: owner,
                  repo: repo,
                  token: token,
                );

                await _gitService.commitAndPushToGitHub(
                  repoOwner: owner,
                  repoName: repo,
                  filePath: _activeFileName,
                  content: _controllers[_activeFileName]!.text,
                  commitMessage: commitCtrl.text.trim(),
                  personalAccessToken: token,
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pushed to GitHub successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Push error: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Push', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCloneDialog() async {
    final creds = await StorageService.getGitHubCredentials();
    final ownerCtrl = TextEditingController(text: creds['owner']);
    final repoCtrl = TextEditingController(text: creds['repo']);
    final tokenCtrl = TextEditingController(text: creds['token']);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252526),
        title: const Text('Clone from GitHub', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ownerCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'GitHub Username / Org', labelStyle: TextStyle(color: Colors.white54)),
              ),
              TextField(
                controller: repoCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Repository Name', labelStyle: TextStyle(color: Colors.white54)),
              ),
              TextField(
                controller: tokenCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Personal Access Token', labelStyle: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007ACC)),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              try {
                final files = await _gitService.cloneGitHubRepo(
                  repoOwner: ownerCtrl.text.trim(),
                  repoName: repoCtrl.text.trim(),
                  personalAccessToken: tokenCtrl.text.trim(),
                );

                await StorageService.saveGitHubCredentials(
                  owner: ownerCtrl.text.trim(),
                  repo: repoCtrl.text.trim(),
                  token: tokenCtrl.text.trim(),
                );

                await _loadWorkspace();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cloned ${files.length} files successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Clone error: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Clone', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- UI Layout ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E1E1E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF007ACC))),
      );
    }

    final grammar = _getLanguageGrammar(_activeFileName);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      drawer: _buildExplorerDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.folder_outlined, color: Colors.white70),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(_activeFileName, style: const TextStyle(fontSize: 15, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white70),
            tooltip: 'Save',
            onPressed: _saveActiveFile,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF61AFEF)),
            tooltip: 'Git Push',
            onPressed: _showGitDialog,
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Color(0xFF98C379)),
            tooltip: 'Run Code',
            onPressed: _executeActiveFile,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: grammar != null
                  ? CodeAutocomplete(
                      viewBuilder: (context, notifier, onSelected) {
                        return PreferredSize(
                          preferredSize: const Size(240, 180),
                          child: ValueListenableBuilder<CodeAutocompleteEditingValue?>(
                            valueListenable: notifier,
                            builder: (context, result, _) {
                              final prompts = result?.prompts.toList();
                              if (prompts == null || prompts.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                constraints: const BoxConstraints(maxHeight: 180, maxWidth: 240),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252526),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF454545)),
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: prompts.length,
                                  itemBuilder: (context, index) {
                                    final prompt = prompts[index];
                                    return InkWell(
                                      onTap: () => onSelected(prompt.autocomplete),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.code, size: 14, color: Color(0xFF61AFEF)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                prompt.word,
                                                style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                      promptsBuilder: DefaultCodeAutocompletePromptsBuilder(language: grammar),
                      child: _buildEditorView(grammar),
                    )
                  : _buildEditorView(null),
            ),
            _buildAccessoryBar(),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 38,
      color: const Color(0xFF252526),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _fileList.map((fileName) {
          final isActive = fileName == _activeFileName;
          final isDirty = _dirtyFiles.contains(fileName);

          return GestureDetector(
            onTap: () => setState(() => _activeFileName = fileName),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D2D),
                border: Border(
                  top: BorderSide(color: isActive ? const Color(0xFF007ACC) : Colors.transparent, width: 2),
                  right: const BorderSide(color: Color(0xFF1E1E1E), width: 1),
                ),
              ),
              child: Row(
                children: [
                  _buildFileIcon(fileName),
                  const SizedBox(width: 6),
                  Text(fileName, style: TextStyle(color: isActive ? Colors.white : Colors.white60, fontSize: 13)),
                  if (isDirty) ...[
                    const SizedBox(width: 6),
                    const Text('●', style: TextStyle(color: Colors.white60, fontSize: 10)),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEditorView(dynamic grammar) {
    final activeCtrl = _controllers[_activeFileName] ?? CodeLineEditingController.fromText('');
    return CodeEditor(
      key: ValueKey(_activeFileName),
      controller: activeCtrl,
      style: CodeEditorStyle(
        fontSize: 14,
        codeTheme: CodeHighlightTheme(
          languages: {
            if (grammar != null) _getLanguageName(_activeFileName): CodeHighlightThemeMode(mode: grammar),
          },
          theme: atomOneDarkTheme,
        ),
      ),
      indicatorBuilder: (context, editingController, chunkController, notifier) {
        return Row(
          children: [
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
              textStyle: const TextStyle(color: Color(0xFF5A5A5A), fontSize: 12),
            ),
            DefaultCodeChunkIndicator(width: 16, controller: chunkController, notifier: notifier),
          ],
        );
      },
    );
  }

  Widget _buildAccessoryBar() {
    final activeCtrl = _controllers[_activeFileName];
    final keys = ['Tab', '{', '}', '(', ')', '[', ']', ':', ';', '"', '\'', '=', '#', '.', '_'];

    return Container(
      height: 42,
      color: const Color(0xFF252526),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: keys.map((char) {
          return InkWell(
            onTap: () {
              if (activeCtrl == null) return;
              final insert = char == 'Tab' ? '    ' : char;
              activeCtrl.replaceSelection(insert);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Text(char, style: const TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'monospace')),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBar() {
    final isDirty = _dirtyFiles.contains(_activeFileName);
    return Container(
      height: 24,
      color: const Color(0xFF007ACC),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_alt, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              const Text('main*', style: TextStyle(color: Colors.white, fontSize: 11)),
              const SizedBox(width: 10),
              if (isDirty) const Text('Unsaved', style: TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
          Row(
            children: [
              const Text('UTF-8', style: TextStyle(color: Colors.white, fontSize: 11)),
              const SizedBox(width: 10),
              Text(
                _getLanguageName(_activeFileName).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExplorerDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF252526),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            color: const Color(0xFF2D2D2D),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('EXPLORER', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_outlined, color: Color(0xFF61AFEF), size: 20),
                      tooltip: 'Clone from GitHub',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _showCloneDialog,
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      icon: const Icon(Icons.note_add_outlined, color: Colors.white70, size: 20),
                      tooltip: 'New File',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _showNewFileDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _fileList.map((fileName) {
                final isSelected = fileName == _activeFileName;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: const Color(0xFF37373D),
                  leading: _buildFileIcon(fileName),
                  title: Text(fileName, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white24),
                    onPressed: () async {
                      if (_fileList.length <= 1) return;
                      await StorageService.deleteFile(fileName);
                      setState(() {
                        _fileList.remove(fileName);
                        _controllers.remove(fileName);
                        if (_activeFileName == fileName) {
                          _activeFileName = _fileList.first;
                        }
                      });
                    },
                  ),
                  onTap: () {
                    setState(() => _activeFileName = fileName);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}