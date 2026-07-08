import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sorisdk_flutter/sorisdk_flutter.dart';

void main() {
  runApp(const SoriExampleApp());
}

class SoriExampleApp extends StatelessWidget {
  const SoriExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SORI Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const RecognitionHome(),
    );
  }
}

class RecognitionHome extends StatefulWidget {
  const RecognitionHome({super.key});

  @override
  State<RecognitionHome> createState() => _RecognitionHomeState();
}

class _RecognitionHomeState extends State<RecognitionHome> {
  static const _applicationId = String.fromEnvironment('SORI_APP_ID');
  static const _secretKey = String.fromEnvironment('SORI_SECRET_KEY');

  late final SORIAudioRecognizer _recognizer;
  late final StreamSubscription<SORIRecognitionEvent> _subscription;

  final _campaigns = <SORICampaign>[];
  var _isStarting = false;
  var _isRunning = false;
  var _isUpdating = false;
  var _status = 'Stopped';
  String? _message;
  String? _marker;

  bool get _hasCredentials =>
      _applicationId.isNotEmpty && _secretKey.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _recognizer = SORIAudioRecognizer(
      applicationId: _applicationId,
      secretKey: _secretKey,
    );
    _subscription = _recognizer.events.listen(
      _handleRecognitionEvent,
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() => _message = error.toString());
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _handleRecognitionEvent(SORIRecognitionEvent event) {
    if (!mounted) {
      return;
    }

    setState(() {
      if (event.type == SORIRecognitionEventType.stateChanged) {
        _applyNativeState(event.payload['state']?.toString());
      }

      final campaign = _campaignFromEvent(event);
      if (campaign != null) {
        _campaigns.insert(0, campaign);
        _message = null;
      }

      if (event.audioMarker != null ||
          event.type == SORIRecognitionEventType.audioMarkerChanged) {
        _marker = event.audioMarker;
      }

      if (event.type == SORIRecognitionEventType.error ||
          event.type == SORIRecognitionEventType.networkError) {
        _message = event.message ?? 'Recognition failed.';
      }
    });
  }

  void _applyNativeState(String? state) {
    switch (state) {
      case 'STARTING':
        _isStarting = true;
        _isRunning = true;
        _status = 'Starting';
        break;
      case 'STARTED':
        _isStarting = false;
        _isRunning = true;
        _status = 'Listening';
        break;
      default:
        _isStarting = false;
        _isRunning = false;
        _status = 'Stopped';
        break;
    }
  }

  Future<void> _toggleRecognition() async {
    if (!_hasCredentials || _isStarting) {
      setState(() => _message = 'Missing SORI_APP_ID or SORI_SECRET_KEY.');
      return;
    }

    if (_isRunning) {
      await _recognizer.stopRecognition();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRunning = false;
        _isStarting = false;
        _status = 'Stopped';
      });
      return;
    }

    setState(() {
      _isStarting = true;
      _status = 'Starting';
      _message = null;
    });

    try {
      await _recognizer.configure();
      await _recognizer.startRecognition(
        notification: const SORIAndroidNotificationOptions(
          title: 'SORI recognition',
          body: 'Listening for SORI audio signals',
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isStarting = false;
        _isRunning = true;
        _status = 'Listening';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isStarting = false;
        _isRunning = false;
        _status = 'Stopped';
        _message = error.message ?? error.code;
      });
    }
  }

  Future<void> _updateDatabase() async {
    if (!_hasCredentials || _isUpdating) {
      setState(() => _message = 'Missing SORI_APP_ID or SORI_SECRET_KEY.');
      return;
    }

    setState(() {
      _isUpdating = true;
      _message = null;
    });

    try {
      final result = await _recognizer.updateDatabase();
      if (!mounted) {
        return;
      }
      setState(() {
        _isUpdating = false;
        _message = result.success
            ? 'Recognition database is ready: ${result.currentVersion}'
            : result.errorMessage ?? 'Database update failed.';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isUpdating = false;
        _message = error.message ?? error.code;
      });
    }
  }

  Future<void> _openCampaign(SORICampaign campaign) async {
    final actionUrl = campaign.actionUrl;
    if (actionUrl == null || actionUrl.isEmpty) {
      return;
    }

    try {
      await _recognizer.handleActionUrl(actionUrl);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? error.code)));
    }
  }

  SORICampaign? _campaignFromEvent(SORIRecognitionEvent event) {
    if (event.campaign != null) {
      return event.campaign;
    }

    final payloadCampaign = stringKeyedMap(event.payload['campaign']);
    if (payloadCampaign != null) {
      return SORICampaign.fromMap(payloadCampaign);
    }

    if (event.type == SORIRecognitionEventType.campaignFound ||
        event.type == SORIRecognitionEventType.recognitionResult) {
      final campaign = SORICampaign.fromMap(event.payload);
      if (campaign.id.isNotEmpty || campaign.name.isNotEmpty) {
        return campaign;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SORI Example'),
        actions: [
          IconButton(
            onPressed: _hasCredentials && !_isUpdating ? _updateDatabase : null,
            tooltip: 'Update database',
            icon: _isUpdating
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        children: [
          StatusPanel(
            status: _status,
            message: _message,
            marker: _marker,
            hasCredentials: _hasCredentials,
          ),
          Expanded(
            child: CampaignTimeline(
              campaigns: _campaigns,
              onTapCampaign: _openCampaign,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _hasCredentials && !_isStarting ? _toggleRecognition : null,
        tooltip: _isRunning ? 'Stop recognition' : 'Start recognition',
        child: Icon(_isRunning ? Icons.mic_off : Icons.mic),
      ),
    );
  }
}

class StatusPanel extends StatelessWidget {
  const StatusPanel({
    required this.status,
    required this.hasCredentials,
    this.message,
    this.marker,
    super.key,
  });

  final String status;
  final String? message;
  final String? marker;
  final bool hasCredentials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveMessage = hasCredentials
        ? message
        : 'Run with SORI_APP_ID and SORI_SECRET_KEY.';

    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                status == 'Listening' ? Icons.graphic_eq : Icons.hearing,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (effectiveMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        effectiveMessage,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (marker != null && marker!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Marker $marker',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CampaignTimeline extends StatelessWidget {
  const CampaignTimeline({
    required this.campaigns,
    required this.onTapCampaign,
    super.key,
  });

  final List<SORICampaign> campaigns;
  final ValueChanged<SORICampaign> onTapCampaign;

  @override
  Widget build(BuildContext context) {
    if (campaigns.isEmpty) {
      return const EmptyCampaignState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: campaigns.length,
      itemBuilder: (context, index) {
        final campaign = campaigns[index];
        return CampaignCard(
          campaign: campaign,
          onTap: () => onTapCampaign(campaign),
        );
      },
    );
  }
}

class EmptyCampaignState extends StatelessWidget {
  const EmptyCampaignState({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, color: scheme.outline, size: 44),
            const SizedBox(height: 12),
            Text(
              'No recognized campaigns yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class CampaignCard extends StatelessWidget {
  const CampaignCard({required this.campaign, required this.onTap, super.key});

  final SORICampaign campaign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actionUrl = campaign.actionUrl;
    final marker = campaign.trait?.marker;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: actionUrl == null || actionUrl.isEmpty ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CampaignImage(url: campaign.imageUrl),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CampaignText(campaign: campaign, marker: marker),
                  ),
                  if (actionUrl != null && actionUrl.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.open_in_new, size: 20),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CampaignText extends StatelessWidget {
  const CampaignText({required this.campaign, this.marker, super.key});

  final SORICampaign campaign;
  final String? marker;

  @override
  Widget build(BuildContext context) {
    final description = campaign.description;
    final title = campaign.name.isEmpty ? campaign.id : campaign.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.isEmpty ? 'Untitled campaign' : title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
        if (marker != null && marker!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Marker $marker'),
        ],
      ],
    );
  }
}

class CampaignImage extends StatelessWidget {
  const CampaignImage({required this.url, super.key});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: CampaignImagePlaceholder(icon: Icons.image_not_supported),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const CampaignImagePlaceholder(icon: Icons.broken_image);
        },
      ),
    );
  }
}

class CampaignImagePlaceholder extends StatelessWidget {
  const CampaignImagePlaceholder({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(icon, color: scheme.outline, size: 40),
    );
  }
}

Map<String, Object?>? stringKeyedMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}
