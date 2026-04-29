import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../widgets/provisioning/provisioning_tab.dart';
import 'manage_pilgrims_screen.dart';

class PilgrimProvisioningScreen extends StatelessWidget {
  const PilgrimProvisioningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: 'provision_tab_provision'.tr()),
              Tab(text: 'provision_tab_manage'.tr()),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ProvisioningTab(),
            ManagePilgrimsScreen(),
          ],
        ),
      ),
    );
  }
}
