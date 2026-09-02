import 'package:flutter_test/flutter_test.dart';
import 'package:musly/widgets/common/album_artwork.dart';

void main() {
  test('uses physical-pixel buckets for artwork decoding', () {
    expect(resolveArtworkCacheSize(44, 3), 256);
    expect(resolveArtworkCacheSize(180, 2), 512);
    expect(resolveArtworkCacheSize(260, 3), 1024);
    expect(resolveArtworkCacheSize(600, 3), 1200);
  });
}
