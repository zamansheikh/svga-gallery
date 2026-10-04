import 'package:flutter_test/flutter_test.dart';
import 'package:svga_gallery/data/library_store.dart';
import 'package:svga_gallery/models/svga_item.dart';

void main() {
  test('SvgaItem survives a JSON round trip', () {
    final item = SvgaItem(
      id: '1',
      name: 'angel',
      fileName: '1.svga',
      bytes: 214571,
      addedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      favorite: true,
      source: 'https://example.com/angel.svga',
      width: 750,
      height: 750,
      fps: 20,
      frames: 50,
    );
    final copy = SvgaItem.fromJson(item.toJson());
    expect(copy.toJson(), item.toJson());
    expect(copy.duration, const Duration(milliseconds: 2500));
  });

  test('formatters', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(214571), '210 KB');
    expect(formatBytes(3 * 1024 * 1024), '3.0 MB');
    expect(formatSeconds(const Duration(milliseconds: 2500)), '2.5s');
  });

  test('ImportResult sums and describes itself', () {
    final result =
        const ImportResult(added: 2) +
        const ImportResult(duplicates: 1) +
        const ImportResult(failed: 1);
    expect(
      result.message,
      'Added 2 animations · 1 already in gallery · 1 not a valid SVGA 2.x file',
    );
    expect(const ImportResult().message, 'Nothing to import');
  });
}
