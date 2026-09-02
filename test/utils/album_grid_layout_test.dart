import 'package:flutter_test/flutter_test.dart';
import 'package:musly/utils/album_grid_layout.dart';

void main() {
  test('uses three columns for normal phone album grids', () {
    expect(AlbumGridLayout.columnsForWidth(390, 'normal'), 3);
  });

  test('uses two columns for large phone album grids', () {
    expect(AlbumGridLayout.columnsForWidth(390, 'large'), 2);
  });
}
