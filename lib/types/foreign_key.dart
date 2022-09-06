import 'reference.dart';

class ForeignKey {
  final String? parent;
  final Reference? reference;

  const ForeignKey({this.parent, this.reference});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForeignKey &&
          runtimeType == other.runtimeType &&
          parent == other.parent &&
          reference == other.reference;

  @override
  int get hashCode => parent.hashCode ^ reference.hashCode;

  @override
  String toString() {
    return 'ForeignKey(parent: $parent, reference: $reference)';
  }
}
