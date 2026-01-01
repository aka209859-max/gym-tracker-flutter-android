import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gym_match/gen/app_localizations.dart';
import '../providers/gym_provider.dart';
import '../models/gym.dart';
import 'gym_detail_screen.dart';

/// ジム一覧画面
class GymListScreen extends StatefulWidget {
  const GymListScreen({super.key});

  @override
  State<GymListScreen> createState() => _GymListScreenState();
}

class _GymListScreenState extends State<GymListScreen> {
  String _sortBy = 'rating'; // 'rating', 'crowd', 'price'

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gymList),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rating',
                child: Row(
                  children: [
                    Icon(Icons.star, size: 20),
                    SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.sortByRating),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'crowd',
                child: Row(
                  children: [
                    Icon(Icons.people, size: 20),
                    SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.sortByCrowd),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'price',
                child: Row(
                  children: [
                    Icon(Icons.attach_money, size: 20),
                    SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.sortByPrice),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<GymProvider>(
        builder: (context, provider, child) {
          var gyms = List<Gym>.from(provider.gyms);

          // ソート処理
          switch (_sortBy) {
            case 'rating':
              gyms.sort((a, b) => b.rating.compareTo(a.rating));
              break;
            case 'crowd':
              gyms.sort((a, b) => a.currentCrowdLevel.compareTo(b.currentCrowdLevel));
              break;
            case 'price':
              gyms.sort((a, b) => a.monthlyFee.compareTo(b.monthlyFee));
              break;
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: gyms.length,
            itemBuilder: (context, index) {
              return _buildGymListTile(gyms[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildGymListTile(Gym gym) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GymDetailScreen(gym: gym),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ジム画像
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                gym.imageUrl,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 160,
                    color: Colors.grey[300],
                    child: const Icon(Icons.fitness_center, size: 48),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ジム名
                  Text(
                    gym.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 評価
                  Row(
                    children: [
                      const Icon(Icons.star, size: 20, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${gym.rating}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' (${gym.reviewCount}件)',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 住所
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          gym.address,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 料金
                  Row(
                    children: [
                      Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '月額 ¥${gym.monthlyFee.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 混雑度インジケーター
                  _buildCrowdIndicator(gym),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrowdIndicator(Gym gym) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color(gym.crowdLevelColor).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Color(gym.crowdLevelColor),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people,
            size: 16,
            color: Color(gym.crowdLevelColor),
          ),
          const SizedBox(width: 6),
          Text(
            '現在の混雑度: ${gym.crowdLevelText}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(gym.crowdLevelColor),
            ),
          ),
        ],
      ),
    );
  }
}
