extension BoolExtension on bool {
  int? toInt() => this != null ? (this ? 1 : 0) : null;
}
