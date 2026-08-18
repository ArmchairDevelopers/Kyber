import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:nexus_bridge/src/api_client/nxs_api_client.dart';
import 'package:nexus_bridge/src/types/nxs_search_result.dart';

class NexusBridge {
  NexusBridge._({
    required Dio dio,
    String? apiToken,
  }) {
    _dio = dio;

    final apiDio = dio;
    apiDio.options.headers['apikey'] = apiToken;
    apiClient = NxsApiClient(apiDio);
  }

  late Dio _dio;
  late NxsApiClient apiClient;
  final List<NexusCategory> categories = [
    NexusCategory(name: 'All Mods', id: ''),
    NexusCategory(name: 'Audio', id: '3'),
    NexusCategory(name: 'Gameplay', id: '7'),
    NexusCategory(name: 'Maps', id: '4'),
    NexusCategory(name: 'Miscellaneous', id: '2'),
    NexusCategory(name: 'Models and Textures', id: '6'),
    NexusCategory(name: 'Skins and Abilities - Classes', id: '15'),
    NexusCategory(name: 'Skins and Abilities - Heroes', id: '14'),
    NexusCategory(name: 'User Interface', id: '8'),
    NexusCategory(name: 'Utilities', id: '10'),
    NexusCategory(name: 'Vehicles', id: '1'),
    NexusCategory(name: 'Visuals and Graphics', id: '5'),
    NexusCategory(name: 'Weapons', id: '11'),
  ];
  final Map<int, List<int>> _modStatistics = {};

  static Future<NexusBridge> getInstance({Dio? dio, String? apiToken}) async {
    dio ??= Dio();

    final b = NexusBridge._(dio: dio ?? Dio(), apiToken: apiToken);
    await b.fetchModStatistics();

    return b;
  }

  Future<NexusModsSearchResult> search({required String terms}) async {
    terms = terms.replaceAll(' ', ',');
    final resp = await _dio.get<Map<String, dynamic>>(
      'https://api.nexusmods.com/mods?terms=$terms&game_id=2229',
    );

    return NexusModsSearchResult.fromJson(resp.data!);
  }

  Future<void> fetchModStatistics() async {
    if (_modStatistics.isNotEmpty) {
      return;
    }

    final resp = await _dio.get<String>(
      'https://staticstats.nexusmods.com/live_download_counts/mods/2229.csv',
    );

    final stats = Csv(lineDelimiter: '\n', dynamicTyping: true)
        .decode(resp.data!.substring(0, resp.data!.lastIndexOf('\n')));

    for (final stat in stats) {
      _modStatistics[stat.first as int] = List<int>.from(stat.sublist(1));
    }
  }

  int getModViews(String modId) {
    return _modStatistics[int.parse(modId)]?.last ?? 0;
  }

  Future<List<WSNexusModImage>> getModImages(String modId) async {
    Future<Response<String>> requestModImage(int page) async {
      return await _dio.get<String>(
        'https://www.nexusmods.com/Core/Libs/Common/Widgets/ModImagesList?RH_ModImagesList1=game_id:2229,id:$modId,page_size:24,1page:$page,rh_group_id:1',
        options: Options(
          headers: {
            'x-requested-with': 'XMLHttpRequest',
          },
        ),
      );
    }

    final resp = await requestModImage(1);
    final doc = parse(resp.data);

    final pageScriptIndex = resp.data!.indexOf('pages: [');
    final x = resp.data!.substring(pageScriptIndex);
    final end = x.indexOf(']');
    final pages = x.substring(0, end + 1).replaceAll('pages:', '').split("{").length - 1;

    final images = doc.querySelectorAll('.image-tile').map((e) {
      final img = e.querySelector('.fore_div')!.children.first.attributes['src']!;
      final title = e.querySelector('.tile-name')!.text;
      return WSNexusModImage(url: img, title: title);
    }).toList();

    for (var i = 1; i != pages; i++) {
      final document = parse((await requestModImage(i)).data);
      images.addAll(
        document.querySelectorAll('.image-tile').map((e) {
          final img = e.querySelector('.fore_div')!.children.first.attributes['src']!;
          final title = e.querySelector('.tile-name')!.text;
          return WSNexusModImage(url: img, title: title);
        }),
      );
    }

    return images.toList();
  }

  Future<String> getModHeader(String modId) async {
    final x = DateTime.now();
    final resp = await _dio.get<String>(
      'https://www.nexusmods.com/starwarsbattlefront22017/mods/$modId',
    );

    final doc = parse(resp.data);
    final header = doc.querySelector('.header-img')?.children.first;
    return header?.attributes['src']! ?? 'https://www.nexusmods.com/assets/images/default/bg_default.jpg';
  }

  Future<WSNexusMod> fetchMod(String id) async {
    try {
      final resp = await _dio.get<String>(
        'https://www.nexusmods.com/starwarsbattlefront22017/mods/$id',
      );
      final doc = parse(resp.data);
      final header = doc.querySelector('.header-img')?.children.first;
      final desc = doc.querySelector('.mod_description_container')!.innerHtml;

      final requirementsDoc = doc
          .querySelectorAll('h3')
          .where(
            (e) => e.text.toLowerCase().contains('nexus requirements'),
          )
          .firstOrNull
          ?.parent
          ?.children
          .last;
      final requirements = <ModRequirement>[];

      for (final req in requirementsDoc?.children.last.children ?? <Element>[]) {
        final name = req.children.first.text;
        final url = req.children.first.attributes['href'];
        final notes = req.children.last.text;
        requirements.add(ModRequirement(name: name, url: url, notes: notes));
      }

      return WSNexusMod(
        headerSource: header?.attributes['src']! ?? 'https://www.nexusmods.com/assets/images/default/bg_default.jpg',
        description: desc,
        requirements: requirements,
      );
    } catch (e) {
      print("Error fetching mod: $e");
      rethrow;
    }
  }

  Future<List<NexusCategory>> getCategoryList() async {
    final resp = await _dio.get<String>(
      'https://www.nexusmods.com/starwarsbattlefront22017/mods',
    );

    final doc = parse(resp.data);
    final categories = doc.querySelectorAll('input[name="categories[]"]').map((e) => NexusCategory(
          name: e.parent!.children.last.text.replaceAll('\n', ''),
          id: e.attributes['value']!,
        ));

    for (final cat in categories) {
      print(cat.name);
      print(cat.id);
      print('---');
    }

    return categories.toList();
  }

  Future<(int, List<NexusListMod>)> fetchMods({
    String sortBy = 'two_weeks_ratings',
    String category = '7',
    String maxResults = '6',
    int page = 1,
    int time = 0,
  }) async {
    if (!_modStatistics.isNotEmpty) {
      await fetchModStatistics();
    }

    final queryParameters =
        'RH_ModList=categories%5B0%5D:$category,categories%5B2%5D:$category,nav:true,home:false,type:0,user_id:0,game_id:2229,advfilt:true,category_id:$category,include_adult:false,show_game_filter:false,page_size:20,page:${page.toString()},sort_by:$sortBy,time:${time.toString()}';

    try {
      final resp = await _dio.get<String>(
        'https://www.nexusmods.com/Core/Libs/Common/Widgets/ModList?$queryParameters',
        options: Options(
          headers: {
            'accept-language': 'en-US,en;q=0.9',
            'cache-control': 'no-cache',
            'pragma': 'no-cache',
            'x-requested-with': 'XMLHttpRequest',
          },
        ),
      );

      final doc = parse(resp.data);
      final mods = doc.querySelectorAll('.mod-tile').map((e) {
        final id = int.parse(
          e.querySelector('.mod-tile-left')!.attributes['data-mod-id']!,
        );
        final name = e.querySelector('.tile-name')!.children.first.text;
        final time = e.querySelector('.date')!.attributes['datetime']!;
        final author = e.querySelector('.realauthor')!.text.replaceAll('Author:  ', '');
        final uploader = e.querySelector('.author')!.children.last.text;
        final desc = e.querySelector('.desc')!.text;
        final img = e.querySelector('.fore')!.attributes['src']!;
        final endorsements = e.querySelector('.endorsecount')!.children.last.text;
        final size = e.querySelector('.sizecount')!.children.last.text;

        return NexusListMod(
          id: id,
          name: name,
          author: author,
          uploader: uploader,
          description: desc,
          image: img,
          downloads: _modStatistics[id]?[0] ?? -1,
          views: _modStatistics[id]?.last ?? -1,
          endorsements: endorsements,
          size: size.replaceAll('	', '').replaceAll('\n', ''),
          date: DateTime.parse(time),
        );
      });

      var lastPage = "0";
      final paginationDiv = doc.querySelector('.pagination');
      if (paginationDiv != null) {
        final ul = paginationDiv.children[1];
        lastPage = ul.children.last.text.trim();
        if (lastPage.isEmpty) {
          lastPage = ul.children[ul.children.length - 2].text.trim();
        }
      }

      return (int.parse(lastPage), mods.toList());
    } catch (e) {
      print(e);
      if (e is DioException) {}
      rethrow;
    }
  }
}

class NexusCategory {
  String name;
  String id;

  NexusCategory({
    required this.name,
    required this.id,
  });
}

class ModRequirement {
  ModRequirement({
    required this.name,
    required this.notes,
    this.url,
  });

  final String name;
  final String? url;
  final String notes;
}

class WSNexusModImage {
  WSNexusModImage({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;
}

class WSNexusMod {
  WSNexusMod({
    required this.description,
    required this.headerSource,
    this.requirements = const [],
  });

  final List<ModRequirement> requirements;
  final String description;
  final String headerSource;
}

class NexusXMod {
  NexusXMod({
    required this.id,
    required this.name,
    required this.author,
    required this.image,
    required this.description,
    required this.downloads,
    required this.views,
    required this.endorsements,
    required this.uploader,
    required this.date,
    required this.header,
    required this.size,
  });

  final int id;
  final String size;
  final String name;
  final String author;
  final String uploader;
  final String image;
  final String header;
  final String description;
  final int downloads;
  final int views;
  final String endorsements;
  final DateTime date;
}

class NexusListMod {
  NexusListMod({
    required this.id,
    required this.name,
    required this.author,
    required this.image,
    required this.description,
    required this.downloads,
    required this.views,
    required this.endorsements,
    required this.uploader,
    required this.date,
    required this.size,
  });

  final int id;
  final String size;
  final String name;
  final String author;
  final String uploader;
  final String image;
  final String description;
  final int downloads;
  final int views;
  final String endorsements;
  final DateTime date;
}
