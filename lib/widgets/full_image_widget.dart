import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../helper/private_file_url.dart';

class FullImageWidget extends StatelessWidget {
  const FullImageWidget({super.key, required this.image});
  final String image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }),
      body: Center(
        // Only used for payment slips -> protected /files route.
        child: Image.network(privateFileUrl(image)),
      ),
    );
  }
}
