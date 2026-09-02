import '../models/song.dart';
import '../providers/library_provider.dart';

String? resolveAlbumCoverArt(LibraryProvider? library, Song song) {
  if (song.albumId != null && song.albumId!.isNotEmpty && library != null) {
    for (final album in library.cachedAllAlbums) {
      if (album.id == song.albumId && album.coverArt?.isNotEmpty == true) {
        return album.coverArt;
      }
    }
  }
  return song.coverArt;
}
