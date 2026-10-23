/// `num.clamp` returns `num`; these keep the static type precise.
extension NumClampExt on num {
  double clampD(double lo, double hi) => this < lo ? lo : (this > hi ? hi : toDouble());
  int clampI(int lo, int hi) => this < lo ? lo : (this > hi ? hi : toInt());
}
