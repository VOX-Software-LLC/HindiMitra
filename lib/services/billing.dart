/// services/billing/skus.ts — pricing catalog.
class PlanDescriptor {
  final String id, tier, cycle, priceLabel, cycleLabel;
  final String? savings;
  final bool popular;
  final int? maxChildren, maxStudents;
  const PlanDescriptor(this.id, this.tier, this.cycle, this.priceLabel, this.cycleLabel,
      {this.savings, this.popular = false, this.maxChildren, this.maxStudents});
}

const plans = <PlanDescriptor>[
  PlanDescriptor('individual_monthly', 'individual', 'monthly', '\$4.99', 'per month', maxChildren: 1),
  PlanDescriptor('individual_yearly', 'individual', 'yearly', '\$39.99', 'per year', savings: 'Save 33%', popular: true, maxChildren: 1),
  PlanDescriptor('family_monthly', 'family', 'monthly', '\$7.99', 'per month', maxChildren: 2),
  PlanDescriptor('family_yearly', 'family', 'yearly', '\$59.99', 'per year', savings: 'Save 38%', maxChildren: 2),
  PlanDescriptor('teacher_monthly', 'teacher', 'monthly', '\$9.99', 'per month', maxStudents: 30),
  PlanDescriptor('teacher_yearly', 'teacher', 'yearly', '\$79.99', 'per year', savings: 'Save 33%', popular: true, maxStudents: 30),
];

List<PlanDescriptor> plansForTier(String tier) => plans.where((p) => p.tier == tier).toList();

class PurchaseResult {
  final bool ok; final String? message;
  const PurchaseResult(this.ok, [this.message]);
}
