import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';
import 'package:sanad_client/features/provider_setup/data/models/model_cache_snapshot_dto.dart';
import 'package:sanad_client/features/provider_setup/data/models/model_options_dto.dart';
import 'package:sanad_client/features/provider_setup/data/models/provider_model_group_dto.dart';
import 'package:sanad_client/features/provider_setup/data/provider_setup_client.dart';

/// Hierarchical provider→models state for the model picker dialog.
class ProviderRuntimeState extends Equatable {
  final String? activeProviderId;
  final String? activeModel;
  final List<ProviderModelGroupDto> groups;
  final List<RecentModelDto> recent;
  final bool loading;

  /// True while a background live-fetch is in progress (groups already shown).
  final bool isRefreshing;
  final String? error;

  const ProviderRuntimeState({
    this.activeProviderId,
    this.activeModel,
    this.groups = const [],
    this.recent = const [],
    this.loading = false,
    this.isRefreshing = false,
    this.error,
  });

  ProviderRuntimeState copyWith({
    String? activeProviderId,
    String? activeModel,
    List<ProviderModelGroupDto>? groups,
    List<RecentModelDto>? recent,
    bool? loading,
    bool? isRefreshing,
    String? error,
  }) {
    return ProviderRuntimeState(
      activeProviderId: activeProviderId ?? this.activeProviderId,
      activeModel: activeModel ?? this.activeModel,
      groups: groups ?? this.groups,
      recent: recent ?? this.recent,
      loading: loading ?? this.loading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }

  @override
  List<Object?> get props => [activeProviderId, activeModel, groups, recent, loading, isRefreshing, error];
}

/// Owns the hierarchical provider→models list for the model picker.
///
/// Uses a **stale-while-revalidate** strategy via the new Plan 29 model cache:
/// 1. Immediately fetches [modelSnapshot] → instant render from cache, no spinner.
/// 2. Silently refreshes each instance group in the background → pushes updates
///    via [isRefreshing].
/// 3. Loads [modelRecentList] for the "Recently Selected" section.
///
/// Listens to `capabilities_changed` / `provider_instances_changed` events
/// and re-fetches.
class ProviderRuntimeCubit extends Cubit<ProviderRuntimeState> {
  final ProviderSetupClient _client;
  final DeviceConfig? _agent;
  final Stream<void>? _capabilitiesChangedTrigger;
  StreamSubscription? _capSub;

  ProviderRuntimeCubit({
    required ProviderSetupClient client,
    DeviceConfig? agent,
    Stream<void>? capabilitiesChangedTrigger,
  }) : _client = client,
       _agent = agent,
       _capabilitiesChangedTrigger = capabilitiesChangedTrigger,
       super(const ProviderRuntimeState(loading: true)) {
    unawaited(_loadStaleWhileRevalidate());
    _capSub = _capabilitiesChangedTrigger?.listen((_) => unawaited(_loadStaleWhileRevalidate()));
  }

  /// Stale-while-revalidate: loads cached snapshot instantly, then refreshes
  /// each instance group in the background.
  Future<void> _loadStaleWhileRevalidate() async {
    // Step 1 — instant: load cached snapshot and recent list with no spinner.
    await _loadSnapshot();

    // Step 2 — background: silently refresh all instances and update UI.
    if (!isClosed) {
      await _refreshAll();
    }
  }

  Future<void> _loadSnapshot() async {
    if (isClosed) return;
    emit(state.copyWith(loading: true, error: null));

    try {
      final results = await Future.wait([
        _client.modelSnapshot(agent: _agent),
        _client.modelRecentList(agent: _agent),
      ]);
      final snapshot = results[0] as ModelCacheSnapshotDto;
      final recent = results[1] as List<RecentModelDto>;

      if (!isClosed) {
        emit(
          state.copyWith(
            groups: _buildGroups(snapshot),
            recent: recent,
            loading: false,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            loading: false,
            // Only show error if cache is empty (first-ever load).
            error: state.groups.isEmpty ? e.toString() : null,
          ),
        );
      }
    }
  }

  Future<void> _refreshAll({bool manual = false}) async {
    if (isClosed) return;
    emit(state.copyWith(isRefreshing: true, error: null));

    try {
      // Refresh all instances that have cached models.
      final snapshot = await _client.modelSnapshot(agent: _agent);
      for (final inst in snapshot.instances) {
        if (!isClosed) {
          try {
            await _client.modelRefresh(
              providerInstanceId: inst.id,
              manual: manual,
              agent: _agent,
            );
          } catch (_) {
            // Individual refresh failure is non-fatal; keep cached data.
          }
        }
      }

      if (!isClosed) {
        final fresh = await Future.wait([
          _client.modelSnapshot(agent: _agent),
          _client.modelRecentList(agent: _agent),
        ]);
        final snapshot = fresh[0] as ModelCacheSnapshotDto;
        final recent = fresh[1] as List<RecentModelDto>;

        emit(
          state.copyWith(
            groups: _buildGroups(snapshot),
            recent: recent,
            isRefreshing: false,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isRefreshing: false,
            error: state.groups.isEmpty ? e.toString() : null,
          ),
        );
      }
    }
  }

  List<ProviderModelGroupDto> _buildGroups(ModelCacheSnapshotDto snapshot) {
    return snapshot.instances.map((inst) {
      // runtimeReady reflects whether the instance is actually usable
      // (status == 'ready'), NOT whether it is the default. Using isDefault
      // here wrongly marked ready non-default instances with an error badge
      // (Plan 29 §6.3 / criterion 10).
      return ProviderModelGroupDto(
        providerId: inst.id,
        displayName: inst.displayName,
        runtimeReady: inst.status == 'ready',
        models: ModelOptionsDto(
          providerId: inst.id,
          models: inst.models.map((m) => m.id).toList(),
          selectedModel: inst.defaultModel,
          authenticated: true,
          authType: 'api_key',
          source: inst.cacheStatus == 'fetched' ? 'cache' : 'empty',
          warning: inst.warning,
        ),
      );
    }).toList();
  }

  /// Explicit user-triggered refresh: re-fetches the live model list without
  /// hiding the existing list. Uses `manual: true` to bypass cooldown and
  /// force a fresh provider fetch when the user asks for updated catalogs.
  Future<void> refreshModels() => _refreshAll(manual: true);

  /// Updates the active provider/model display (from session selection).
  void setActiveSelection({String? providerId, String? model}) {
    emit(state.copyWith(activeProviderId: providerId, activeModel: model));
  }

  @override
  Future<void> close() async {
    await _capSub?.cancel();
    return super.close();
  }
}
