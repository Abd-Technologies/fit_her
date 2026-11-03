import 'package:fitness_zone_2/UI/diet_screen/client_details_screen.dart';
import 'package:fitness_zone_2/data/controllers/home_controller/home_controller.dart';
import 'package:fitness_zone_2/data/models/get_clients_diet.dart';
import 'package:fitness_zone_2/values/my_imgs.dart';
import 'package:fitness_zone_2/widgets/app_bar_widget.dart';
import 'package:fitness_zone_2/widgets/circular_progress.dart';
import 'package:fitness_zone_2/widgets/custom_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../data/controllers/diet_contoller/diet_controller.dart';
import '../chat/widgets/chat_room.dart';

// v2 tokens — same palette as dietitian_home_screen.dart / flagged_
// reviews_screen.dart, so this list finally looks like the rest of the
// dietitian_v2 module instead of a plain ListTile dump.
const Color _kBg = Color(0xFFE8F4E0);
const Color _kInk = Color(0xFF163220);
const Color _kInkSoft = Color(0xFF6F8B7A);
const Color _kBorder = Color(0xFFD8EDD4);

class _StatusStyle {
  final String label;
  final Color fg;
  final Color bg;
  const _StatusStyle(this.label, this.fg, this.bg);
}

// Mirrors the priority order the backend sorts by (getAllClients in
// dietController.js) — flagged and today's consultations always float
// to the top regardless of when the client bought their plan.
const Map<String, _StatusStyle> _kStatusStyles = {
  'FLAGGED': _StatusStyle('Needs attention', Color(0xFFC24B4B), Color(0xFFFBEAEA)),
  'CONSULTATION_TODAY': _StatusStyle('Consultation today', Color(0xFF3D8F4F), Color(0xFFE3F3E3)),
  'PLAN_OVERDUE': _StatusStyle('Plan overdue', Color(0xFFC77B2B), Color(0xFFFBEBD8)),
  'AWAITING_PLAN': _StatusStyle('Plan due soon', Color(0xFF3B6FA0), Color(0xFFE3EEF7)),
  'ON_TRACK': _StatusStyle('On track', Color(0xFF4E9F3D), Color(0xFFE4F3DE)),
  'NEW': _StatusStyle('No consultation yet', Color(0xFF6F8B7A), Color(0xFFEFF3EF)),
  'PLAN_ENDED': _StatusStyle('Plan ended', Color(0xFF8A8F87), Color(0xFFEDEFEA)),
};

_StatusStyle _styleFor(String? status) =>
    _kStatusStyles[status] ?? _kStatusStyles['ON_TRACK']!;

class ClientsScreen extends StatefulWidget {
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final DietController dietController = Get.find();
  final HomeController homeController = Get.find();
  final TextEditingController searchController = TextEditingController();

  String searchQuery = "";

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: HelpingWidgets().appBarWidget(() {
        Get.back();
      }, text: "Clients", backGroundColor: _kBg),
      body: Obx(() {
        if (!dietController.clientDataLoad.value) {
          return const CircularProgress();
        }

        final clients = dietController.getDietClientsModel!.cliets.where((client) {
          final name = "${client.user?.firstName ?? ''} ${client.user?.lastName ?? ''}".toLowerCase();
          return name.contains(searchQuery.toLowerCase());
        }).toList();

        final needsAttention = clients
            .where((c) => c.status == 'FLAGGED' || c.status == 'CONSULTATION_TODAY' || c.status == 'PLAN_OVERDUE')
            .length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: CustomTextField(
                  background: Colors.white,
                  height: 48,
                  text: "Search clients...",
                  length: 100,
                  keyboardType: TextInputType.text,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  icon: const Icon(Icons.search),
                  inputFormatters: FilteringTextInputFormatter.singleLineFormatter),
            ),
            if (needsAttention > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$needsAttention client${needsAttention == 1 ? '' : 's'} need${needsAttention == 1 ? 's' : ''} something from you today',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC77B2B),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: clients.isEmpty
                  ? const Center(
                      child: Text(
                        'No clients found',
                        style: TextStyle(fontFamily: 'Poppins', color: _kInkSoft),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                      itemCount: clients.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final client = clients[index];
                        return _ClientCard(
                          client: client,
                          onTap: () {
                            if (client.user != null) {
                              Get.to(() => ClientDetailsScreen(
                                    clientUser: client.user!,
                                    planId: client.id,
                                  ));
                            }
                          },
                          onMessage: () async {
                            if (client.user != null) {
                              var userDetail = client.user!.id.toString();
                              var userMap = await homeController.getspecificUserFromFireStore(userDetail);
                              var roomId = await homeController.makeRoomId(userDetail);

                              Get.to(() => ChatRoom(
                                    title: "Message to ${client.user?.firstName} ${client.user?.lastName}",
                                    chatRoomId: roomId,
                                    userMap: userMap,
                                  ));
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Cliet client;
  final VoidCallback onTap;
  final VoidCallback onMessage;

  const _ClientCard({
    required this.client,
    required this.onTap,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(client.status);
    final name = "${client.user?.firstName ?? ''} ${client.user?.lastName ?? ''}".trim();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (client.status == 'FLAGGED' || client.status == 'CONSULTATION_TODAY')
                ? style.fg
                : _kBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: _kInk.withOpacity(0.04),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundImage: AssetImage(MyImgs.avatar),
              radius: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Client' : name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: style.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      style.label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: style.fg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Plan: ${DateFormat("MMM d").format(client.buyingDate)} – ${DateFormat("MMM d").format(client.expireDate)}",
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _kInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: _kInkSoft),
              onPressed: onMessage,
            ),
          ],
        ),
      ),
    );
  }
}
