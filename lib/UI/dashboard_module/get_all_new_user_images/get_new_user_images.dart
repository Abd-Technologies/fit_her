import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/widgets/circular_progress.dart';
import 'package:fitness_zone_2/widgets/custom_button.dart';
import 'package:fitness_zone_2/widgets/full_image_widget.dart';
import 'package:fitness_zone_2/helper/private_file_url.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../../values/constants.dart';
import '../../../values/slip_reject_reasons.dart';
import '../../../values/my_colors.dart';
import '../../../widgets/app_bar_widget.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AllNewUserImages extends StatelessWidget {
  AllNewUserImages({Key? key}) : super(key: key);
  final HomeController homeController = Get.find();

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }, text: "All New Users"),
      body: Column(
        children: [
          Expanded(
              child: Obx(
            () => homeController.getPlanImagesLoad.value
                ? GetBuilder<HomeController>(
                    id: "newList",
                    builder: (cont) {
                      return ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemBuilder: (BuildContext context, int index) {
                          var plan =
                              homeController.getAllPlansImages!.data[index];
                          var user = homeController
                              .getAllPlansImages!.data[index].user;

                          return Container(
                            padding: EdgeInsets.all(20.h),
                            decoration: BoxDecoration(
                                color: MyColors.appBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.black.withOpacity(0.6))),
                            child: Column(children: [
                              if (plan.image != null)
                                GestureDetector(
                                  onTap: () {
                                    Get.to(() =>
                                        FullImageWidget(image: plan.image!));
                                  },
                                  child: Container(
                                    height: 200.h,
                                    margin: EdgeInsets.only(bottom: 20.h),
                                    decoration: BoxDecoration(
                                        image: DecorationImage(
                                            image: NetworkImage(
                                                privateFileUrl(plan.image!)),
                                            fit: BoxFit.cover)),
                                  ),
                                ),

                              reportRow(
                                  "Name",
                                  "${user?.firstName} ${user?.lastName}",
                                  context),
                              reportRow("Email", user?.email ?? "", context),
                              reportRow(
                                  "Phone No.", user?.phone ?? "", context),
                              // reportRow("Phone no", user.phone, context),
                              reportRow(
                                  "Plan Name",
                                  plan.plan == null ? "N/A" : plan.plan!.title,
                                  context),
                              reportRow(
                                  "Sales Representative",
                                  user?.supporter != null
                                      ? "${user?.supporter!.firstName} ${user?.supporter?.lastName} "
                                      : "",
                                  context),
                              reportRow(
                                  "Plan Duration",
                                  plan.plan == null
                                      ? "N/A"
                                      : (plan.priceDuration?.duration ?? "N/A"),
                                  context),
                              // Slip check: why it's waiting for you.
                              _slipCheck(plan),
                              SizedBox(
                                height: 20.h,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomButton(
                                        text: "Approve",
                                        onPressed: () {
                                          homeController
                                              .approveUser(plan.id.toString(),false);
                                        }),
                                  ),
                                  SizedBox(width: 10,),
                                  Expanded(
                                    child: CustomButton(
                                        text: "Reject",
                                        color:Colors.red,
                                        onPressed: () async {
                                          // Oct 2026: pick a reason first.
                                          final reason = await pickSlipRejectReason(context);
                                          if (reason == null) return;
                                          homeController.approveUser(
                                              plan.id.toString(), true,
                                              reason: reason);
                                        }),
                                  ),
                                ],
                              )
                              // reportRow("Current Day Weight",
                              //     report.currentWeight, context),
                              // reportRow("Waist", report.weist, context),
                              // reportRow("Shoulder", report.shoulder, context),
                              // reportRow("Arms", report.arms, context),
                              // reportRow("Chest", report.chest, context),
                              // reportRow("Abdomen", report.abdoman, context),
                              // reportRow("Hips", report.hips, context),
                              // reportRow("Thighs", report.thighs, context),
                            ]),
                          );
                        },
                        itemCount:
                            homeController.getAllPlansImages!.data.length,
                        separatorBuilder: (BuildContext context, int index) {
                          return SizedBox(
                            height: 20.h,
                          );
                        },
                      );
                    })
                : CircularProgress(),
          ))
        ],
      ),
    );
  }

  Widget reportRow(String text1, String text2, context) {
    var textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          // crossAxisAlignment: CrossAxisAlignment.start,
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                text1,
                style: textTheme.bodyMedium!.copyWith(
                    color: MyColors.textColor.withOpacity(0.6),
                    fontWeight: FontWeight.w400),
              ),
            ),
            Expanded(
              child: Text(
                text2,
                style: textTheme.bodySmall!.copyWith(
                    color: MyColors.textColor, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 5.h,
        )
      ],
    );
  }

  /// What the automatic slip check found (account, date, reference, amount)
  /// and why it's waiting for the admin.
  Widget _slipCheck(dynamic p) {
    final String? reason = p.slipReason;
    final Map<String, dynamic>? acc = p.slipAccount;
    final Map<String, dynamic>? data = p.ocrData;
    if (data == null) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFDF3DF), borderRadius: BorderRadius.circular(12)),
        child: const Text('Slip could not be read automatically. Please check it by eye.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Color(0xFF7A4E0E))),
      );
    }
    Widget row(String k, String? v, bool? ok) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ok == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 16, color: ok == true ? const Color(0xFF4E9F3D) : const Color(0xFFC77B2B)),
            const SizedBox(width: 6),
            SizedBox(width: 84, child: Text(k, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF66705F)))),
            Expanded(child: Text(v == null || v.isEmpty ? 'not found' : v, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600))),
          ]),
        );
    final checks = data['checks'] is Map ? Map<String, dynamic>.from(data['checks']) : const <String, dynamic>{};
    final accText = acc == null ? null : '${acc['title']} · ${acc['provider']} …${acc['last4']}';
    final amt = p.ocrAmount == null ? null : 'PKR ${p.ocrAmount} (price PKR ${p.price ?? '-'})';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E8DE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Slip check', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700)),
        row('Our account', accText, checks['account'] as bool?),
        row('Date', data['slipDate']?.toString() ?? p.ocrDate, checks['date'] as bool?),
        row('Reference', p.ocrTransactionId, checks['reference'] as bool?),
        row('Amount', amt, checks['amount'] as bool?),
        if (reason != null) ...[
          const SizedBox(height: 6),
          Text(reason, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF7A4E0E))),
        ],
      ]),
    );
  }
}
