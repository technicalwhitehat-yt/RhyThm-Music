import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/models/quick_picks.dart';
import '../navigator.dart';
import '../player/player_controller.dart';
import 'image_widget.dart';
import 'songinfo_bottom_sheet.dart';

class QuickPicksWidget extends StatelessWidget {
  const QuickPicksWidget(
      {super.key, required this.content, this.scrollController});
  final QuickPicks content;
  final ScrollController? scrollController;

  String _formatTitle(String rawTitle) {
    if (rawTitle.isEmpty) return "Quick Picks";
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

    final trVal = lowerNoSpace.tr;
    if (trVal != lowerNoSpace && trVal.isNotEmpty) {
      return trVal;
    }

    if (!trimmed.contains(' ') && RegExp(r'[a-z][A-Z]').hasMatch(trimmed)) {
      return trimmed.replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();
    final titleText = _formatTitle(content.title);
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: SizedBox(
        height: 340,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0, right: 18.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        titleText,
                        style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
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
          Expanded(
            child: Scrollbar(
              thickness: GetPlatform.isDesktop ? null : 0,
              controller: scrollController,
              child: GridView.builder(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  itemCount: content.songList.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: .26 / 1,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 5,
                  ),
                  itemBuilder: (_, item) {
                    return Listener(
                      onPointerDown: (PointerDownEvent event) {
                        if (event.buttons == kSecondaryMouseButton) {
                          //show songinfobotomsheet
                          showModalBottomSheet(
                            constraints: const BoxConstraints(maxWidth: 500),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10.0)),
                            ),
                            isScrollControlled: true,
                            context: playerController
                                .homeScaffoldkey.currentState!.context,
                            barrierColor: Colors.transparent.withAlpha(100),
                            builder: (context) => SongInfoBottomSheet(
                              content.songList[item],
                            ),
                          ).whenComplete(
                              () => Get.delete<SongInfoController>());
                        }
                      },
                      child: ListTile(
                          contentPadding: const EdgeInsets.only(left: 5),
                          leading: ImageWidget(
                            song: content.songList[item],
                            size: 55,
                          ),
                          title: Text(
                            content.songList[item].title,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            "${content.songList[item].artist}",
                            maxLines: 1,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          onTap: () {
                            playerController
                                .pushSongToQueue(content.songList[item]);
                          },
                          onLongPress: () {
                            showModalBottomSheet(
                              constraints: const BoxConstraints(maxWidth: 500),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(10.0)),
                              ),
                              isScrollControlled: true,
                              context: playerController
                                  .homeScaffoldkey.currentState!.context,
                              //constraints: BoxConstraints(maxHeight:Get.height),
                              barrierColor: Colors.transparent.withAlpha(100),
                              builder: (context) =>
                                  SongInfoBottomSheet(content.songList[item]),
                            ).whenComplete(
                                () => Get.delete<SongInfoController>());
                          },
                          trailing: (GetPlatform.isDesktop)
                              ? IconButton(
                                  splashRadius: 20,
                                  onPressed: () {
                                    showModalBottomSheet(
                                      constraints:
                                          const BoxConstraints(maxWidth: 500),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(10.0)),
                                      ),
                                      isScrollControlled: true,
                                      context: playerController.homeScaffoldkey
                                          .currentState!.context,
                                      //constraints: BoxConstraints(maxHeight:Get.height),
                                      barrierColor:
                                          Colors.transparent.withAlpha(100),
                                      builder: (context) => SongInfoBottomSheet(
                                          content.songList[item]),
                                    ).whenComplete(
                                        () => Get.delete<SongInfoController>());
                                  },
                                  icon: const Icon(Icons.more_vert))
                              : null),
                    );
                  }),
            ),
          ),
          const SizedBox(height: 20)
        ],
      ),
    ));
  }
}
