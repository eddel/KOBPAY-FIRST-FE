import "dart:async";
import "dart:convert";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../core/theme/app_theme.dart";
import "../../shared/helpers.dart";
import "../../shared/in_app_browser.dart";
import "../../shared/widgets.dart";
import "../../store/session_store.dart";
import "../transactions/exchange_transaction_detail_screen.dart";
import "../transactions/transaction_detail_screen.dart";
import "../wallet/fund_sheet.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showBalance = true;
  final PageController _bannerController = PageController(viewportFraction: 0.92);
  Timer? _bannerTimer;
  int _bannerIndex = 0;
  List<_DashboardBanner> _banners = [];

  @override
  void initState() {
    super.initState();
    _startBannerTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = context.read<SessionStore>();
      try {
        await session.fetchBanners();
        if (session.wallet == null) {
          await session.fetchWallet();
        }
        await session.fetchRecentTransactions(limit: 5);
      } catch (err) {
        if (mounted) {
          showMessage(context, err.toString());
        }
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = Provider.of<SessionStore>(context);
    final nextBanners = _mapBanners(session.banners);
    if (!_sameBanners(_banners, nextBanners)) {
      _banners = nextBanners;
      _bannerIndex = 0;
      _startBannerTimer();
    }
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    if (_banners.length < 2) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      final nextIndex = (_bannerIndex + 1) % _banners.length;
      _bannerController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut
      );
    });
  }

  Future<void> _refresh(SessionStore session) async {
    try {
      await session.fetchBanners();
      await session.fetchWallet();
      await session.fetchRecentTransactions(limit: 5);
    } catch (err) {
      if (mounted) {
        showMessage(context, err.toString());
      }
    }
  }

  Future<void> _openBanner(_DashboardBanner banner) async {
    if (banner.linkUrl == null || banner.linkUrl!.isEmpty) return;
    if (mounted) {
      await openInAppBrowser(context, banner.linkUrl!);
    }
  }

  List<_DashboardBanner> _mapBanners(List<Map<String, dynamic>>? raw) {
    if (raw == null) return [];
    return raw
        .map(
          (entry) => _DashboardBanner(
            id: entry["id"]?.toString() ?? "",
            title: entry["title"]?.toString(),
            subtitle: entry["subtitle"]?.toString(),
            imageUrl: entry["imageUrl"]?.toString() ?? "",
            linkUrl: entry["linkUrl"]?.toString()
          )
        )
        .where((banner) => banner.imageUrl.isNotEmpty)
        .toList();
  }

  bool _sameBanners(List<_DashboardBanner> current, List<_DashboardBanner> next) {
    if (current.length != next.length) return false;
    for (int i = 0; i < current.length; i++) {
      if (current[i].id != next[i].id ||
          current[i].imageUrl != next[i].imageUrl) {
        return false;
      }
    }
    return true;
  }

  String _firstName(Map<String, dynamic>? user) {
    final name = pickString(
      user ?? <String, dynamic>{},
      ["name", "fullName", "firstName", "username"]
    ).trim();
    if (name.isEmpty) return "";
    return name.split(" ").first;
  }

  String _formatTxDate(dynamic raw) {
    if (raw == null) return "";
    DateTime? parsed;
    if (raw is DateTime) {
      parsed = raw;
    } else if (raw is String) {
      parsed = DateTime.tryParse(raw);
    }
    if (parsed == null) return raw.toString();
    final time = _formatTime(parsed);
    final date =
        "${_monthName(parsed.month)} ${parsed.day}, ${parsed.year}";
    return "$time - $date";
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, "0");
    final suffix = date.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $suffix";
  }

  String _monthName(int month) {
    const names = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    if (month < 1 || month > names.length) return "";
    return names[month - 1];
  }

  bool _isCredit(Map<String, dynamic> tx) {
    final type = tx["type"]?.toString().toLowerCase() ?? "";
    return type.contains("credit");
  }

  IconData _iconForCategory(String category) {
    final value = category.toLowerCase();
    if (value.contains("airtime")) return Icons.phone_android;
    if (value.contains("data")) return Icons.wifi;
    if (value.contains("cable") || value.contains("tv")) return Icons.tv;
    if (value.contains("electric")) return Icons.bolt;
    if (value.contains("wallet") || value.contains("fund")) {
      return Icons.account_balance_wallet;
    }
    if (value.contains("exchange")) return Icons.currency_exchange;
    if (value.contains("gift")) return Icons.card_giftcard;
    return Icons.receipt_long;
  }

  ImageProvider? _profileImageProvider(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith("data:image")) {
      final parts = url.split(",");
      if (parts.length < 2) return null;
      try {
        return MemoryImage(base64Decode(parts.last));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final user = session.user;
    final wallet = session.wallet;
    final balanceKobo = (wallet?["balanceKobo"] as int?) ?? 0;
    final currency = (wallet?["currency"] as String?) ?? "NGN";
    final name = _firstName(user);
    final displayName = name.isEmpty ? "there" : name;
    final photoUrl = pickString(
      user ?? <String, dynamic>{},
      ["photoUrl", "avatarUrl", "imageUrl", "profileImageUrl"]
    );
    final profileImage = _profileImageProvider(photoUrl);
    final transactions = session.recentTransactions ?? [];
    final walletLoading = wallet == null;
    final transactionsLoading = session.recentTransactions == null;
    final hasBanners = _banners.isNotEmpty;
    final balanceText = _showBalance
        ? formatKobo(balanceKobo, currency: currency)
        : "${currency.toUpperCase()} \u2022\u2022\u2022\u2022\u2022";

    return AppScaffold(
      title: "",
      showBack: false,
      showAppBar: false,
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      child: RefreshIndicator(
        onRefresh: () => _refresh(session),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _HeaderRow(
              name: displayName,
              profileImage: profileImage,
              onBellTap: () => showMessage(context, "Notifications coming soon")
            ),
            const SizedBox(height: 16),
            if (walletLoading)
              const _BalanceSkeletonCard()
            else
              _BalanceCard(
                balanceText: balanceText,
                showBalance: _showBalance,
                onToggle: () => setState(() => _showBalance = !_showBalance),
                onFund: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const FundWalletSheet()
                  );
                }
              ),
            const SizedBox(height: 20),
            const _SectionHeader(title: "Quick Links"),
            const SizedBox(height: 12),
            _QuickLinksRow(
              items: [
                _QuickLinkItem(
                  label: "Airtime",
                  icon: Icons.phone_android,
                  onTap: () => Navigator.of(context).pushNamed("/airtime")
                ),
                _QuickLinkItem(
                  label: "Data",
                  icon: Icons.wifi,
                  onTap: () => Navigator.of(context).pushNamed("/data")
                ),
                _QuickLinkItem(
                  label: "Electricity",
                  icon: Icons.bolt,
                  onTap: () => Navigator.of(context).pushNamed("/electricity")
                ),
                _QuickLinkItem(
                  label: "More",
                  icon: Icons.more_horiz,
                  onTap: () => Navigator.of(context).pushNamed("/billers")
                )
              ]
            ),
            const SizedBox(height: 20),
            if (hasBanners) ...[
              const _SectionHeader(title: "Highlights"),
              const SizedBox(height: 12),
              _BannerCarousel(
                controller: _bannerController,
                banners: _banners,
                index: _bannerIndex,
                onChanged: (index) => setState(() => _bannerIndex = index),
                onTap: _openBanner
              ),
              const SizedBox(height: 20),
            ],
            _SectionHeader(
              title: "Transactions",
              actionLabel: "View all >",
              onAction: () => Navigator.of(context).pushNamed("/transactions")
            ),
            const SizedBox(height: 12),
            if (transactionsLoading)
              const _TransactionsSkeleton()
            else if (transactions.isEmpty)
              Text(
                "No transactions yet",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.black54)
              )
            else
              ...transactions.take(4).map((tx) {
                final isFunding = isWalletFunding(tx);
                final title = isFunding
                    ? "Deposit"
                    : pickString(tx, [
                        "title",
                        "category",
                        "provider",
                        "reference"
                      ], "Transaction");
                final amount = tx["amountKobo"] as int? ?? 0;
                final isCredit = _isCredit(tx);
                final amountText =
                    "${isCredit ? "+" : "-"}${formatKobo(amount, currency: currency)}";
                final dateText = _formatTxDate(tx["createdAt"]);
                final status = formatStatusLabel(
                    pickString(tx, ["status", "state"], "unknown"));
                final icon =
                    _iconForCategory(tx["category"]?.toString() ?? "");
                final meta = asStringKeyMap(tx["metaJson"]);
                final isExchange =
                    (tx["category"]?.toString() ?? "") == "exchange";
                final canOpenExchangeDetail = isExchange && meta["tradeId"] != null;
                final VoidCallback? onTap = canOpenExchangeDetail
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExchangeTransactionDetailScreen(
                              transaction: tx
                            )
                          )
                        )
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TransactionDetailScreen(
                              transaction: tx
                            )
                          )
                        );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TransactionTile(
                    title: title,
                    subtitle: dateText,
                    amount: amountText,
                    status: status,
                    isCredit: isCredit,
                    icon: icon,
                    onTap: onTap
                  )
                );
              })
          ]
        )
      )
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.seed,
                    fontWeight: FontWeight.w600
                  )
            )
          )
      ]
    );
  }
}

class _BalanceSkeletonCard extends StatelessWidget {
  const _BalanceSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stone),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6)
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonLine(width: 140, height: 14),
          SizedBox(height: 12),
          _SkeletonLine(width: 200, height: 26),
          SizedBox(height: 14),
          _SkeletonLine(width: 120, height: 36)
        ]
      )
    );
  }
}

class _TransactionsSkeleton extends StatelessWidget {
  const _TransactionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _TransactionSkeletonRow(),
        SizedBox(height: 12),
        _TransactionSkeletonRow(),
        SizedBox(height: 12),
        _TransactionSkeletonRow()
      ]
    );
  }
}

class _TransactionSkeletonRow extends StatelessWidget {
  const _TransactionSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stone)
      ),
      child: Row(
        children: const [
          _SkeletonCircle(size: 44),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(width: 140, height: 14),
                SizedBox(height: 8),
                _SkeletonLine(width: 200, height: 12)
              ]
            )
          ),
          SizedBox(width: 12),
          _SkeletonLine(width: 60, height: 14)
        ]
      )
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.stone.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12)
      )
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppTheme.stone.withOpacity(0.7),
        shape: BoxShape.circle
      )
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.name,
    required this.profileImage,
    required this.onBellTap
  });

  final String name;
  final ImageProvider? profileImage;
  final VoidCallback onBellTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.stone,
          backgroundImage: profileImage,
          child: profileImage == null
              ? const Icon(Icons.person, color: AppTheme.ink)
              : null
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome,",
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.black54)
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)
              )
            ]
          )
        ),
        IconButton(
          onPressed: onBellTap,
          icon: const Icon(Icons.notifications_none)
        )
      ]
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balanceText,
    required this.showBalance,
    required this.onToggle,
    required this.onFund
  });

  final String balanceText;
  final bool showBalance;
  final VoidCallback onToggle;
  final VoidCallback onFund;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stone),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6)
          )
        ]
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Available Balance",
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.black54)
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ScaleDownText(
                        text: balanceText,
                        alignment: Alignment.centerLeft,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)
                      ),
                    ),
                    IconButton(
                      onPressed: onToggle,
                      icon: Icon(
                        showBalance ? Icons.visibility : Icons.visibility_off,
                        color: AppTheme.seed
                      )
                    )
                  ]
                )
              ]
            )
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onFund,
            child: const Text("+ Fund Wallet"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.seed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)
              )
            )
          )
        ]
      )
    );
  }
}

class _QuickLinkItem {
  const _QuickLinkItem({
    required this.label,
    required this.icon,
    required this.onTap
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _QuickLinksRow extends StatelessWidget {
  const _QuickLinksRow({
    required this.items
  });

  final List<_QuickLinkItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int index = 0; index < items.length; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == items.length - 1 ? 0 : 12
              ),
              child: _QuickLinkTile(
                label: items[index].label,
                icon: items[index].icon,
                onTap: items[index].onTap
              )
            )
          )
      ]
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.label,
    required this.icon,
    required this.onTap
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.seed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.seed.withOpacity(0.12))
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: Icon(icon, color: AppTheme.seed, size: 18)
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600
                      )
                )
              ]
            )
          )
        )
      )
    );
  }
}

class _DashboardBanner {
  const _DashboardBanner({
    required this.id,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.linkUrl
  });

  final String id;
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final String? linkUrl;
}

class _BannerCarousel extends StatelessWidget {
  const _BannerCarousel({
    required this.controller,
    required this.banners,
    required this.index,
    required this.onChanged,
    required this.onTap
  });

  final PageController controller;
  final List<_DashboardBanner> banners;
  final int index;
  final ValueChanged<int> onChanged;
  final ValueChanged<_DashboardBanner> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: controller,
            itemCount: banners.length,
            onPageChanged: onChanged,
            padEnds: false,
            itemBuilder: (context, bannerIndex) {
              final banner = banners[bannerIndex];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _BannerTile(
                  banner: banner,
                  onTap: () => onTap(banner)
                )
              );
            }
          )
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (dotIndex) {
            final active = dotIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: active ? 18 : 8,
              decoration: BoxDecoration(
                color: active ? AppTheme.seed : Colors.black26,
                borderRadius: BorderRadius.circular(12)
              )
            );
          })
        )
      ]
    );
  }
}

class _BannerTile extends StatelessWidget {
  const _BannerTile({
    required this.banner,
    required this.onTap
  });

  final _DashboardBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 8)
              )
            ]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              banner.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.stone.withOpacity(0.4)
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: AppTheme.stone.withOpacity(0.3)
                );
              }
            )
          )
        )
      )
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.isCredit,
    required this.icon,
    this.onTap
  });

  final String title;
  final String subtitle;
  final String amount;
  final String status;
  final bool isCredit;
  final IconData icon;
  final VoidCallback? onTap;

  Color _statusColor(String value) {
    final status = value.toLowerCase();
    if (status.contains("success") || status.contains("completed")) {
      return Colors.green;
    }
    if (status.contains("pending") || status.contains("processing")) {
      return Colors.orange;
    }
    if (status.contains("fail") || status.contains("reversed")) {
      return Colors.redAccent;
    }
    return Colors.black45;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.stone)
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rawAmountWidth = constraints.maxWidth * 0.32;
              final amountWidth =
                  rawAmountWidth.clamp(72.0, 140.0) as double;
              return Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Icon(icon, color: AppTheme.seed)
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)
                              )
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.w600)
                              )
                            )
                          ]
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black54)
                        )
                      ]
                    )
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: amountWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _ScaleDownText(
                        text: amount,
                        alignment: Alignment.centerRight,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color:
                                  isCredit ? Colors.green : Colors.redAccent,
                              fontWeight: FontWeight.w700
                            )
                      )
                    )
                  )
                ]
              );
            }
          )
        )
      )
    );
  }
}

class _ScaleDownText extends StatelessWidget {
  const _ScaleDownText({
    required this.text,
    required this.style,
    this.alignment = Alignment.centerLeft,
    this.maxLines = 1,
    this.textAlign
  });

  final String text;
  final TextStyle? style;
  final Alignment alignment;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        maxLines: maxLines,
        softWrap: false,
        overflow: TextOverflow.visible,
        textAlign: textAlign,
        style: style
      )
    );
  }
}
