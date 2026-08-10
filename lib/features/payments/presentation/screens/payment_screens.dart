import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/models/payment_models.dart';

class InvoiceListWidget extends StatelessWidget {
  final List<Invoice> invoices;
  final bool isLoading;
  final ValueChanged<Invoice>? onInvoiceSelected;

  const InvoiceListWidget({
    super.key,
    required this.invoices,
    this.isLoading = false,
    this.onInvoiceSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (invoices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.tr('No invoices issued.')),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final inv = invoices[index];
        final isPaid = inv.status == 'paid';
        final isOverdue = inv.status == 'overdue';

        return Card(
          child: ListTile(
            leading: Icon(
              isPaid
                  ? Icons.check_circle
                  : (isOverdue ? Icons.warning : Icons.receipt_long),
              color: isPaid
                  ? Colors.green
                  : (isOverdue ? Colors.red : Colors.orange),
              size: 36,
            ),
            title: Text(
              '${context.tr('Invoice')} ${inv.invoiceNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${context.tr('Total')}: ${inv.totalMinor / 100.0} ${inv.currency} | ${context.tr('Paid')}: ${inv.amountPaidMinor / 100.0} ${inv.currency}\n${context.tr('Status')}: ${context.l10n.t(inv.status).toUpperCase()}',
            ),
            trailing: isPaid
                ? Chip(
                    label: Text(context.tr('PAID')),
                    backgroundColor: Colors.greenAccent,
                  )
                : ElevatedButton(
                    onPressed: onInvoiceSelected != null
                        ? () => onInvoiceSelected!(inv)
                        : null,
                    child: Text(context.tr('Record Cash')),
                  ),
          ),
        );
      },
    );
  }
}

class FinancialSummaryWidget extends StatelessWidget {
  final FinancialSummary summary;

  const FinancialSummaryWidget({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Financial Summary'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge(
                  context.tr('Total Due'),
                  '${summary.totalDueMinor / 100.0} ${summary.currency}',
                  Colors.black,
                ),
                _buildStatBadge(
                  context.tr('Total Paid'),
                  '${summary.totalPaidMinor / 100.0} ${summary.currency}',
                  Colors.green,
                ),
                _buildStatBadge(
                  context.tr('Balance'),
                  '${summary.remainingBalanceMinor / 100.0} ${summary.currency}',
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
