import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tsiwa_mahber/core/constants/app_constants.dart';
import 'package:tsiwa_mahber/core/constants/firestore_paths.dart';
import 'package:tsiwa_mahber/features/area/domain/area.dart';

class AreaRepository {
  final FirebaseFirestore _firestore;

  AreaRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<Area?> watchArea(String areaId) {
    return _firestore
        .doc(FirestorePaths.area(areaId))
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Area.fromDoc(doc);
    });
  }

  /// Active (non-deleted) areas, ordered by name.
  /// Filters client-side to avoid requiring a composite index.
  Stream<List<Area>> watchAllAreas() {
    return _firestore
        .collection(FirestorePaths.areas())
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Area.fromDoc(doc))
            .where((area) => !area.isDeleted)
            .toList());
  }

  /// Soft-deleted areas (trash).
  Stream<List<Area>> watchDeletedAreas() {
    return _firestore
        .collection(FirestorePaths.areas())
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Area.fromDoc(doc))
            .where((area) => area.isDeleted)
            .toList());
  }

  Future<String?> ensureDefaultArea() async {
    try {
      final docRef = _firestore.doc(
        FirestorePaths.area(AppConstants.defaultAreaId),
      );
      final doc = await docRef.get();
      if (!doc.exists) {
        const defaultArea = Area(
          id: '',
          name: AppConstants.defaultAreaName,
          shortName: AppConstants.defaultAreaShortName,
          location: AppConstants.defaultAreaLocation,
          description: AppConstants.defaultAreaDescription,
        );
        await docRef.set(defaultArea.toCreateMap());
      }
      return null;
    } on FirebaseException catch (e) {
      return 'Firebase error: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> createArea(Area area) async {
    final docRef = await _firestore
        .collection(FirestorePaths.areas())
        .add(area.toCreateMap());
    return docRef.id;
  }

  Future<void> updateArea(Area area) async {
    await _firestore
        .doc(FirestorePaths.area(area.id))
        .update(area.toUpdateMap());
  }

  Future<void> hideArea(String areaId, bool hidden) async {
    await _firestore.doc(FirestorePaths.area(areaId)).update({
      'isHidden': hidden,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Soft-delete: move to trash by setting deletedAt.
  Future<void> softDeleteArea(String areaId, String deletedBy) async {
    await _firestore.doc(FirestorePaths.area(areaId)).update({
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': deletedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Restore from trash.
  Future<void> restoreArea(String areaId) async {
    await _firestore.doc(FirestorePaths.area(areaId)).update({
      'deletedAt': null,
      'deletedBy': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently delete.
  Future<void> deleteArea(String areaId) async {
    await _firestore.doc(FirestorePaths.area(areaId)).delete();
  }
}
