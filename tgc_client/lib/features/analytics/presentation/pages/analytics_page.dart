import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/ui/widgets/range_date_picker.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_bloc.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_event.dart';
import 'package:tgc_client/features/analytics/presentation/widgets/sales_analytics_tab.dart';
import 'package:tgc_client/features/analytics/presentation/widgets/production_analytics_tab.dart';
import 'package:tgc_client/features/analytics/presentation/widgets/financial_analytics_tab.dart';
import 'package:tgc_client/features/analytics/presentation/widgets/client_analytics_tab.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AnalyticsBloc>(),
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatefulWidget {
  const _AnalyticsView();

  @override
  State<_AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<_AnalyticsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _range = RangeDatePicker.currentMonth;
    _tabController.addListener(_onTabChanged);
    _loadCurrentTab();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadCurrentTab();
    }
  }

  void _loadCurrentTab() {
    final bloc = context.read<AnalyticsBloc>();
    switch (_tabController.index) {
      case 0:
        bloc.add(SalesAnalyticsRequested(from: _range.start, to: _range.end));
        break;
      case 1:
        bloc.add(ProductionAnalyticsRequested(from: _range.start, to: _range.end));
        break;
      case 2:
        bloc.add(FinancialAnalyticsRequested(from: _range.start, to: _range.end));
        break;
      case 3:
        bloc.add(ClientAnalyticsRequested(from: _range.start, to: _range.end));
        break;
    }
  }

  void _onRangeChanged(DateTimeRange range) {
    setState(() => _range = range);
    _loadCurrentTab();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analitika'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedDollarSquare),
              text: 'Savdo',
            ),
            Tab(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedSetup01),
              text: 'Ishlab chiqarish',
            ),
            Tab(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedBadgeDollarSign),
              text: 'Moliya',
            ),
            Tab(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedUserGroup),
              text: 'Mijozlar',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: RangeDatePicker(
              value: _range,
              onChanged: _onRangeChanged,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                SalesAnalyticsTab(),
                ProductionAnalyticsTab(),
                FinancialAnalyticsTab(),
                ClientAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
