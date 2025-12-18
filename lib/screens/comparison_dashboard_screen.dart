import 'package:flutter/material.dart';

import '../models/vehicle_comparison.dart';
import '../services/vehicle_comparison_service.dart';
import '../widgets/comparison_header_card.dart';
import '../widgets/ev_vs_petrol_card.dart';
import '../widgets/recommendations_card.dart';
import '../widgets/vehicle_comparison_card.dart';

class ComparisonDashboardScreen extends StatefulWidget {
  const ComparisonDashboardScreen({super.key});

  @override
  State<ComparisonDashboardScreen> createState() =>
      _ComparisonDashboardScreenState();
}

class _ComparisonDashboardScreenState extends State<ComparisonDashboardScreen> {
  final _comparisonService = VehicleComparisonService.instance;

  ComparisonPeriod _selectedPeriod = ComparisonPeriod.thisMonth;
  bool _isLoading = true;
  FamilyComparison? _comparison;
  List<VehicleRecommendation>? _recommendations;
  EVvsPetrolComparison? _evComparison;

  @override
  void initState() {
    super.initState();
    _loadComparison();
  }

  Future<void> _loadComparison() async {
    setState(() => _isLoading = true);

    try {
      final comparison =
          await _comparisonService.getFamilyComparison(_selectedPeriod);
      List<VehicleRecommendation> recommendations =
          const <VehicleRecommendation>[];
      EVvsPetrolComparison? evComparison;

      if (comparison.vehicles.isNotEmpty) {
        recommendations =
            await _comparisonService.generateRecommendations(comparison);
        evComparison =
            await _comparisonService.getEVvsPetrolComparison(comparison);
      }

      setState(() {
        _comparison = comparison;
        _recommendations = recommendations;
        _evComparison = evComparison;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading comparison: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Comparison'),
        actions: [
          // Period selector dropdown
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<ComparisonPeriod>(
              value: _selectedPeriod,
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              dropdownColor: Theme.of(context).primaryColor,
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              onChanged: (period) {
                if (period != null) {
                  setState(() => _selectedPeriod = period);
                  _loadComparison();
                }
              },
              items: ComparisonPeriod.values.map((period) {
                return DropdownMenuItem(
                  value: period,
                  child: Text(_getPeriodLabel(period)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _comparison == null || _comparison!.vehicles.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadComparison,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Family Summary Card
                        ComparisonHeaderCard(comparison: _comparison!),
                        const SizedBox(height: 24),

                        // Winner Badge
                        if (_comparison!.vehicles.isNotEmpty)
                          _buildWinnerBadge(),
                        const SizedBox(height: 24),

                        // Side-by-Side Comparison
                        _buildSideBySideComparison(),
                        const SizedBox(height: 24),

                        // EV vs Petrol Comparison
                        if (_evComparison != null) ...[
                          EVvsPetrolCard(comparison: _evComparison!),
                          const SizedBox(height: 24),
                        ],

                        // Recommendations
                        if (_recommendations != null &&
                            _recommendations!.isNotEmpty) ...[
                          RecommendationsCard(
                            recommendations: _recommendations!,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // What-If Scenarios Button
                        _buildWhatIfButton(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compare_arrows, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Data Available',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add some expenses to see vehicle comparisons',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerBadge() {
    final winner = _comparison!.mostEconomical;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MOST ECONOMICAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  winner.vehicle.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${winner.costPerKm.toStringAsFixed(2)}/km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (winner.isElectric)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'EV',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideBySideComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Side-by-Side Comparison',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        // Horizontal scrolling for 3+ vehicles
        if (_comparison!.vehicles.length > 2)
          SizedBox(
            height: 380,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _comparison!.vehicles.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < _comparison!.vehicles.length - 1 ? 12 : 0,
                  ),
                  child: SizedBox(
                    width: 280,
                    child: VehicleComparisonCard(
                      comparison: _comparison!.vehicles[index],
                      isWinner: _comparison!.vehicles[index] ==
                          _comparison!.mostEconomical,
                    ),
                  ),
                );
              },
            ),
          )
        else
          // Grid layout for 1-2 vehicles
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _comparison!.vehicles.length == 1 ? 1 : 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _comparison!.vehicles.length,
            itemBuilder: (context, index) {
              return VehicleComparisonCard(
                comparison: _comparison!.vehicles[index],
                isWinner:
                    _comparison!.vehicles[index] == _comparison!.mostEconomical,
              );
            },
          ),
      ],
    );
  }

  Widget _buildWhatIfButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // TODO: Navigate to What-If Scenarios screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('What-If Scenarios coming soon!')),
          );
        },
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('What-If Scenarios'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  String _getPeriodLabel(ComparisonPeriod period) {
    switch (period) {
      case ComparisonPeriod.thisMonth:
        return 'This Month';
      case ComparisonPeriod.last3Months:
        return 'Last 3 Months';
      case ComparisonPeriod.last6Months:
        return 'Last 6 Months';
      case ComparisonPeriod.thisYear:
        return 'This Year';
      case ComparisonPeriod.allTime:
        return 'All Time';
    }
  }
}
