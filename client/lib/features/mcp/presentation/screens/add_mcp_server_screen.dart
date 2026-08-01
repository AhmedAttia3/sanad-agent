import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sanad_client/features/mcp/data/mcp_runtime_client.dart';
import 'package:sanad_client/features/mcp/domain/models/mcp_runtime_models.dart';
import 'package:sanad_client/features/mcp/domain/models/mcp_server_config.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';
import 'package:sanad_client/infrastructure/mcp/mcp_transport_detector.dart';
import 'package:sanad_client/utils/toast_utils.dart';

enum _McpServerFormType { remote, stdio }

/// صفحة إضافة خادم MCP جديد
class AddMcpServerScreen extends StatefulWidget {
  const AddMcpServerScreen({
    super.key,
    this.workspacePath,
    this.scopeLabel,
    this.scope = McpConfigScope.global,
    this.device,
  });

  final String? workspacePath;
  final String? scopeLabel;
  final McpConfigScope scope;
  final DeviceConfig? device;

  @override
  State<AddMcpServerScreen> createState() => _AddMcpServerScreenState();
}

class _AddMcpServerScreenState extends State<AddMcpServerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final _oauthClientIdController = TextEditingController();
  final _oauthClientSecretController = TextEditingController();
  final _commandController = TextEditingController();
  final _argsController = TextEditingController();
  final _envController = TextEditingController();

  _McpServerFormType _serverType = _McpServerFormType.remote;
  McpAuthType _authType = McpAuthType.oauth;
  bool _isLoading = false;
  bool _acceptedRisks = false;

  bool _isTesting = false;
  bool? _testSuccess;
  String? _testMessage;
  McpTransportType? _detectedTransport;
  List<String>? _availableTools;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  String? _discoveredOAuthClientId;
  String? _discoveredOAuthTokenUrl;
  String? _discoveredOAuthAuthUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _oauthClientIdController.dispose();
    _oauthClientSecretController.dispose();
    _commandController.dispose();
    _argsController.dispose();
    _envController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_serverType == _McpServerFormType.stdio) {
      setState(() {
        _testSuccess = true;
        _testMessage = 'STDIO configuration looks valid. Save to enable this server.';
        _detectedTransport = McpTransportType.stdio;
        _availableTools = null;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testSuccess = null;
      _testMessage = null;
      _detectedTransport = null;
      _availableTools = null;
      _accessToken = null;
      _refreshToken = null;
      _tokenExpiry = null;
      _discoveredOAuthClientId = null;
      _discoveredOAuthTokenUrl = null;
      _discoveredOAuthAuthUrl = null;
    });

    try {
      final result = await McpTransportDetector.testConnection(
        serverUrl: _urlController.text.trim(),
        authType: _authType,
        oauthClientId: _oauthClientIdController.text.trim().isEmpty ? null : _oauthClientIdController.text.trim(),
        oauthClientSecret: _oauthClientSecretController.text.trim().isEmpty
            ? null
            : _oauthClientSecretController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _testSuccess = result.success;
        _testMessage = result.message;
        _detectedTransport = result.detectedTransport;
        _availableTools = result.availableTools;
        _accessToken = result.accessToken;
        _refreshToken = result.refreshToken;
        _tokenExpiry = result.tokenExpiry;
        _discoveredOAuthClientId = result.oauthClientId;
        _discoveredOAuthTokenUrl = result.oauthTokenUrl;
        _discoveredOAuthAuthUrl = result.oauthAuthUrl;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _testSuccess = false;
        _testMessage = 'Test failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<void> _createServer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_serverType == _McpServerFormType.remote && _testSuccess != true) {
      ToastUtils.showError(context, 'Please test the connection first');
      return;
    }

    if (!_acceptedRisks) {
      ToastUtils.showError(context, 'Please acknowledge the risks before continuing');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final config = McpServerConfig(
        name: _nameController.text.trim(),
        description: _trimOrNull(_descriptionController.text),
        serverUrl: _serverType == _McpServerFormType.remote ? _urlController.text.trim() : '',
        authType: _serverType == _McpServerFormType.remote ? _authType : McpAuthType.noAuth,
        oauthClientId: _serverType == _McpServerFormType.remote
            ? _discoveredOAuthClientId ?? _trimOrNull(_oauthClientIdController.text)
            : null,
        oauthClientSecret:
            _serverType == _McpServerFormType.remote &&
                (_authType == McpAuthType.oauth || _authType == McpAuthType.mixed)
            ? _trimOrNull(_oauthClientSecretController.text)
            : null,
        detectedTransport: _serverType == _McpServerFormType.remote ? _detectedTransport : McpTransportType.stdio,
        accessToken: _serverType == _McpServerFormType.remote ? _accessToken : null,
        refreshToken: _serverType == _McpServerFormType.remote ? _refreshToken : null,
        tokenExpiry: _serverType == _McpServerFormType.remote ? _tokenExpiry : null,
        oauthTokenUrl: _serverType == _McpServerFormType.remote ? _discoveredOAuthTokenUrl : null,
        oauthAuthUrl: _serverType == _McpServerFormType.remote ? _discoveredOAuthAuthUrl : null,
        command: _serverType == _McpServerFormType.stdio ? _trimOrNull(_commandController.text) : null,
        args: _serverType == _McpServerFormType.stdio ? _parseArgs() : null,
        env: _serverType == _McpServerFormType.stdio ? _parseEnv() : null,
      );

      await context.read<McpRuntimeClient>().saveServer(
        device: widget.device,
        scope: widget.scope,
        workspaceId: widget.workspacePath,
        config: config,
      );

      if (mounted) {
        Navigator.pop(context, config);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.scopeLabel == null ? 'New MCP Server' : 'New ${widget.scopeLabel} MCP Server',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _label(context, 'Name'),
            _textField(
              context,
              controller: _nameController,
              hintText: 'filesystem-local',
              validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 20),
            _label(context, 'Description (optional)'),
            _textField(
              context,
              controller: _descriptionController,
              hintText: 'Explain what it does in a few words',
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            _label(context, 'Server Type'),
            _dropdownField<_McpServerFormType>(
              context,
              value: _serverType,
              items: const [
                DropdownMenuItem(
                  value: _McpServerFormType.remote,
                  child: Text('Remote (HTTP / SSE)'),
                ),
                DropdownMenuItem(
                  value: _McpServerFormType.stdio,
                  child: Text('STDIO'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _serverType = value;
                  _testSuccess = null;
                  _testMessage = null;
                  _availableTools = null;
                  _detectedTransport = value == _McpServerFormType.stdio ? McpTransportType.stdio : null;
                });
              },
            ),
            const SizedBox(height: 20),
            if (_serverType == _McpServerFormType.remote) ..._buildRemoteFields(context),
            if (_serverType == _McpServerFormType.stdio) ..._buildStdioFields(context),
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Icon(_serverType == _McpServerFormType.stdio ? Icons.rule_folder : Icons.wifi_find),
              label: Text(
                _isTesting
                    ? 'Testing...'
                    : _serverType == _McpServerFormType.stdio
                    ? 'Validate Config'
                    : 'Test Connection',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            if (_testSuccess != null) ...[
              _buildTestResult(context),
              const SizedBox(height: 20),
            ],
            _buildRiskNotice(context),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _acceptedRisks,
              onChanged: (value) => setState(() => _acceptedRisks = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: Theme.of(context).colorScheme.primary,
              checkColor: Theme.of(context).colorScheme.onPrimary,
              title: RichText(
                text: TextSpan(
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  children: [
                    const TextSpan(text: 'I understand and want to continue\n'),
                    TextSpan(
                      text:
                          'OpenAI hasn\'t reviewed this MCP server. Attackers may attempt to steal your data or trick the model into taking unintended actions, including destroying data.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _createServer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                          ),
                        )
                      : const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRemoteFields(BuildContext context) {
    return [
      _label(context, 'MCP Server URL'),
      _textField(
        context,
        controller: _urlController,
        hintText: 'https://example.com/mcp',
        validator: (value) {
          if (_serverType != _McpServerFormType.remote) {
            return null;
          }
          if (value == null || value.trim().isEmpty) {
            return 'Server URL is required';
          }
          if (!value.startsWith('http://') && !value.startsWith('https://')) {
            return 'URL must start with http:// or https://';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _label(context, 'Authentication'),
      _dropdownField<McpAuthType>(
        context,
        value: _authType,
        items: McpAuthType.values
            .map((type) => DropdownMenuItem(value: type, child: Text(type.displayName)))
            .toList(growable: false),
        onChanged: (value) {
          if (value != null) {
            setState(() => _authType = value);
          }
        },
      ),
      const SizedBox(height: 20),
      if (_authType == McpAuthType.oauth || _authType == McpAuthType.mixed) ...[
        _label(context, 'OAuth Client ID (Optional)'),
        _textField(context, controller: _oauthClientIdController),
        const SizedBox(height: 20),
        _label(context, 'OAuth Client Secret (Optional)'),
        _textField(
          context,
          controller: _oauthClientSecretController,
          obscureText: true,
        ),
        const SizedBox(height: 20),
      ],
    ];
  }

  List<Widget> _buildStdioFields(BuildContext context) {
    return [
      _label(context, 'Command'),
      _textField(
        context,
        controller: _commandController,
        hintText: 'npx',
        validator: (value) {
          if (_serverType != _McpServerFormType.stdio) {
            return null;
          }
          if (value == null || value.trim().isEmpty) {
            return 'Command is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _label(context, 'Arguments'),
      _textField(
        context,
        controller: _argsController,
        hintText: 'One argument per line',
        maxLines: 4,
      ),
      const SizedBox(height: 20),
      _label(context, 'Environment Variables'),
      _textField(
        context,
        controller: _envController,
        hintText: 'KEY=value\nANOTHER_KEY=value',
        maxLines: 5,
      ),
      const SizedBox(height: 20),
    ];
  }

  Widget _buildTestResult(BuildContext context) {
    final success = _testSuccess == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: success
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _testMessage ?? '',
                  style: TextStyle(
                    color: success ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (success && _detectedTransport != null) ...[
            const SizedBox(height: 8),
            Text(
              'Protocol: ${_detectedTransport!.displayName}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
          if (success && _availableTools != null && _availableTools!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tools: ${_availableTools!.take(3).join(", ")}${_availableTools!.length > 3 ? "..." : ""}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
          if (success && _serverType == _McpServerFormType.stdio) ...[
            const SizedBox(height: 8),
            Text(
              'Tools will be discovered after the STDIO server starts successfully.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.tertiary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Custom MCP servers introduce risk. Review server commands, remote URLs, and exposed tools before enabling them.',
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _textField(
    BuildContext context, {
    required TextEditingController controller,
    String? hintText,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      validator: validator,
      maxLines: maxLines,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdownField<T>(
    BuildContext context, {
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  List<String> _parseArgs() {
    return _argsController.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, String> _parseEnv() {
    final env = <String, String>{};
    for (final line in _envController.text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final separator = trimmed.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final key = trimmed.substring(0, separator).trim();
      final value = trimmed.substring(separator + 1).trim();
      if (key.isNotEmpty) {
        env[key] = value;
      }
    }
    return env;
  }

  String? _trimOrNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
