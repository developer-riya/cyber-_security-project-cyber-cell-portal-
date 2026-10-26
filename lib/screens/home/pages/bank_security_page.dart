import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/cyber_design_system.dart';
import '../../../services/firebase_service.dart';
import '../../../services/localization_service.dart';

class BankSecurityPage extends StatefulWidget {
  const BankSecurityPage({super.key, this.permissionStream});

  final Stream<DocumentSnapshot<Map<String, dynamic>>>? permissionStream;

  @override
  State<BankSecurityPage> createState() => _BankSecurityPageState();
}

class _BankSecurityPageState extends State<BankSecurityPage> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _permissionStream;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _permissionStream =
        widget.permissionStream ??
        FirebaseService.instance.getUserBankPermission();
  }

  Future<void> _savePermissionRequest() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseService.instance.connectBankPermission({
        'platform': Theme.of(context).platform.toString(),
        'context': 'Citizen Bank Security Service',
        'permissionSource': 'Bank Security Service',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translate(
                'bank_security_permission_saved_message',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translate(
                'bank_security_permission_failed',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: CyberSpacing.pagePadding,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: CyberDimensions.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocalizationService.instance.translate('bank_security_title'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              CyberSpacing.vertical(CyberSpacing.xs),
              Text(
                LocalizationService.instance.translate('bank_security_intro'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              CyberSpacing.vertical(CyberSpacing.xl),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _permissionStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CyberCard(
                      child: Row(
                        children: [
                          const SizedBox(
                            width: CyberDimensions.iconMedium,
                            height: CyberDimensions.iconMedium,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          CyberSpacing.horizontal(CyberSpacing.sm),
                          Expanded(
                            child: Text(
                              LocalizationService.instance.translate(
                                'bank_security_loading',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final bool permissionSaved = snapshot.data?.exists == true;
                  final bool hasError = snapshot.hasError;
                  return _PermissionCard(
                    permissionSaved: permissionSaved,
                    hasError: hasError,
                    isSaving: _isSaving,
                    onRequest: _savePermissionRequest,
                  );
                },
              ),
              CyberSpacing.vertical(CyberSpacing.xl),
              CyberCard(
                variant: CyberCardVariant.status,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    CyberSpacing.vertical(CyberSpacing.sm),
                    Text(
                      LocalizationService.instance.translate(
                        'bank_security_credentials_note',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.permissionSaved,
    required this.hasError,
    required this.isSaving,
    required this.onRequest,
  });

  final bool permissionSaved;
  final bool hasError;
  final bool isSaving;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String title = hasError
        ? LocalizationService.instance.translate('bank_security_load_failed')
        : permissionSaved
        ? LocalizationService.instance.translate(
            'bank_security_permission_title',
          )
        : LocalizationService.instance.translate(
            'bank_security_permission_none',
          );
    final String action = permissionSaved
        ? LocalizationService.instance.translate('bank_security_update')
        : LocalizationService.instance.translate('bank_security_request');

    return CyberCard(
      variant: CyberCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: CyberRadius.standardRadius,
                ),
                child: Icon(
                  Icons.account_balance_outlined,
                  color: theme.colorScheme.secondary,
                ),
              ),
              CyberSpacing.horizontal(CyberSpacing.md),
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            ],
          ),
          CyberSpacing.vertical(CyberSpacing.sm),
          Text(
            hasError
                ? LocalizationService.instance.translate(
                    'bank_security_load_failed_description',
                  )
                : LocalizationService.instance.translate(
                    'bank_security_permission_description',
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          CyberSpacing.vertical(CyberSpacing.md),
          CyberButton(
            label: action,
            icon: const Icon(Icons.arrow_forward_rounded),
            isLoading: isSaving,
            onPressed: onRequest,
          ),
        ],
      ),
    );
  }
}
