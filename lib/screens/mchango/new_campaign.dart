
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messaging/cubit/mchango_cubit.dart';
import 'package:messaging/models/mchango_campaign.dart';


class NewCampaignSheet extends StatefulWidget {
  final Campaign? toEdit;
  const NewCampaignSheet({super.key, this.toEdit});
  @override
  State<NewCampaignSheet> createState() => _NewCampaignSheetState();
}

class _NewCampaignSheetState extends State<NewCampaignSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  bool _hasTarget = false;
  bool _hasEndDate = false;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    if (widget.toEdit != null) {
      final c = widget.toEdit!;
      _nameController.text = c.name;
      if (c.targetAmount != null) {
        _hasTarget = true;
        _targetController.text = c.targetAmount.toString();
      }
      if (c.endDate != null) {
        _hasEndDate = true;
        _endDate = DateTime.fromMillisecondsSinceEpoch(c.endDate!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
        
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text( widget.toEdit == null ? 'New Campaign' : 'Edit Campaign',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                          IconButton(onPressed: (){
                            Navigator.pop(context);
                          }, icon: const Icon(Icons.close))
                ],
              ),
              const SizedBox(height: 20),
        
              // Campaign name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Campaign Name',
                  hintText: 'e.g. Wedding for John & Mary',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
        
              // Target amount toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set Target Amount'),
                subtitle: const Text('Track progress towards a goal and be notified when it is reached'),
                value: _hasTarget,
                onChanged: (v) => setState(() => _hasTarget = v),
              ),
              if (_hasTarget) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _targetController,
                  decoration: const InputDecoration(
                   hintText: "Enter target amount",
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  
                  validator: (v) {
                    if (!_hasTarget) return null;
                    if (v == null || v.isEmpty) return 'Enter target amount';
                    if (double.tryParse(v) == null) return 'Invalid amount';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 8),
        
              // End date toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set End Date'),
                subtitle: const Text('Campaign runs indefinitely by default'),
                value: _hasEndDate,
                onChanged: (v) => setState(() => _hasEndDate = v),
              ),
              if (_hasEndDate) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(_endDate == null
                      ? 'Select end date'
                      : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
              ],
        
              const Spacer(),
        
              // Submit
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child:  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(widget.toEdit == null ? 'Start Campaign' : 'Update Campaign'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hasEndDate && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an end date')),
      );
      return;
    }
    if (widget.toEdit != null){
      await _updateCampaign(widget.toEdit!.id!);
    } else {
      await _createCampaign();
    }


  }
  Future<void> _createCampaign() async {

    Navigator.pop(context);
    context.read<MchangoCubit>().startCampaign(
      name: _nameController.text.trim(),
      targetAmount: _hasTarget
          ? double.tryParse(_targetController.text)
          : null,
      endDate: _hasEndDate
          ? _endDate?.millisecondsSinceEpoch
          : null,
      openingBalance: 0,
    );
  }
  Future<void> _updateCampaign(int campaignId) async {

    Navigator.pop(context);
    context.read<MchangoCubit>().updateCampaign(
      campaignId: campaignId,
      name: _nameController.text.trim(),
      targetAmount: _hasTarget
          ? double.tryParse(_targetController.text)
          : null,
      clearTargetAmount: !_hasTarget,
      endDate: _hasEndDate
          ? _endDate?.millisecondsSinceEpoch
          : null,
      clearEndDate: !_hasEndDate,
    );
  }
}

