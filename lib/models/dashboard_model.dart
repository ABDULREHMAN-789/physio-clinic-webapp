class DashboardModel {
  final int totalPatients;
  final int totalSessions;
  final double pendingDues;
  final double totalEarnings;
  final List<RevenueDataPoint> revenueChartData;

  DashboardModel({
    required this.totalPatients,
    required this.totalSessions,
    required this.pendingDues,
    required this.totalEarnings,
    required this.revenueChartData,
  });

  factory DashboardModel.empty() {
    return DashboardModel(
      totalPatients: 0,
      totalSessions: 0,
      pendingDues: 0.0,
      totalEarnings: 0.0,
      revenueChartData: [],
    );
  }
}

class RevenueDataPoint {
  final String label; // E.g., 'Jan', 'Feb', 'Mar'
  final double earnings;

  RevenueDataPoint({
    required this.label,
    required this.earnings,
  });
}
