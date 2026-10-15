//navigations
// ignore_for_file: constant_identifier_names, empty_catches

import 'package:audio_service/audio_service.dart';

import '/models/media_Item_builder.dart';
import '/services/utils.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';

const single_column = ['contents', 'singleColumnBrowseResultsRenderer'];
const tab_content = ['tabs', 0, 'tabRenderer', 'content'];
const List<dynamic> single_column_tab = [
  'contents',
  'singleColumnBrowseResultsRenderer',
  'tabs',
  0,
  'tabRenderer',
  'content'
];
const section_list = ['sectionListRenderer', 'contents'];
const description_shelf = ['musicDescriptionShelfRenderer'];
const run_text = ['runs', 0, 'text'];
const description = ['description', 'runs', 0, 'text'];
const carousel_title = [
  'header',
  'musicCarouselShelfBasicHeaderRenderer',
  'title',
  'runs',
  0
];
const mtrir = 'musicTwoRowItemRenderer';
const mrlir = 'musicResponsiveListItemRenderer';
const n_title = ['title', 'runs', 0]; //titile
const navigation_browse = ['navigationEndpoint', 'browseEndpoint'];
const page_type = [
  'browseEndpointContextSupportedConfigs',
  'browseEndpointContextMusicConfig',
  'pageType'
];
const navigation_watch_playlist_id = [
  'navigationEndpoint',
  'watchPlaylistEndpoint',
  'playlistId'
];
const audio_watch_playlist_id = [
  ...menu_items,
  0,
  'menuNavigationItemRenderer',
  ...navigation_watch_playlist_id
];
const title_text = ['title', 'runs', 0, 'text'];
const thumbnail_renderer = [
  'thumbnailRenderer',
  'musicThumbnailRenderer',
  'thumbnail',
  'thumbnails'
];
const navigation_playlist_id = [
  'navigationEndpoint',
  'watchEndpoint',
  'playlistId'
];
const navigation_video_id = ['navigationEndpoint', 'watchEndpoint', 'videoId'];
const subtitle2 = ['subtitle', 'runs', 2, 'text'];
const navigation_browse_id = [
  'navigationEndpoint',
  'browseEndpoint',
  'browseId'
];

const text_run_navigation_browse_id = [];

const subtitle_badge_label = [
  'subtitleBadges',
  0,
  'musicInlineBadgeRenderer',
  'accessibilityData',
  'accessibilityData',
  'label'
];
const text_run_text = ['text', 'runs', 0, 'text'];
const text_run = ['text', 'runs', 0];
const badge_label = [
  'badges',
  0,
  'musicInlineBadgeRenderer',
  'accessibilityData',
  'accessibilityData',
  'label'
];
const thumbnail = ['thumbnail', 'thumbnails'];
const thumbnails = [
  'thumbnail',
  'musicThumbnailRenderer',
  'thumbnail',
  'thumbnails'
];

const navigation_video_type = [
  'watchEndpoint',
  'watchEndpointMusicSupportedConfigs',
  'watchEndpointMusicConfig',
  'musicVideoType'
];
const toggle_menu = 'toggleMenuServiceItemRenderer';
const List<dynamic> menu_items = ['menu', 'menuRenderer', 'items'];
const menu_service = ['menuServiceItemRenderer', 'serviceEndpoint'];
const play_button = [
  'overlay',
  'musicItemThumbnailOverlayRenderer',
  'content',
  'musicPlayButtonRenderer'
];
const menu_like_status = [
  'menu',
  'menuRenderer',
  'topLevelButtons',
  0,
  'likeButtonRenderer',
  'likeStatus'
];
const List<dynamic> section_list_item = ['sectionListRenderer', 'contents', 0];
const List<dynamic> thumnail_cropped = [
  'thumbnail',
  'croppedSquareThumbnailRenderer',
  'thumbnail',
  'thumbnails'
];
const subtitle = ['subtitle', 'runs', 0, 'text'];
const subtitle3 = ['subtitle', 'runs', 4, 'text'];
const feedback_token = ['feedbackEndpoint', 'feedbackToken'];
const musicPlaylistShelfRenderer = [
  "contents",
  "twoColumnBrowseResultsRenderer",
  "secondaryContents",
  "sectionListRenderer",
  "contents",
  0,
  "musicPlaylistShelfRenderer",
];

List<Map<String, dynamic>> parseMixedContent(List<dynamic> rows) {
  List<Map<String, dynamic>> items = [];
  //inspect(rows);

  for (var row in rows) {
    dynamic title;
    dynamic contents = [];
    if (description_shelf[0] == row.keys.first.toString()) {
      var results = nav(row, description_shelf);
      title = nav(results, ['header', 'runs', 0, 'text']);
      contents = nav(results, description);
    } else {
      var results = row.values.first;
      if (!results.containsKey('contents')) {
        continue;
      }
      title = nav(results, carousel_title + ['text']);

      for (var result in results['contents']) {
        var data = nav(result, [mtrir]);
        dynamic content;
        if (data != null) {
          var pageType = nav(data, n_title + navigation_browse + page_type,
              noneIfAbsent: true, funName: "mixed1");
          if (pageType == null) {
            if (nav(data, navigation_watch_playlist_id) != null) {
              //  content = parseWatchPlaylistHome(data);
            } else {
              content = parseSong(data);
            }
          } else if (pageType == "MUSIC_PAGE_TYPE_ALBUM") {
            content = parseAlbum(data, reqAlbumObj: false);
          } else if (pageType == "MUSIC_PAGE_TYPE_ARTIST") {
            content = parseRelatedArtist(data);
          } else if (pageType == "MUSIC_PAGE_TYPE_PLAYLIST") {
            content = parsePlaylist(data);
          }
        } else {
          data = nav(result, [mrlir]);
          content = parseSongFlat(data);
        }

        contents.add(content);
      }

      items.add({'title': title, 'contents': contents});
    }
  }
  return items;
}

dynamic parseVideo(dynamic result) {
  final runs = nav(result, ['subtitle', 'runs']);
  final runsLength = runs.length;
  final artistsLen = runsLength == 3 ? 1 : getDotSeparatorIndex(runs);
  return MediaItemBuilder.fromJson({
    'title': nav(result, title_text),
    'videoId': nav(result, navigation_video_id) ??
        nav(
          result,
          navigation_browse_id,
        ),
    'artists': parseSongArtistsRuns(runs.sublist(0, artistsLen)),
    'playlistId': nav(result, navigation_playlist_id),
    'thumbnails': nav(result, thumbnail_renderer),
    'views': runs[runs.length - 1]['text'].split(' ')[0]
  });
}

dynamic parseSingle(dynamic result) {
  dynamic year;
  try {
    year = int.parse(nav(result, subtitle));
  } catch (e) {
    year = nav(result, ["subtitle", "runs", 2, "text"]);
  }
  return Album.fromJson({
    'title': nav(result, title_text),
    'artists': [
      {'name': 'Single'}
    ],
    'audioPlaylistId': nav(result, audio_watch_playlist_id),
    'year': "${year ?? ""}",
    'browseId': nav(result, ['title', 'runs', 0, ...navigation_browse_id]),
    'thumbnails': nav(result, thumbnail_renderer),
    'description':
        (nav(result, ["subtitle", "runs"])).map((run) => run['text']).join('')
  });
}

MediaItem parseSong(Map<dynamic, dynamic> result) {
  //inspect(result);
  var song = {
    'title': nav(result, title_text),
    'videoId':
        nav(result, navigation_video_id) ?? nav(result, navigation_browse_id),
    'playlistId': nav(result, navigation_playlist_id,
        noneIfAbsent: true, funName: "parseSong"),
    'thumbnails': nav(result, thumbnail_renderer),
  };

  song.addAll(parseSongRuns(result['subtitle']['runs']));
  return MediaItemBuilder.fromJson(song);
}

Map<String, dynamic> parseSongRuns(List<dynamic> runs) {
  Map<String, dynamic> parsed = {'artists': []};
  for (int i = 0; i < runs.length; i++) {
    Map<String, dynamic> run = runs[i];
    if (i % 2 != 0) {
      // uneven items are always separators
      continue;
    }
    String text = run['text'];
    if (run.containsKey('navigationEndpoint')) {
      // artist or album
      Map<String, dynamic> item = {
        'name': text,
        'id': nav(run, navigation_browse_id,
            noneIfAbsent: true, funName: "parseSongRuns")
      };

      if (item['id'] != null &&
          (item['id'].startsWith('MPRE') ||
              item['id'].contains("release_detail"))) {
        // album
        parsed['album'] = item;
      } else {
        // artist
        parsed['artists'].add(item);
      }
    } else {
      RegExp regExp = RegExp(r"^\d([^ ])* [^ ]*$");
      if (regExp.hasMatch(text) && i > 0) {
        parsed['views'] = text.split(' ')[0];
      } else if (RegExp(r"^(\d+:)*\d+:\d+$").hasMatch(text)) {
        parsed['length'] = text;
        parsed['duration_seconds'] = parseDuration(text);
      } else if (RegExp(r"^\d{4}$").hasMatch(text)) {
        parsed['year'] = text;
      } else {
        // artist without id
        parsed['artists'].add({'name': text, 'id': null});
      }
    }
  }
  return parsed;
}

Album parseAlbum(Map<dynamic, dynamic> result, {bool reqAlbumObj = true}) {
  final List runs = nav(result, ['subtitle', 'runs']);
  final Map<String, dynamic> artistInfo = parseSongRuns(runs);
  Map albumMap = {
    'title': nav(result, title_text),
    'browseId': nav(result, n_title + navigation_browse_id),
    'thumbnails': nav(result, thumbnail_renderer),
    'audioPlaylistId': nav(result, audio_watch_playlist_id),
    'description':
        (nav(result, ["subtitle", "runs"])).map((run) => run['text']).join('')
    //'isExplicit': nav(result, subtitle_badge_label, noneIfAbsent: true) != null,
  };
  albumMap.addAll(artistInfo);
  return Album.fromJson(albumMap);
}

Artist parseRelatedArtist(Map<String, dynamic> data) {
  return Artist.fromJson({
    'artist': nav(data, title_text),
    'browseId': nav(data, n_title + navigation_browse_id),
    'thumbnails': nav(data, thumbnail_renderer),
  });
}

Playlist parsePlaylist(Map<String, dynamic> data) {
  //inspect(data);
  Map<String, dynamic> playlist = {
    'title': nav(data, title_text),
    'playlistId': nav(data, ['title', 'runs', 0] + navigation_browse_id),
    'thumbnails': nav(data, thumbnail_renderer)
  };

  var subtitle = data['subtitle'];
  if (subtitle.containsKey('runs')) {
    var runs = subtitle['runs'];
    playlist['description'] = runs.map((run) => run['text']).join('');
    if (runs.length == 3 && RegExp(r'\d+ ').hasMatch(nav(data, subtitle2))) {
      playlist['count'] = nav(data, subtitle2).split(' ')[0];
      playlist['author'] = parseSongArtistsRuns(runs.sublist(0, 1));
    }
  }

  return Playlist.fromJson(playlist);
}

List<dynamic> parseSongArtistsRuns(List<dynamic> runs) {
  //print(runs);
  List<Map<String, dynamic>> artists = [];
  int n = (runs.length / 2).floor() + 1;
  for (var j = 0; j < n; j++) {
    artists.add({
      'name': runs[j * 2]['text'],
      'id': nav(runs[j * 2], navigation_browse_id,
          noneIfAbsent: false, funName: "parseSongArtistsRuns"),
    });
  }
  return artists;
}

MediaItem parseSongFlat(Map<String, dynamic> data) {
  //print(data);
  List<Map<String, dynamic>> columns = [];
  for (int i = 0; i < data['flexColumns'].length; i++) {
    columns.add(getFlexColumnItem(data, i));
  }

  Map<String, dynamic> song = {
    'title': nav(columns[0], text_run_text),
    'videoId': nav(columns[0], text_run + navigation_video_id,
            noneIfAbsent: true, funName: "parseSongFlat") ??
        nav(columns[0], text_run + navigation_browse_id,
            noneIfAbsent: true, funName: "parseSongFlat"),
    'artists': parseSongArtists(data, 1),
    'thumbnails': nav(data, thumbnails),
    //'isExplicit': nav(data, badge_label, noneIfAbsent: true) != null
  };
//checkpoint .contains
  if (columns.length > 2 && columns[2].isNotEmpty) {
    if (nav(columns[2], text_run).containsKey('navigationEndpoint')) {
      song['album'] = {
        'name': nav(columns[2], text_run_text),
        'id': nav(columns[2], text_run + navigation_browse_id)
      };
    }
  }

  return MediaItemBuilder.fromJson(song);
}

List<dynamic>? parseSongArtists(Map<String, dynamic> data, int index) {
  dynamic flexItem = getFlexColumnItem(data, index);
  if (flexItem == null || flexItem.length == 0) {
    return null;
  } else {
    var runs = flexItem['text']['runs'];
    return parseSongArtistsRuns(runs);
  }
}

Map<String, dynamic> getFlexColumnItem(Map<String, dynamic> item, int index) {
  if ((item['flexColumns']).length <= index ||
      !item['flexColumns'][index]['musicResponsiveListItemFlexColumnRenderer']
          .containsKey('text') ||
      !item['flexColumns'][index]['musicResponsiveListItemFlexColumnRenderer']
              ['text']
          .containsKey('runs')) {
    return {};
  }

  return item['flexColumns'][index]
      ['musicResponsiveListItemFlexColumnRenderer'];
}

Map<String, dynamic> parseWatchPlaylistHome(Map<dynamic, dynamic> data) {
  return {
    'title': nav(data, title_text),
    'playlistId': nav(data, navigation_watch_playlist_id),
    'thumbnails': nav(data, thumbnail_renderer),
  };
}

//For Song Watch Playlist

List<dynamic> parseWatchPlaylist(List<dynamic> results) {
  final tracks = [];
  const PPVWR = 'playlistPanelVideoWrapperRenderer';
  const PPVR = 'playlistPanelVideoRenderer';
  for (var result in results) {
    Map<String, dynamic>? counterpart;
    if (result.containsKey(PPVWR)) {
      counterpart =
          result[PPVWR]['counterpart'][0]['counterpartRenderer'][PPVR];
      result = result[PPVWR]['primaryRenderer'];
    }
    if (!result.containsKey(PPVR)) {
      continue;
    }
    final data = result[PPVR];
    if (data.containsKey('unplayableText')) {
      continue;
    }
    final track = parseWatchTrack(data);
    if (counterpart != null) {
      track['counterpart'] = parseWatchTrack(counterpart);
    }
    tracks.add(MediaItemBuilder.fromJson(track));
  }
  return tracks;
}

Map<String, dynamic> parseWatchTrack(Map<String, dynamic> data) {
  final songInfo = parseSongRuns(data['longBylineText']['runs']);

  final track = {
    'videoId': data['videoId'],
    'title': nav(data, title_text),
    'length': nav(data, ['lengthText', 'runs', 0, 'text']),
    'thumbnails': nav(data, thumbnail),
    'videoType': nav(data, ['navigationEndpoint'] + navigation_video_type),
  };
  track.addAll(songInfo);
  return track;
}

String? getTabBrowseId(Map<String, dynamic> watchNextRenderer, int tabId) {
  try {
    final tabs = watchNextRenderer['tabs'];
    if (tabs is List && tabId >= 0 && tabId < tabs.length) {
      final tabRenderer = tabs[tabId]['tabRenderer'];
      if (tabRenderer != null && !tabRenderer.containsKey('unselectable')) {
        return tabRenderer['endpoint']?['browseEndpoint']?['browseId'];
      }
    }
  } catch (e) {
    // ignore
  }
  return null;
}

String? getWatchTabBrowseId(Map<String, dynamic> watchNextRenderer, String tabName) {
  try {
    final tabs = watchNextRenderer['tabs'];
    if (tabs is List) {
      final query = tabName.toLowerCase();
      for (final tab in tabs) {
        final tabRenderer = tab['tabRenderer'];
        if (tabRenderer == null || tabRenderer.containsKey('unselectable')) continue;
        final title = (tabRenderer['title'] ?? '').toString().toLowerCase();
        final browseId = tabRenderer['endpoint']?['browseEndpoint']?['browseId']?.toString();
        final pageType = tabRenderer['endpoint']?['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType']?.toString().toLowerCase() ?? '';

        if (query == 'lyrics') {
          if (title.contains('lyrics') || pageType.contains('lyrics') || (browseId != null && browseId.startsWith('MPLY'))) {
            return browseId;
          }
        } else if (query == 'related') {
          if (title.contains('related') || pageType.contains('related') || (browseId != null && browseId.startsWith('MPTR'))) {
            return browseId;
          }
        } else if (title.contains(query)) {
          return browseId;
        }
      }
    }
  } catch (e) {
    // ignore
  }
  return null;
}


///Parse playlist songs, Also used in Album Song parsing
///
///[dynamic album,dynamic artists] used in Album case
List<dynamic> parsePlaylistItems(List<dynamic> results,
    {List<List<dynamic>>? menuEntries,
    dynamic thumbnailsM,
    dynamic artistsM,
    String? albumYear,
    dynamic albumIdName,
    bool isAlbum = false}) {
  List<MediaItem> songs = [];

  //int count = 1;
  for (dynamic result in results) {
    // count += 1;
    if (!result.containsKey('musicResponsiveListItemRenderer')) {
      continue;
    }
    dynamic data = result['musicResponsiveListItemRenderer'];
    String? videoId;
    String? trackDetails;

    videoId = nav(data, ['playlistItemData', 'videoId']);

    if (videoId == null && isAlbum) {
      final creditId = nav(data, [
        'menu',
        'menuRenderer',
        'items',
        5,
        'menuNavigationItemRenderer',
        'navigationEndpoint',
        'browseEndpoint',
        'browseId'
      ]);
      videoId = creditId?.split("MPTC")[1];
      
    }

    if(isAlbum){
      // Contains track number and total tracks 
      trackDetails = data?["index"] != null
          ? "${nav(data, ['index', 'runs', 0, 'text'])}/${results.length}"
          : null;
    }

    // if the item has a menu, find its setVideoId
    if (videoId == null) {
      if (data.containsKey('menu')) {
        for (dynamic item in nav(data, menu_items)) {
          if (item.containsKey('menuServiceItemRenderer')) {
            dynamic menuService = nav(item, menu_service);
            //inspect(menuService);

            if (menuService.containsKey('playlistEditEndpoint')) {
              videoId = menuService['playlistEditEndpoint']['actions'][0]
                  ['removedVideoId'];
              // print("$videoId");
            }
          }
        }
      }
    }

    // if item is not playable, the videoId was retrieved above
    if (videoId == null && nav(data, play_button) != null) {
      if (nav(data, play_button).containsKey('playNavigationEndpoint')) {
        videoId = nav(data, play_button)['playNavigationEndpoint']
            ['watchEndpoint']['videoId'];
      }
    }

    String? title = getItemText(data, 0);
    if (title == 'Song deleted') {
      continue;
    }

    List? artists = parseSongArtists(data, 1);

    dynamic album = isAlbum ? albumIdName : parseSongAlbum({...data}, 2);

    dynamic duration;
    if (data.containsKey('fixedColumns')) {
      if (getFixedColumnItem(data, 0)!['text'].containsKey('simpleText')) {
        duration = getFixedColumnItem(data, 0)!['text']['simpleText'];
      } else {
        duration = getFixedColumnItem(data, 0)!['text']['runs'][0]['text'];
      }
    }

    dynamic thumbnails_;
    if (data.containsKey('thumbnail')) {
      thumbnails_ = nav(data, thumbnails);
    }

    bool isAvailable = true;
    if (data.containsKey('musicItemRendererDisplayPolicy')) {
      isAvailable = data['musicItemRendererDisplayPolicy'] !=
          'MUSIC_ITEM_RENDERER_DISPLAY_POLICY_GREY_OUT';
    }

    //print('here');
    dynamic song = {
      'videoId': videoId,
      'title': title,
      'album': album,
      'artists': artists ?? artistsM,
      'thumbnails': isAlbum ? thumbnailsM : thumbnails_ ?? thumbnailsM,
      'isAvailable': isAvailable,
      'trackDetails': trackDetails
    };

    if (duration != null) {
      song['length'] = duration;
      song['duration_seconds'] = parseDuration(duration);
    }

    if (menuEntries != null) {
      for (final List<dynamic> menuEntry in menuEntries) {
        song[menuEntry.last] = nav(data,
            menu_items + menuEntry.map((e) => e).whereType<String>().toList());
      }
    }
    if (song['videoId'] != null) {
      songs.add(MediaItemBuilder.fromJson(song));
    }
  }
  return songs;
}

Map<String, dynamic>? parseSongAlbum(Map<String, dynamic> data, int index) {
  Map<String, dynamic> flexItem = getFlexColumnItem(data, index);
  // print("here");
  if (flexItem.isNotEmpty) {
    return {
      'name': getItemText(data, index),
      'id': getBrowseId(flexItem, 0),
    };
  }
  return null;
}

String? getBrowseId(Map<String, dynamic> item, int index) {
  if (item['text']['runs'][index].containsKey('navigationEndpoint')) {
    return nav(item['text']['runs'][index], navigation_browse_id);
  }
  return null;
}

Map<String, dynamic> parseSongMenuTokens(Map<String, dynamic> item) {
  Map<String, dynamic> toggleMenu = item[toggle_menu];
  String serviceType = toggleMenu['defaultIcon']['iconType'];
  Map<String, dynamic> libraryAddToken =
      nav(toggleMenu, ['defaultServiceEndpoint', ...feedback_token]);
  Map<String, dynamic> libraryRemoveToken =
      nav(toggleMenu, ['toggledServiceEndpoint', ...feedback_token]);

  if (serviceType == "LIBRARY_REMOVE") {
    // swap if already in library
    Map<String, dynamic> temp = libraryAddToken;
    libraryAddToken = libraryRemoveToken;
    libraryRemoveToken = temp;
  }

  return {'add': libraryAddToken, 'remove': libraryRemoveToken};
}

dynamic nav(dynamic root, List items,
    {bool noneIfAbsent = false, String funName = "d"}) {
  try {
    dynamic res = root;
    for (final item in items) {
      res = res[item];
    }
    return res;
  } catch (e) {
    return null;
  }
}

//search parsers
dynamic parseTopResult(
    Map<String, dynamic> data, List<String> searchResultTypes) {
  Map<String, dynamic> searchResult = {};
  String? resultType =
      getSearchResultType(nav(data, subtitle), searchResultTypes);
  searchResult['resultType'] = resultType;

  if (resultType == 'artist') {
    String? subscribers = nav(data, subtitle2);
    if (subscribers != null) {
      searchResult['subscribers'] = subscribers.split(' ')[0];
    }
    Map<String, dynamic> artistInfo =
        parseSongRuns(nav(data, ['title', 'runs']));
    searchResult.addAll(artistInfo);
  }

  if (resultType == 'song' || resultType == 'video' || resultType == 'album') {
    searchResult['title'] = nav(data, title_text);
    List runs = nav(data, ['subtitle', 'runs']);
    List songInfoRuns = runs.sublist(2);
    Map<String, dynamic> songInfo = parseSongRuns(songInfoRuns);
    searchResult.addAll(songInfo);
  }

  searchResult['thumbnails'] = nav(data, thumbnails);

  if (resultType == 'song' || resultType == 'video') {
    return MediaItemBuilder.fromJson(searchResult);
  } else if (resultType == 'playlist') {
    return Playlist.fromJson(searchResult);
  } else if (resultType == 'album') {
    return Album.fromJson(searchResult);
  } else if (resultType == 'Artist') {
    return Artist.fromJson(searchResult);
  }
  return searchResult;
}

String? getSearchResultType(
    String? resultTypeLocal, List<String> resultTypesLocal) {
  if (resultTypeLocal == null) {
    return null;
  }
  List<String> resultTypes = ['artist', 'playlist', 'song', 'video', 'station'];
  resultTypeLocal = resultTypeLocal.toLowerCase();
  if (!resultTypesLocal.contains(resultTypeLocal)) {
    return 'album';
  } else {
    int index = resultTypesLocal.indexOf(resultTypeLocal);
    return resultTypes[index];
  }
}

List<dynamic> parseSearchResults(List<dynamic> results,
    List<String> searchResultTypes, String? resultType, String category) {
  List<dynamic> items = [];
  for (dynamic result in results) {
    if (result == null) continue;
    if (result is Map) {
      if (result.containsKey('musicResponsiveListItemRenderer')) {
        final parsed = parseSearchResult(
            result['musicResponsiveListItemRenderer'],
            searchResultTypes,
            resultType,
            category);
        if (parsed != null) items.add(parsed);
      } else if (result.containsKey('itemSectionRenderer')) {
        final sub = nav(result, ['itemSectionRenderer', 'contents']);
        if (sub is List) {
          items.addAll(parseSearchResults(sub, searchResultTypes, resultType, category));
        }
      } else if (result.containsKey('musicShelfRenderer')) {
        final sub = nav(result, ['musicShelfRenderer', 'contents']);
        if (sub is List) {
          items.addAll(parseSearchResults(sub, searchResultTypes, resultType, category));
        }
      }
    }
  }
  return items;
}

dynamic parseCardShelfItem(Map<String, dynamic> card) {
  try {
    final title = nav(card, ['title', 'runs', 0, 'text']) ?? '';
    final subtitleRuns = nav(card, ['subtitle', 'runs']) as List? ?? [];
    String type = subtitleRuns.isNotEmpty
        ? (subtitleRuns[0]['text'] ?? '').toString().toLowerCase()
        : 'song';

    if (type.contains('song')) {
      type = 'song';
    } else if (type.contains('video')) {
      type = 'video';
    } else if (type.contains('artist')) {
      type = 'artist';
    } else if (type.contains('album') || type.contains('single') || type.contains('ep')) {
      type = 'album';
    } else if (type.contains('playlist')) {
      type = 'playlist';
    } else {
      type = 'song';
    }

    String? videoId = nav(card, ['title', 'runs', 0, 'navigationEndpoint', 'watchEndpoint', 'videoId']);
    videoId ??= nav(card, ['onTap', 'watchEndpoint', 'videoId']);
    if (videoId == null && card['buttons'] is List) {
      for (var btn in card['buttons']) {
        videoId = nav(btn, ['buttonRenderer', 'command', 'watchEndpoint', 'videoId']);
        if (videoId != null) break;
      }
    }

    String? browseId = nav(card, ['title', 'runs', 0, 'navigationEndpoint', 'browseEndpoint', 'browseId']);
    browseId ??= nav(card, ['onTap', 'browseEndpoint', 'browseId']);

    dynamic thumbs = nav(card, ['thumbnail', 'musicThumbnailRenderer', 'thumbnail', 'thumbnails']) ??
        nav(card, ['thumbnail', 'thumbnails']);

    List remainingRuns = subtitleRuns.length > 2 ? subtitleRuns.sublist(2) : subtitleRuns;
    Map<String, dynamic> metadata = parseSongRuns(remainingRuns);

    Map<String, dynamic> cardData = {
      'title': title,
      'videoId': videoId,
      'browseId': browseId,
      'thumbnails': thumbs,
      'resultType': type,
      ...metadata,
    };

    if (type == 'song' || type == 'video') {
      if (videoId != null) {
        return MediaItemBuilder.fromJson(cardData);
      }
    } else if (type == 'artist' && browseId != null) {
      cardData['artist'] = title;
      return Artist.fromJson(cardData);
    } else if (type == 'album' && browseId != null) {
      return Album.fromJson(cardData);
    } else if (type == 'playlist' && browseId != null) {
      cardData['playlistId'] = browseId;
      return Playlist.fromJson(cardData);
    }
  } catch (e) {
    return null;
  }
  return null;
}

dynamic parseSearchResult(Map<String, dynamic>? data,
    List<String> searchResultTypes, String? resultType, String? category) {
  if (data == null) return null;

  if ((resultType != null && resultType.toLowerCase().contains("playlist")) ||
      (category != null && category.toLowerCase().contains("playlist"))) {
    resultType = 'playlist';
  }

  Map<String, dynamic> searchResult = {'category': category};
  String? videoType = nav(data,
      [...play_button, 'playNavigationEndpoint', ...navigation_video_type]);
  if (videoType != null) {
    resultType = (videoType == 'MUSIC_VIDEO_TYPE_ATV') ? 'song' : 'video';
  }

  final flexItem1 = getFlexColumnItem(data, 1);
  final dynamic flexRunsRaw = nav(flexItem1, ['text', 'runs']);
  List flexRuns = flexRunsRaw is List ? flexRunsRaw : [];

  String firstRunText = flexRuns.isNotEmpty ? (flexRuns[0]?['text'] ?? '').toString().trim().toLowerCase() : '';
  bool hasTypePrefix = ['song', 'video', 'single', 'album', 'ep', 'artist', 'playlist', 'episode', 'podcast'].contains(firstRunText);

  if (resultType == null) {
    if (hasTypePrefix) {
      if (firstRunText == 'song') {
        resultType = 'song';
      } else if (firstRunText == 'video' || firstRunText == 'episode' || firstRunText == 'podcast') {
        resultType = 'video';
      } else if (firstRunText == 'artist') {
        resultType = 'artist';
      } else if (firstRunText == 'single' || firstRunText == 'album' || firstRunText == 'ep') {
        resultType = 'album';
      } else if (firstRunText == 'playlist') {
        resultType = 'playlist';
      }
    } else if (category != null && category.isNotEmpty && category != 'mixed') {
      String catLower = category.toLowerCase();
      if (catLower.contains('song')) {
        resultType = 'song';
      } else if (catLower.contains('video')) {
        resultType = 'video';
      } else if (catLower.contains('artist')) {
        resultType = 'artist';
      } else if (catLower.contains('album')) {
        resultType = 'album';
      } else if (catLower.contains('playlist')) {
        resultType = 'playlist';
      }
    } else {
      resultType = getSearchResultType(getItemText(data, 1), searchResultTypes) ?? 'song';
    }
  }

  searchResult['resultType'] = resultType;

  String? title = getItemText(data, 0);
  if (title == null || title.isEmpty) {
    title = nav(data, ['flexColumns', 0, 'musicResponsiveListItemFlexColumnRenderer', 'text', 'runs', 0, 'text']);
  }
  searchResult['title'] = title ?? '';

  if (resultType == 'song' || resultType == 'video' || resultType == 'station') {
    String? vid = nav(data, [...play_button, 'playNavigationEndpoint', 'watchEndpoint', 'videoId']);
    vid ??= nav(data, ['overlay', 'musicItemThumbnailOverlayRenderer', 'content', 'musicPlayButtonRenderer', 'playNavigationEndpoint', 'watchEndpoint', 'videoId']);
    vid ??= nav(data, ['flexColumns', 0, 'musicResponsiveListItemFlexColumnRenderer', 'text', 'runs', 0, 'navigationEndpoint', 'watchEndpoint', 'videoId']);
    vid ??= nav(data, ['navigationEndpoint', 'watchEndpoint', 'videoId']);
    vid ??= nav(data, ['onTap', 'watchEndpoint', 'videoId']);
    if (vid == null && data.containsKey('menu')) {
      final menuItems = nav(data, menu_items);
      if (menuItems is List) {
        for (dynamic item in menuItems) {
          vid = nav(item, ['menuNavigationItemRenderer', 'navigationEndpoint', 'watchEndpoint', 'videoId']);
          if (vid != null) break;
        }
      }
    }
    searchResult['videoId'] = vid;
    searchResult['videoType'] = videoType;
  }

  List runsToParse = hasTypePrefix && flexRuns.length > 2 ? flexRuns.sublist(2) : flexRuns;

  if (resultType == 'artist') {
    searchResult['artist'] = title;
    String subscribers = runsToParse.map((r) => r['text'] ?? '').join('');
    searchResult['subscribers'] = subscribers;
  } else if (resultType == 'album') {
    searchResult['type'] = hasTypePrefix ? flexRuns[0]['text'] : getItemText(data, 1);
    searchResult['audioPlaylistId'] = nav(data, audio_watch_playlist_id);
    searchResult['description'] = runsToParse.map((r) => r['text'] ?? '').join('');
    final songInfo = parseSongRuns(runsToParse);
    searchResult.addAll(songInfo);
  } else if (resultType == 'playlist') {
    searchResult['description'] = runsToParse.map((r) => r['text'] ?? '').join('');
    searchResult['itemCount'] = runsToParse.isNotEmpty ? runsToParse.last['text']?.toString().split(' ')[0] : '0';
  } else if (resultType == 'station') {
    searchResult['videoId'] = nav(data, navigation_video_id) ?? nav(data, navigation_browse_id);
    searchResult['playlistId'] = nav(data, navigation_playlist_id);
  } else {
    searchResult['album'] = null;
    searchResult['length'] = null;
    searchResult['year'] = null;
    final songInfo = parseSongRuns(runsToParse);
    searchResult.addAll(songInfo);
  }

  if (['artist', 'album', 'playlist'].contains(resultType)) {
    String? bId = nav(data, navigation_browse_id);
    bId ??= nav(data, ['flexColumns', 0, 'musicResponsiveListItemFlexColumnRenderer', 'text', 'runs', 0, 'navigationEndpoint', 'browseEndpoint', 'browseId']);
    bId ??= nav(data, ['navigationEndpoint', 'browseEndpoint', 'browseId']);
    searchResult['browseId'] = bId;
    if (bId == null && resultType == 'artist') {
      return null;
    }
    if (resultType == 'playlist') {
      searchResult['playlistId'] = bId;
    }
  }

  if (resultType == 'song' || resultType == 'album') {
    searchResult['isExplicit'] = nav(data, badge_label);
  }

  searchResult['thumbnails'] = nav(data, thumbnails) ??
      nav(data, thumbnail_renderer) ??
      nav(data, ['thumbnail', 'musicThumbnailRenderer', 'thumbnail', 'thumbnails']) ??
      nav(data, ['thumbnail', 'thumbnails']);

  if (resultType == 'song' || resultType == 'video') {
    if (searchResult['videoId'] != null) {
      return MediaItemBuilder.fromJson(searchResult);
    }
    return null;
  } else if (resultType == 'playlist') {
    return Playlist.fromJson(searchResult);
  } else if (resultType == 'album') {
    return Album.fromJson(searchResult);
  } else if (resultType == 'artist') {
    return Artist.fromJson(searchResult);
  }

  return searchResult;
}

//parse album Header
Map<String, dynamic> parseAlbumHeader(Map<String, dynamic> response) {
  Map<String, dynamic> header = nav(response, [
        'contents',
        "twoColumnBrowseResultsRenderer",
        'tabs',
        0,
        "tabRenderer",
        "content",
        "sectionListRenderer",
        "contents",
        0,
        "musicResponsiveHeaderRenderer"
      ]) ??
      nav(response, ["header", "musicDetailHeaderRenderer"]);
  Map<String, dynamic> album = {
    'title': nav(header, title_text),
    'type': nav(header, subtitle),
    'thumbnails': nav(header, thumnail_cropped) ??
        nav(header,
            ["thumbnail", "musicThumbnailRenderer", "thumbnail", "thumbnails"])
  };

  album["description"] = nav(header, [
        "description",
        "musicDescriptionShelfRenderer",
        "description",
        "runs",
        0,
        "text"
      ]) ??
      (nav(header, ["subtitle", "runs"]))
          .map((item) => item.values.first)
          .toList()
          .join(" ");

  Map<String, dynamic> albumInfo =
      parseSongRuns(header['subtitle']['runs'].sublist(2));
  try {
    albumInfo.addAll(parseSongRuns(header["straplineTextOne"]['runs']));
  } catch (e) {}
  album.addAll(albumInfo);

  if (header['secondSubtitle']['runs'].length > 1) {
    album['trackCount'] = (header['secondSubtitle']['runs'][0]['text']);
    album['duration'] = header['secondSubtitle']['runs'][2]['text'];
  } else {
    album['duration'] = header['secondSubtitle']['runs'][0]['text'];
  }

  // add to library/uploaded

  album['audioPlaylistId'] =
      nav(response, ['microformat', "microformatDataRenderer", "urlCanonical"])
          .toString()
          .split("list=")[1];

  return album;
}

Map<String, dynamic> parseArtistContents(List results) {
  final Map<String, dynamic> navigationEndpointsNContent = {
    'Songs': null,
    'Videos': null,
    'Albums': null,
    'Singles': null
  };

  for (dynamic result in results) {
    if (result.containsKey('musicShelfRenderer')) {
      final title =
          nav(result, ['musicShelfRenderer', 'title', 'runs', 0])['text'];
      final browseEndpoint = nav(
          result, ['musicShelfRenderer', 'bottomEndpoint', 'browseEndpoint']);

      final contentList = nav(result, ['musicShelfRenderer', 'contents']);
      final content = parsePlaylistItems(contentList);

      if (browseEndpoint == null) {
        navigationEndpointsNContent[title] = {"content": content};
      } else {
        navigationEndpointsNContent[title] = {
          'browseId': browseEndpoint['browseId'],
          'params': browseEndpoint['params'],
          "content": content
        };
      }
    } else if (result.containsKey('musicCarouselShelfRenderer')) {
      final browseEndpoint = nav(result, [
        'musicCarouselShelfRenderer',
        'header',
        'musicCarouselShelfBasicHeaderRenderer',
        'moreContentButton',
        'buttonRenderer',
        'navigationEndpoint',
        'browseEndpoint'
      ]);

      final title = nav(result, [
        'musicCarouselShelfRenderer',
        'header',
        'musicCarouselShelfBasicHeaderRenderer',
        'title',
        'runs',
        0
      ])['text'];

      final contentList =
          nav(result, ['musicCarouselShelfRenderer', 'contents']);
      dynamic content = [];
      if (title == "Videos") {
        content = contentList
            .map((video) => parseVideo(video['musicTwoRowItemRenderer']))
            .toList();
      } else if (title == "Albums") {
        content = contentList
            .map((album) => parseAlbum(album['musicTwoRowItemRenderer']))
            .toList();
      } else if (title == "Singles") {
        content = contentList
            .map((single) => parseSingle(single['musicTwoRowItemRenderer']))
            .toList();
      }

      if (browseEndpoint != null) {
        navigationEndpointsNContent[title] = {
          'browseId': browseEndpoint['browseId'],
          'params': browseEndpoint['params'],
          'content': content
        };
      } else {
        navigationEndpointsNContent[title] = {'content': content};
      }
    }
  }
  return navigationEndpointsNContent;
}

dynamic parseContentList(results, Function parseFunc) {
  var contents = [];
  for (dynamic result in results) {
    contents.add(parseFunc(result['musicTwoRowItemRenderer']));
  }

  return contents;
}

Map<String, dynamic> parseChartsItem(dynamic result) {
  final contentList = nav(result, ['musicCarouselShelfRenderer', 'contents']);
  final String category = nav(result, [
    'musicCarouselShelfRenderer',
    'header',
    'musicCarouselShelfBasicHeaderRenderer',
    'title',
    ...run_text
  ]);
  if (category.contains('videos')) {
    final videoList = contentList
        .map((video) => parseVideo(video['musicTwoRowItemRenderer']))
        .toList();
    return {'title': category, 'contents': videoList};
  } else if (category.contains('artists')) {
    final artists = contentList
        .map((artist) =>
            parseChartsArtist(artist['musicResponsiveListItemRenderer']))
        .toList();
    return {'title': category, 'contents': artists};
  } else if (category.contains('Genres')) {
    final playlists = contentList
        .map((playlist) => parsePlaylist(playlist['musicTwoRowItemRenderer']))
        .toList();
    return {'title': category, 'contents': playlists};
  } else if (category.contains('Trending')) {
    final videoList = contentList
        .map((video) =>
            parseChartsTrending(video['musicResponsiveListItemRenderer']))
        .whereType<MediaItem>()
        .toList();
    return {'title': category, 'contents': videoList};
  }
  return {};
}

Artist parseChartsArtist(dynamic data) {
  final subscribers = getFlexColumnItem(data, 1);
  dynamic subs;
  if (subscribers.isNotEmpty) {
    subs = nav(subscribers, text_run_text).split(' ')[0];
  }

  final parsed = {
    'artist': nav(getFlexColumnItem(data, 0), text_run_text),
    'browseId': nav(data, navigation_browse_id),
    'subscribers': subs,
    'thumbnails': nav(data, thumbnails),
  };

  return Artist.fromJson(parsed);
}

MediaItem? parseChartsTrending(dynamic data) {
  final flex_0 = getFlexColumnItem(data, 0);
  final artists = parseSongArtists(data, 1);

  final video = {
    'title': nav(flex_0, text_run_text),
    'videoId': nav(
          flex_0,
          text_run + navigation_video_id,
        ) ??
        nav(data, ['playlistItemData', 'videoId']),
    'playlistId': nav(flex_0, text_run + navigation_playlist_id),
    'artists': artists,
    'thumbnails': nav(data, thumbnails),
  };
  if (video['videoId'] == null) {
    return null;
  }
  return MediaItemBuilder.fromJson(video);
}
