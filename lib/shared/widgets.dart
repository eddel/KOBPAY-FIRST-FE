import "package:flutter/material.dart";
import "../core/theme/app_theme.dart";

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showBack = true,
    this.showAppBar = true,
    this.bottomNavigationBar
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showBack;
  final bool showAppBar;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              automaticallyImplyLeading: showBack,
              title: Text(title),
              actions: actions
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, AppTheme.background],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter
          )
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child
          )
        )
      ),
      bottomNavigationBar: bottomNavigationBar
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex
  });

  final int currentIndex;

  static const List<_NavItem> _items = [
    _NavItem(
      label: "Home",
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      route: "/home"
    ),
    _NavItem(
      label: "Pay",
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      route: "/billers"
    ),
    _NavItem(
      label: "Exchange",
      icon: Icons.swap_horiz_outlined,
      activeIcon: Icons.swap_horiz,
      route: "/exchange"
    ),
    _NavItem(
      label: "Profile",
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      route: "/profile"
    )
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4)
          )
        ],
        border: Border(
          top: BorderSide(color: Colors.black.withOpacity(0.06))
        )
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        iconSize: 24,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == currentIndex) return;
          Navigator.of(context).pushNamedAndRemoveUntil(
            _items[index].route,
            (_) => false
          );
        },
        selectedItemColor: AppTheme.seed,
        unselectedItemColor: Colors.black54,
        items: _items
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.activeIcon),
                label: item.label
              )
            )
            .toList()
      )
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.seed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)
          )
        )
      )
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.ink,
          side: const BorderSide(color: AppTheme.ink),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)
          )
        )
      )
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child
      )
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.trailing
  });

  final String title;
  final String value;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.black54)),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54))
              ]
            ]
          )
        ),
        if (trailing != null) trailing!
      ]
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message))
  );
}
