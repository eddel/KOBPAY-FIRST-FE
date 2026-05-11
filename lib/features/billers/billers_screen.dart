import "package:flutter/material.dart";
import "../../shared/widgets.dart";
import "../../core/theme/app_theme.dart";

class BillersScreen extends StatelessWidget {
  const BillersScreen({super.key});

  static const List<_BillTile> _tiles = [
    _BillTile(label: "Airtime", icon: Icons.phone_android, enabled: true, route: "/airtime"),
    _BillTile(label: "Data", icon: Icons.wifi, enabled: true, route: "/data"),
    _BillTile(label: "Cable TV", icon: Icons.tv, enabled: true, route: "/cable"),
    _BillTile(label: "Electricity", icon: Icons.bolt, enabled: true, route: "/electricity"),
    _BillTile(label: "Betting", icon: Icons.sports_soccer, enabled: false),
    _BillTile(label: "Giftcards", icon: Icons.card_giftcard, enabled: false),
    _BillTile(label: "Flight", icon: Icons.flight_takeoff, enabled: false),
    _BillTile(label: "WAEC/JAMB", icon: Icons.school, enabled: false),
    _BillTile(label: "Airtime2Cash", icon: Icons.swap_horiz, enabled: false)
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Pay Bills",
      showBack: false,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      child: ListView(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _tiles
                .map((tile) => _BillTileCard(
                      tile: tile,
                      onTap: () {
                        if (tile.enabled && tile.route != null) {
                          Navigator.of(context).pushNamed(tile.route!);
                        } else {
                          showMessage(context, "Coming soon");
                        }
                      }
                    ))
                .toList()
          )
        ]
      )
    );
  }
}

class _BillTile {
  const _BillTile({
    required this.label,
    required this.icon,
    required this.enabled,
    this.route
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final String? route;
}

class _BillTileCard extends StatelessWidget {
  const _BillTileCard({
    required this.tile,
    required this.onTap
  });

  final _BillTile tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          tile.icon,
          size: 28,
          color: tile.enabled ? AppTheme.seed : Colors.black45
        ),
        const SizedBox(height: 10),
        Text(
          tile.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tile.enabled ? AppTheme.ink : Colors.black45
              )
        )
      ]
    );

    return Opacity(
      opacity: tile.enabled ? 1 : 0.5,
      child: SizedBox(
        width: (MediaQuery.of(context).size.width - 64) / 2,
        child: SectionCard(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: content
            )
          )
        )
      )
    );
  }
}
