import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() {
  runApp(const AkatorWalletApp());
}

class AkatorWalletApp extends StatelessWidget {
  const AkatorWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Akator Wallet',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AkatorColors.primary,
          brightness: Brightness.light,
        ).copyWith(surface: AkatorColors.backgroundSecondary),
        scaffoldBackgroundColor: AkatorColors.backgroundNorm,
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: AkatorColors.textNorm,
          displayColor: AkatorColors.textNorm,
        ),
      ),
      home: const WalletHomeScreen(),
    );
  }
}

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _section1Open = true;
  bool _section2Open = true;
  bool _section3Open = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: WalletTopBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        onSettingsPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
      drawer: WalletMenuDrawer(onClose: () => Navigator.of(context).pop()),
      endDrawer: WalletSettingsDrawer(
        onClose: () => Navigator.of(context).pop(),
      ),
      body: WalletDashboard(
        section1Open: _section1Open,
        section2Open: _section2Open,
        section3Open: _section3Open,
        onSection1Toggle:
            () => setState(() {
              _section1Open = !_section1Open;
            }),
        onSection2Toggle:
            () => setState(() {
              _section2Open = !_section2Open;
            }),
        onSection3Toggle:
            () => setState(() {
              _section3Open = !_section3Open;
            }),
      ),
    );
  }
}

class WalletTopBar extends StatelessWidget implements PreferredSizeWidget {
  const WalletTopBar({
    required this.onMenuPressed,
    required this.onSettingsPressed,
    super.key,
  });

  final VoidCallback onMenuPressed;
  final VoidCallback onSettingsPressed;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      backgroundColor: AkatorColors.backgroundNorm,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 68,
      centerTitle: true,
      leading: Center(
        child: CircleIconButton(
          tooltip: 'Open wallet menu',
          icon: Icons.menu_rounded,
          onPressed: onMenuPressed,
        ),
      ),
      title: DecoratedBox(
        decoration: BoxDecoration(
          color: AkatorColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AkatorColors.appBarDividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Akator Wallet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WalletStyles.headline(color: AkatorColors.textNorm),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: defaultPadding),
          child: CircleIconButton(
            tooltip: 'Open settings',
            icon: Icons.settings_rounded,
            onPressed: onSettingsPressed,
          ),
        ),
      ],
    );
  }
}

class WalletDashboard extends StatelessWidget {
  const WalletDashboard({
    required this.section1Open,
    required this.section2Open,
    required this.section3Open,
    required this.onSection1Toggle,
    required this.onSection2Toggle,
    required this.onSection3Toggle,
    super.key,
  });

  final bool section1Open;
  final bool section2Open;
  final bool section3Open;
  final VoidCallback onSection1Toggle;
  final VoidCallback onSection2Toggle;
  final VoidCallback onSection3Toggle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FavoritesSection(
                    expanded: section1Open,
                    onToggle: onSection1Toggle,
                  ),
                  const SizedBox(height: 16),
                  OverviewSection(
                    expanded: section2Open,
                    onToggle: onSection2Toggle,
                  ),
                  const SizedBox(height: 16),
                  ExploreSection(
                    expanded: section3Open,
                    onToggle: onSection3Toggle,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FavoritesSection extends StatelessWidget {
  const FavoritesSection({
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return WalletSection(
      sectionLabel: 'Section 1',
      title: 'My favorites',
      expanded: expanded,
      onToggle: onToggle,
      child: SizedBox(
        height: 126,
        child: Stack(
          clipBehavior: Clip.none,
          children: const [
            Positioned(left: 108, top: 34, child: CardStub(width: 116)),
            Positioned(left: 62, top: 22, child: CardStub(width: 112)),
            Positioned(left: 18, top: 10, child: CardStub(width: 128)),
            Positioned(right: 12, top: 38, child: FavoriteCardHandle()),
          ],
        ),
      ),
    );
  }
}

class OverviewSection extends StatelessWidget {
  const OverviewSection({
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return WalletSection(
      sectionLabel: 'Section 2',
      title: 'Overview',
      expanded: expanded,
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OverviewChip(label: 'passport/ID'),
              OverviewChip(label: 'health insurance'),
              OverviewChip(label: 'loyalty cards'),
              OverviewChip(label: 'driver license'),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.85,
            children: const [
              OverviewCard(label: 'card 01'),
              OverviewCard(label: 'card 02'),
              OverviewCard(label: 'card 03'),
              OverviewCard(label: 'card 04'),
              OverviewCard(label: 'card 05'),
              AddCardButton(),
            ],
          ),
        ],
      ),
    );
  }
}

class ExploreSection extends StatelessWidget {
  const ExploreSection({
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return WalletSection(
      sectionLabel: 'Section 3',
      title: 'Explore: Security & Data',
      expanded: expanded,
      onToggle: onToggle,
      child: Column(
        children: [
          const ArticleRow(
            title: 'Own cloud storage',
            detail: 'Some text and link to a website: own cloud storage',
          ),
          const SizedBox(height: 10),
          const ArticleRow(
            title: 'On-device storage',
            detail: 'Some text and link to a website: on device storage',
          ),
        ],
      ),
    );
  }
}

class WalletMenuDrawer extends StatelessWidget {
  const WalletMenuDrawer({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: panelWidth(context),
      backgroundColor: AkatorColors.drawerBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            DrawerMenuHeader(onClose: onClose),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                children: const [
                  DrawerDivider(),
                  DrawerSectionTitle('Connections'),
                  SizedBox(height: 14),
                  DrawerPlainItem('Syncthing'),
                  DrawerPlainItem('Proton Drive'),
                  SizedBox(height: 28),
                  DrawerDivider(),
                  DrawerSectionTitle('More'),
                  SizedBox(height: 14),
                  DrawerPlainItem('Discover: why is my data safe?'),
                  DrawerPlainItem('User Settings'),
                  DrawerPlainItem('Security'),
                  DrawerPlainItem('Recovery'),
                  SizedBox(height: 28),
                  DrawerDivider(),
                  DrawerPlainItem('Logout', large: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WalletSettingsDrawer extends StatelessWidget {
  const WalletSettingsDrawer({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: panelWidth(context),
      backgroundColor: AkatorColors.backgroundNorm,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SettingsHeader(onClose: onClose),
            const SizedBox(height: 18),
            const SettingsPanel(
              title: 'View',
              children: [
                SettingsTextTile(
                  title: 'My favorites',
                  lines: ['show / hide', 'add/remove items'],
                ),
                SettingsTextTile(
                  title: 'Overview',
                  lines: ['show / hide', 'sort according to'],
                ),
                SettingsTextTile(
                  title: 'Explore',
                  lines: ['show / hide', 'explore more articles'],
                ),
              ],
            ),
            const SizedBox(height: 18),
            const SettingsPanel(
              title: 'Connection status',
              children: [
                SettingsTextTile(
                  title: 'Syncthing',
                  lines: ['Proton Drive'],
                  showChevron: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DrawerMenuHeader extends StatelessWidget {
  const DrawerMenuHeader({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Akator Wallet', style: WalletStyles.drawerTitle()),
                const SizedBox(height: 12),
                Text('johnDoe@gmail.com', style: WalletStyles.drawerBody()),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close menu',
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: AkatorColors.textInverted,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Wallet Settings',
            style: WalletStyles.hero(color: AkatorColors.textNorm),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Close settings',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class WalletSection extends StatelessWidget {
  const WalletSection({
    required this.sectionLabel,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    super.key,
  });

  final String sectionLabel;
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AkatorColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AkatorColors.appBarDividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: WalletStyles.subheadline(
                      color: AkatorColors.textNorm,
                    ),
                  ),
                ),
                SectionToggleButton(
                  sectionLabel: sectionLabel,
                  expanded: expanded,
                  onPressed: onToggle,
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child:
                  expanded
                      ? Padding(
                        key: ValueKey('$sectionLabel-open'),
                        padding: const EdgeInsets.only(top: 12),
                        child: child,
                      )
                      : const SizedBox.shrink(key: ValueKey('collapsed')),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionToggleButton extends StatelessWidget {
  const SectionToggleButton({
    required this.sectionLabel,
    required this.expanded,
    required this.onPressed,
    super.key,
  });

  final String sectionLabel;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: '${expanded ? 'Collapse' : 'Expand'} $sectionLabel',
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        backgroundColor: AkatorColors.primarySoft,
        foregroundColor: AkatorColors.primaryStrong,
        side: const BorderSide(color: AkatorColors.primaryBorder),
      ),
      onPressed: onPressed,
      icon: AnimatedRotation(
        turns: expanded ? 0.5 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
      ),
    );
  }
}

class CardStub extends StatelessWidget {
  const CardStub({required this.width, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AkatorColors.backgroundSecondary,
        border: Border.all(color: AkatorColors.primary, width: 1.6),
        boxShadow: const [
          BoxShadow(
            color: AkatorColors.loadingShadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(width: width, height: 66),
    );
  }
}

class FavoriteCardHandle extends StatelessWidget {
  const FavoriteCardHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AkatorColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AkatorColors.primaryBorder),
      ),
      child: const SizedBox(
        width: 64,
        height: 28,
        child: Icon(
          Icons.credit_card_rounded,
          size: 18,
          color: AkatorColors.primaryStrong,
        ),
      ),
    );
  }
}

class OverviewChip extends StatelessWidget {
  const OverviewChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AkatorColors.backgroundNorm,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AkatorColors.appBarDividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: WalletStyles.body2Medium(color: AkatorColors.textWeak),
        ),
      ),
    );
  }
}

class OverviewCard extends StatelessWidget {
  const OverviewCard({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: AkatorColors.backgroundNorm,
        foregroundColor: AkatorColors.textNorm,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {},
      child: Text(
        label,
        style: WalletStyles.body1Medium(color: AkatorColors.textNorm),
      ),
    );
  }
}

class AddCardButton extends StatelessWidget {
  const AddCardButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton.filled(
        tooltip: 'Add card',
        style: IconButton.styleFrom(
          fixedSize: const Size(58, 58),
          backgroundColor: AkatorColors.primaryStrong,
          foregroundColor: AkatorColors.textInverted,
        ),
        onPressed: () {},
        icon: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }
}

class ArticleRow extends StatelessWidget {
  const ArticleRow({required this.title, required this.detail, super.key});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AkatorColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox(
            width: 58,
            height: 58,
            child: Icon(Icons.image_outlined, color: AkatorColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: WalletStyles.body1Medium(color: AkatorColors.textNorm),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: WalletStyles.captionRegular(
                  color: AkatorColors.textWeak,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DrawerSectionTitle extends StatelessWidget {
  const DrawerSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Text(text, style: WalletStyles.drawerSection()),
    );
  }
}

class DrawerPlainItem extends StatelessWidget {
  const DrawerPlainItem(this.text, {this.large = false, super.key});

  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: large ? 0 : 8),
      child: Text(
        text,
        style: large ? WalletStyles.drawerSection() : WalletStyles.drawerBody(),
      ),
    );
  }
}

class DrawerDivider extends StatelessWidget {
  const DrawerDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: AkatorColors.drawerTextWeak,
      thickness: 1,
      height: 1,
    );
  }
}

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: WalletStyles.subheadline(color: AkatorColors.textNorm),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AkatorColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsTextTile extends StatelessWidget {
  const SettingsTextTile({
    required this.title,
    required this.lines,
    this.showChevron = true,
    super.key,
  });

  final String title;
  final List<String> lines;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(
        title,
        style: WalletStyles.body1Medium(color: AkatorColors.textNorm),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Text(
                line,
                style: WalletStyles.captionRegular(
                  color: AkatorColors.textWeak,
                ),
              ),
          ],
        ),
      ),
      trailing:
          showChevron
              ? const Icon(
                Icons.chevron_right_rounded,
                color: AkatorColors.textHint,
              )
              : null,
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        backgroundColor: AkatorColors.backgroundSecondary,
        foregroundColor: AkatorColors.primaryStrong,
        side: const BorderSide(color: AkatorColors.appBarDividerColor),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
    );
  }
}

double panelWidth(BuildContext context) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final width = math.min(screenWidth - 44, 390.0);
  return width.clamp(292.0, 390.0).toDouble();
}

const double defaultPadding = 16;

class AkatorColors {
  static const backgroundNorm = Color(0xFFF9FAFB);
  static const backgroundSecondary = Color(0xFFFFFFFF);
  static const textNorm = Color(0xFF111827);
  static const textHint = Color(0xFF6B7280);
  static const textWeak = Color(0xFF4B5563);
  static const textInverted = Color(0xFFFFFFFF);
  static const appBarDividerColor = Color(0xFFE5E7EB);
  static const primary = Color(0xFF3370E4);
  static const primaryStrong = Color(0xFF2563EB);
  static const primarySoft = Color(0xFFEFF6FF);
  static const primaryBorder = Color(0xFFBFDBFE);
  static const loadingShadow = Color(0x223370E4);
  static const drawerBackground = Color(0xFF1E3A8A);
  static const drawerTextWeak = Color(0xFFBFDBFE);
}

class WalletStyles {
  static TextStyle hero({Color? color}) {
    return TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 34 / 28,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle headline({Color? color}) {
    return TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 24 / 22,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle subheadline({Color? color}) {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 24 / 20,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle body1Medium({Color? color}) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 24 / 16,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle body2Medium({Color? color}) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle captionRegular({Color? color}) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle drawerTitle() {
    return const TextStyle(
      color: AkatorColors.textInverted,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: 0,
    );
  }

  static TextStyle drawerSection() {
    return const TextStyle(
      color: AkatorColors.textInverted,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 0,
    );
  }

  static TextStyle drawerBody() {
    return const TextStyle(
      color: AkatorColors.textInverted,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.25,
      letterSpacing: 0,
    );
  }
}
