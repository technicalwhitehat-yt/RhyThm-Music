import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../navigator.dart';
import '../screens/Search/search_result_screen_controller.dart';
import '/ui/widgets/content_list_widget_item.dart';

class ContentListWidget extends StatelessWidget {
  ///ContentListWidget is used to render a section of Content like a list of Albums or Playlists in HomeScreen
  const ContentListWidget(
      {super.key,
      this.content,
      this.isHomeContent = true,
      this.scrollController});

  ///content will be of class Type AlbumContent or PlaylistContent
  final dynamic content;
  final bool isHomeContent;
  final ScrollController? scrollController;

  String _formatTitle(String rawTitle) {
    if (rawTitle.isEmpty) return rawTitle;
    final trimmed = rawTitle.trim();
    final lowerNoSpace = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (lowerNoSpace == "youmightalsolike") {
      return "You Might Also Like";
    }
    if (lowerNoSpace == "quickpicks") {
      return "Quick Picks";
    }
    if (lowerNoSpace == "trending") {
      return "Trending";
    }
    if (lowerNoSpace == "topmusicvideos") {
      return "Top Music Videos";
    }
    if (lowerNoSpace == "basedonlastinteraction") {
      return "Based on Last Interaction";
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isAlbumContent = content.runtimeType.toString() == "AlbumContent";
    final rawTitle = content.title.toString();
    final displayTitle = _formatTitle(rawTitle);
    final isLikeSection = displayTitle.toLowerCase().contains("like") ||
        displayTitle.toLowerCase().contains("quick");

    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0, right: 18.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      !isHomeContent && displayTitle.length > 12
                          ? "${displayTitle.substring(0, 12)}..."
                          : displayTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  !isHomeContent
                      ? TextButton(
                          onPressed: () {
                            final scrresController =
                                Get.find<SearchResultScreenController>();
                            scrresController.viewAllCallback(content.title);
                          },
                          child: Text("viewAll".tr,
                              style: Theme.of(Get.context!).textTheme.titleSmall))
                      : Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              Get.toNamed(
                                ScreenNavigationSetup.searchScreen,
                                id: ScreenNavigationSetup.id,
                              );
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: isDark ? 0.25 : 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: isDark ? 0.7 : 0.4),
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.search_rounded,
                                  size: 26,
                                  color: isDark ? Colors.white : primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            //color: Colors.blueAccent,
            child: Scrollbar(
              thickness: GetPlatform.isDesktop ? null : 0,
              controller: scrollController,
              child: ListView.separated(
                  controller: scrollController,
                  addAutomaticKeepAlives: false, //Testing going
                  addRepaintBoundaries: false, //on this
                  physics: const BouncingScrollPhysics(),
                  separatorBuilder: (context, index) => const SizedBox(
                        width: 15,
                      ),
                  scrollDirection: Axis.horizontal,
                  itemCount: isAlbumContent
                      ? content.albumList.length
                      : content.playlistList.length,
                  itemBuilder: (_, index) {
                    if (isAlbumContent) {
                      return ContentListItem(content: content.albumList[index]);
                    }
                    return ContentListItem(
                        content: content.playlistList[index]);
                  }),
            ),
          ),
        ],
      ),
    );
  }
}
