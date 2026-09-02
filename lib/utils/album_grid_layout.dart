import 'package:flutter/material.dart';

import '../services/player_ui_settings_service.dart';

class AlbumGridLayout {
  const AlbumGridLayout._();

  static int columnsForWidth(double width, String size) {
    final large = size == 'large';
    if (width > 1200) return large ? 5 : 6;
    if (width > 900) return large ? 4 : 5;
    if (width > 600) return large ? 3 : 4;
    return large ? 2 : 3;
  }

  static int columns(BuildContext context, double width) => columnsForWidth(
        width,
        PlayerUiSettingsService().getAlbumGridSize(),
      );
}
