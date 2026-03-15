import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../theme/app_colors.dart';

class MLDetailsScreen extends StatefulWidget {
  final String token;
  const MLDetailsScreen({super.key, required this.token});

  @override
  State<MLDetailsScreen> createState() => _MLDetailsScreenState();
}

class _MLDetailsScreenState extends State<MLDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  int _tab = 0;
  final List<String> _tabs = [
    'DATASET',
    'RANDOM FOREST',
    'AUTOENCODER',
    'VAE',
    'SHAP / XAI',
  ];

  // ── Fetch state ──────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _info; // full /model-info response

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _fetchInfo();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Fetch /model-info ─────────────────────────────────────────
  Future<void> _fetchInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final base = await ApiConfig.getBaseUrl();
      final res = await http
          .get(
            Uri.parse('$base/model-info'),
            headers: {'Authorization': 'Bearer ${widget.token}'},
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        setState(() {
          _info = jsonDecode(res.body) as Map<String, dynamic>;
          _loading = false;
        });
        _fadeCtrl.forward();
      } else {
        setState(() {
          _error = 'Server error ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _switchTab(int i) {
    if (i == _tab) return;
    _fadeCtrl.reset();
    setState(() => _tab = i);
    _fadeCtrl.forward();
  }

  // ── Convenience getters ───────────────────────────────────────
  Map<String, dynamic> get _rf =>
      (_info?['random_forest'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get _ae =>
      (_info?['autoencoder'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get _vae =>
      (_info?['vae'] as Map?)?.cast<String, dynamic>() ?? {};

  String _fmt(dynamic v, {String suffix = '%', String fallback = 'N/A'}) {
    if (v == null) return fallback;
    return '${v}$suffix';
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textSecond,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ML MODEL DETAILS',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            onPressed: _loading ? null : _fetchInfo,
            tooltip: 'Refresh from backend',
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
            ),
            child: const Text(
              'v1.0',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? _buildLoader()
          : _error != null
          ? _buildErrorView()
          : Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: _buildTabContent(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Loading / Error ───────────────────────────────────────────
  Widget _buildLoader() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AppColors.primary),
        const SizedBox(height: 16),
        const Text(
          'Fetching model data from backend...',
          style: TextStyle(color: AppColors.textSecond, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildErrorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _fetchInfo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(
                  color: AppColors.bg,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ── Tab bar ───────────────────────────────────────────────────
  Widget _buildTabBar() => Container(
    color: AppColors.appBar,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final active = _tab == i;
          return GestureDetector(
            onTap: () => _switchTab(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.cardBorder,
                ),
              ),
              child: Text(
                _tabs[i],
                style: TextStyle(
                  color: active ? AppColors.bg : AppColors.textSecond,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildDatasetTab();
      case 1:
        return _buildRFTab();
      case 2:
        return _buildAutoencoderTab();
      case 3:
        return _buildVAETab();
      case 4:
        return _buildShapTab();
      default:
        return _buildDatasetTab();
    }
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 0 — DATASET (static, no backend needed)
  // ══════════════════════════════════════════════════════════════
  Widget _buildDatasetTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(
        Icons.dataset_rounded,
        'CICIDS2017 Dataset',
        'Canadian Institute for Cybersecurity — UNB',
      ),
      _infoCard([
        _infoRow(
          'Full Name',
          'CICIDS 2017 — Intrusion Detection Evaluation Dataset',
        ),
        _infoRow(
          'Source',
          'Canadian Institute for Cybersecurity, Univ. of New Brunswick',
        ),
        _infoRow('Capture Period', '5 days — Monday to Friday, July 2017'),
        _infoRow('Total Flows', '2,830,743 labeled network flows'),
        _infoRow('Features', '78 statistical features per flow'),
        _infoRow('Classification', 'Binary — 0 = BENIGN,  1 = ATTACK'),
        _infoRow('Environment', 'Realistic lab with live attack simulation'),
      ]),
      const SizedBox(height: 20),
      _label('ATTACK CATEGORIES'),
      const SizedBox(height: 10),
      _attackTable([
        ['BENIGN', 'Normal network traffic', '2,273,097', AppColors.success],
        ['DDoS', 'Distributed Denial of Service', '128,027', AppColors.danger],
        [
          'PortScan',
          'Network reconnaissance scanning',
          '158,930',
          AppColors.warning,
        ],
        [
          'BruteForce',
          'FTP / SSH brute force login attempts',
          '13,835',
          AppColors.warning,
        ],
        [
          'WebAttack',
          'SQL Injection, XSS, web brute force',
          '2,180',
          AppColors.danger,
        ],
        [
          'DoS',
          'Slowloris, Hulk, GoldenEye, Slowhttptest',
          '252,661',
          AppColors.danger,
        ],
        [
          'Infiltration',
          'Infiltration + port scan combo',
          '36',
          AppColors.warning,
        ],
        [
          'Heartbleed',
          'OpenSSL Heartbleed vulnerability exploit',
          '11',
          AppColors.danger,
        ],
      ]),
      const SizedBox(height: 20),
      _label('BINARY LABEL MAPPING'),
      const SizedBox(height: 10),
      _infoCard([
        _infoRow('Class 0', 'BENIGN — normal, safe network traffic'),
        _infoRow(
          'Class 1',
          'ATTACK — all 7 attack types merged into one label',
        ),
        _infoRow(
          'Why binary?',
          'Simplifies task: is this flow malicious or not?',
        ),
      ]),
      const SizedBox(height: 20),
      _label('PREPROCESSING PIPELINE'),
      const SizedBox(height: 10),
      _stepCard(1, 'Load CSV', 'Read 78 feature columns + Label column.'),
      _stepCard(2, 'Label Encoding', 'BENIGN → 0, all attack types → 1.'),
      _stepCard(
        3,
        'Handle Infinities',
        'Replace Inf/-Inf with column max/min.',
      ),
      _stepCard(4, 'Fill NaN', 'Replace missing values with column median.'),
      _stepCard(
        5,
        'Train/Test Split',
        '80% train / 20% test. Stratified to preserve class ratio.',
      ),
      _stepCard(
        6,
        'StandardScaler',
        'Fit on train only. Transform both sets. Prevents data leakage.',
      ),
      const SizedBox(height: 20),
      _label('KEY FEATURES (78 TOTAL)'),
      const SizedBox(height: 10),
      _featureGrid([
        'Flow Duration',
        'Total Fwd Packets',
        'Total Bwd Packets',
        'Fwd Packet Length Max',
        'Fwd Packet Length Mean',
        'Bwd Packet Length Max',
        'Flow Bytes/s',
        'Flow Packets/s',
        'Flow IAT Mean',
        'Flow IAT Std',
        'Fwd IAT Mean',
        'Bwd IAT Mean',
        'PSH Flag Count',
        'ACK Flag Count',
        'SYN Flag Count',
        'FIN Flag Count',
        'URG Flag Count',
        'RST Flag Count',
        'Packet Length Mean',
        'Packet Length Std',
        'Average Packet Size',
        'Subflow Fwd Packets',
        'Init Fwd Win Bytes',
        'Init Bwd Win Bytes',
        'Active Mean',
        'Idle Mean',
        'Down/Up Ratio',
        'Fwd Header Length',
      ]),
    ],
  );

  // ══════════════════════════════════════════════════════════════
  // TAB 1 — RANDOM FOREST  (live from backend)
  // ══════════════════════════════════════════════════════════════
  Widget _buildRFTab() {
    final hasMetrics = _rf['accuracy'] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.account_tree_rounded,
          'Random Forest Classifier',
          'Supervised binary classification — sklearn',
        ),
        _label('ACTUAL MODEL PARAMETERS'),
        const SizedBox(height: 10),
        _infoCard([
          _infoRow('n_estimators', '${_rf['n_estimators'] ?? 100} trees'),
          _infoRow('max_depth', _rf['max_depth'] ?? 'None — fully grown trees'),
          _infoRow('n_features_in_', '${_rf['n_features'] ?? 78}'),
          _infoRow('classes_', '[0, 1]  →  0=BENIGN, 1=ATTACK'),
          _infoRow('criterion', _rf['criterion'] ?? 'gini'),
          _infoRow('bootstrap', '${_rf['bootstrap'] ?? true}'),
          _infoRow(
            'max_features',
            _rf['max_features'] ?? 'sqrt(78) ≈ 9 per split',
          ),
          _infoRow('Train / Test', '80% / 20%'),
          _infoRow('Scaler', 'StandardScaler (autoencoder_scaler.pkl)'),
          _infoRow('Saved as', 'random_forest_reetrained.pkl  (joblib)'),
        ]),
        const SizedBox(height: 20),
        _label('HOW IT WORKS'),
        const SizedBox(height: 10),
        _stepCard(
          1,
          'Bootstrap Sampling',
          'Each tree is trained on a random subset with replacement — creates 100 diverse trees.',
        ),
        _stepCard(
          2,
          'Feature Subsampling',
          'At each node only sqrt(78)≈9 random features are evaluated. Prevents any single feature dominating.',
        ),
        _stepCard(
          3,
          'Gini Impurity',
          'Best split = one that most reduces Gini impurity across BENIGN vs ATTACK samples.',
        ),
        _stepCard(
          4,
          'Full Tree Growth',
          'max_depth=None — trees grow until leaves are pure. Each leaf outputs a definitive 0 or 1.',
        ),
        _stepCard(
          5,
          'Majority Voting',
          'All 100 trees vote. Most votes wins. 87/100 for ATTACK = prediction: ATTACK, confidence: 87%.',
        ),
        const SizedBox(height: 20),
        _label('PERFORMANCE METRICS'),
        const SizedBox(height: 6),
        if (!hasMetrics)
          _noteBox(
            'Place X_test.csv (with Label column) at data/processed/X_test.csv and tap refresh — metrics will appear automatically.',
          )
        else ...[
          _metricGrid([
            ['Overall Accuracy', '${_rf['accuracy']}%', AppColors.primary],
            ['F1 Score (Attack)', '${_rf['f1_attack']}%', AppColors.danger],
            ['Precision (Attack)', '${_rf['precision']}%', AppColors.warning],
            ['Recall (Attack)', '${_rf['recall']}%', AppColors.success],
          ]),
          const SizedBox(height: 16),
          _label('PER-CLASS  (P = Precision   R = Recall   F1 = F1-Score)'),
          const SizedBox(height: 10),
          _classMetricsTable([
            [
              'BENIGN  (class 0)',
              '${_rf['benign_p']}%',
              '${_rf['benign_r']}%',
              '${_rf['benign_f1']}%',
            ],
            [
              'ATTACK  (class 1)',
              '${_rf['attack_p']}%',
              '${_rf['attack_r']}%',
              '${_rf['attack_f1']}%',
            ],
          ]),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 2 — AUTOENCODER  (live from backend)
  // ══════════════════════════════════════════════════════════════
  Widget _buildAutoencoderTab() {
    final pb = (_ae['param_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.psychology_rounded,
          'Autoencoder — Anomaly Detector',
          'Unsupervised deep learning — PyTorch',
        ),
        _label('CONCEPT'),
        const SizedBox(height: 10),
        _conceptCard(
          'Trained ONLY on benign traffic. Learns to compress and reconstruct normal flows. '
          'Any flow with high reconstruction error (MSE > threshold) is flagged as anomalous — '
          'catching unknown or zero-day attacks the Random Forest has never seen.',
        ),
        const SizedBox(height: 20),
        _label('ARCHITECTURE'),
        const SizedBox(height: 10),
        _layerDiagram([
          ['INPUT', '${_ae['input_dim'] ?? 78}', 'Linear', AppColors.primary],
          ['ENCODER', '64', 'Linear + ReLU', AppColors.warning],
          [
            'LATENT',
            '${_ae['latent_dim'] ?? 32}',
            'Linear + ReLU',
            AppColors.danger,
          ],
          ['DECODER', '64', 'Linear + ReLU', AppColors.success],
          ['OUTPUT', '${_ae['input_dim'] ?? 78}', 'Linear', AppColors.primary],
        ]),
        const SizedBox(height: 20),
        _infoCard([
          _infoRow('Framework', 'PyTorch'),
          _infoRow('Input / Output', '${_ae['input_dim'] ?? 78} features'),
          _infoRow('Encoder', '78 → 64 (ReLU) → 32 (ReLU)'),
          _infoRow('Latent dimension', '${_ae['latent_dim'] ?? 32}'),
          _infoRow('Decoder', '32 → 64 (ReLU) → 78'),
          _infoRow('Total parameters', '${_ae['total_params'] ?? 14318}'),
          _infoRow('Loss function', _ae['loss'] ?? 'MSE'),
          _infoRow('Optimizer', _ae['optimizer'] ?? 'Adam (lr=0.001)'),
          _infoRow('Training data', 'BENIGN flows only'),
          _infoRow(
            'Anomaly threshold',
            '${_ae['threshold'] ?? 0.8802}  (95th percentile)',
          ),
          _infoRow(
            'Detected anomalies',
            '${_ae['anomalies_found'] ?? 2231} flows on test set',
          ),
          _infoRow('Saved as', 'autoencoder_model.pth'),
        ]),
        const SizedBox(height: 20),
        _label('PARAMETER BREAKDOWN'),
        const SizedBox(height: 10),
        _infoCard([
          _infoRow(
            'Encoder  78→64',
            '78×64 + 64  =  ${pb['enc_78_64'] ?? 5056}',
          ),
          _infoRow(
            'Encoder  64→32',
            '64×32 + 32  =  ${pb['enc_64_32'] ?? 2080}',
          ),
          _infoRow(
            'Decoder  32→64',
            '32×64 + 64  =  ${pb['dec_32_64'] ?? 2112}',
          ),
          _infoRow(
            'Decoder  64→78',
            '64×78 + 78  =  ${pb['dec_64_78'] ?? 5070}',
          ),
          _infoRow('TOTAL', '${_ae['total_params'] ?? 14318} parameters'),
        ]),
        const SizedBox(height: 20),
        _label('ANOMALY DETECTION STEPS'),
        const SizedBox(height: 10),
        _stepCard(
          1,
          'Train on Normal',
          'Minimize MSE on benign flows only. Model learns "what normal looks like".',
        ),
        _stepCard(
          2,
          'Set Threshold',
          '95th percentile of training errors = ${_ae['threshold'] ?? 0.8802}. ~5% of benign will exceed this (false positive budget).',
        ),
        _stepCard(
          3,
          'Inference',
          'Encode → ${_ae['latent_dim'] ?? 32}-dim latent → decode back → compute MSE between original and reconstruction.',
        ),
        _stepCard(
          4,
          'Flag',
          'MSE > ${_ae['threshold'] ?? 0.8802} → ANOMALY. Flow does not resemble normal traffic.',
        ),
        _stepCard(
          5,
          'Complement RF',
          'RF catches known attacks. Autoencoder catches novel/zero-day threats by statistical deviation.',
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 3 — VAE  (live from backend)
  // ══════════════════════════════════════════════════════════════
  Widget _buildVAETab() {
    final pb = (_vae['param_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.blur_on_rounded,
          'Variational Autoencoder (VAE)',
          'Probabilistic deep learning — PyTorch',
        ),
        _label('CONCEPT'),
        const SizedBox(height: 10),
        _conceptCard(
          'An advanced upgrade of the standard Autoencoder. Instead of encoding to a fixed point, '
          'the VAE encodes to a probability distribution (mean μ and log-variance). '
          'This creates a smoother, more structured latent space — improving generalization '
          'and anomaly detection on edge cases the standard AE might miss.',
        ),
        const SizedBox(height: 20),
        _label('ACTUAL ARCHITECTURE'),
        const SizedBox(height: 10),
        _vaeArchitectureDiagram(),
        const SizedBox(height: 20),
        _infoCard([
          _infoRow('Framework', 'PyTorch'),
          _infoRow('Input / Output', '${_vae['input_dim'] ?? 78} features'),
          _infoRow('Encoder', '78 → 64 (ReLU) → 32 (ReLU)'),
          _infoRow('fc_mu', 'Linear(32 → 16)  — mean of distribution'),
          _infoRow(
            'fc_logvar',
            'Linear(32 → 16)  — log-variance of distribution',
          ),
          _infoRow(
            'Latent dimension',
            '${_vae['latent_dim'] ?? 16}  (sampled via reparameterization)',
          ),
          _infoRow('Decoder', '16 → 32 (ReLU) → 64 (ReLU) → 78'),
          _infoRow('Total parameters', '${_vae['total_params'] ?? 15918}'),
          _infoRow('Loss function', _vae['loss'] ?? 'MSE + KL Divergence'),
          _infoRow('Reparameterization', 'z = μ + ε·σ  where  ε ~ N(0, 1)'),
          _infoRow('Saved as', 'vAutoEncoder_model.pth'),
        ]),
        const SizedBox(height: 20),
        _label('VAE  vs  STANDARD AUTOENCODER'),
        const SizedBox(height: 10),
        _comparisonTable([
          ['Latent type', 'Fixed vector', 'Probability distribution'],
          [
            'Latent dim',
            '${_ae['latent_dim'] ?? 32}',
            '${_vae['latent_dim'] ?? 16}',
          ],
          [
            'Parameters',
            '${_ae['total_params'] ?? 14318}',
            '${_vae['total_params'] ?? 15918}',
          ],
          ['Loss', 'MSE only', 'MSE + KL divergence'],
          ['Latent space', 'Can have gaps', 'Smooth & continuous'],
          ['Zero-day', 'Good', 'Better generalization'],
        ]),
        const SizedBox(height: 20),
        _label('PARAMETER BREAKDOWN'),
        const SizedBox(height: 10),
        _infoCard([
          _infoRow(
            'Encoder  78→64',
            '78×64 + 64  =  ${pb['enc_78_64'] ?? 5056}',
          ),
          _infoRow(
            'Encoder  64→32',
            '64×32 + 32  =  ${pb['enc_64_32'] ?? 2080}',
          ),
          _infoRow(
            'fc_mu    32→16',
            '32×16 + 16  =  ${pb['fc_mu_32_16'] ?? 528}',
          ),
          _infoRow(
            'fc_logvar32→16',
            '32×16 + 16  =  ${pb['fc_lv_32_16'] ?? 528}',
          ),
          _infoRow(
            'Decoder  16→32',
            '16×32 + 32  =  ${pb['dec_16_32'] ?? 544}',
          ),
          _infoRow(
            'Decoder  32→64',
            '32×64 + 64  =  ${pb['dec_32_64'] ?? 2112}',
          ),
          _infoRow(
            'Decoder  64→78',
            '64×78 + 78  =  ${pb['dec_64_78'] ?? 5070}',
          ),
          _infoRow('TOTAL', '${_vae['total_params'] ?? 15918} parameters'),
        ]),
        const SizedBox(height: 20),
        _label('HOW THE REPARAMETERIZATION TRICK WORKS'),
        const SizedBox(height: 10),
        _stepCard(
          1,
          'Encode',
          'Shared encoder maps 78-dim input → 32-dim hidden vector.',
        ),
        _stepCard(
          2,
          'Two heads',
          'fc_mu outputs μ (16-dim). fc_logvar outputs log-σ² (16-dim). These define a Gaussian distribution per flow.',
        ),
        _stepCard(
          3,
          'Sample',
          'z = μ + ε × exp(0.5 × logvar)  where ε ~ N(0,1). Differentiable — backprop flows through μ and σ.',
        ),
        _stepCard(
          4,
          'Decode',
          'z (16-dim) → 32 → 64 → 78. Reconstruction compared to input with MSE.',
        ),
        _stepCard(
          5,
          'KL Loss',
          'KL divergence forces learned distribution toward N(0,1). Regularizes latent space, prevents overfitting.',
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 4 — SHAP (static explanations)
  // ══════════════════════════════════════════════════════════════
  Widget _buildShapTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(
        Icons.lightbulb_rounded,
        'SHAP Explainability (XAI)',
        'SHapley Additive exPlanations — per-flow feature attribution',
      ),
      _label('WHAT IS SHAP?'),
      const SizedBox(height: 10),
      _conceptCard(
        'SHAP is a game-theory method that explains individual ML predictions. '
        'For each flow flagged as ATTACK, SHAP shows which of the 78 features drove that '
        'decision — and by exactly how much. Makes the AI transparent and auditable.',
      ),
      const SizedBox(height: 20),
      _label('EXAMPLE — FLOW FLAGGED AS ATTACK'),
      const SizedBox(height: 10),
      _shapExampleCard(),
      const SizedBox(height: 20),
      _infoCard([
        _infoRow('Method', 'TreeExplainer — exact SHAP for tree models'),
        _infoRow('Applied to', 'Random Forest binary classifier'),
        _infoRow('Exactness', 'Exact values — not approximations'),
        _infoRow('Computed for', 'Sampled attack flows (subset for speed)'),
        _infoRow('Displayed', 'Top 5 features by |SHAP value| per flow'),
      ]),
      const SizedBox(height: 20),
      _label('HOW IT WORKS'),
      const SizedBox(height: 10),
      _stepCard(
        1,
        'Game Theory',
        'Each feature is a "player". The prediction is the "payout". SHAP fairly distributes credit.',
      ),
      _stepCard(
        2,
        'Shapley Values',
        'Per feature: average marginal contribution across all possible feature orderings.',
      ),
      _stepCard(
        3,
        'TreeExplainer',
        'Exploits tree structure for exact, fast computation — polynomial not exponential time.',
      ),
      _stepCard(
        4,
        'Per-Flow Output',
        '78 SHAP values per flow. Sum = prediction_score − base_rate. Large |value| = high influence.',
      ),
      _stepCard(
        5,
        'Dashboard',
        'Top 5 features sorted by absolute SHAP shown with direction arrow per attack flow.',
      ),
      const SizedBox(height: 20),
      _label('SHAP VALUE REFERENCE'),
      const SizedBox(height: 10),
      _shapReferenceTable(),
      const SizedBox(height: 20),
      _label('WHY XAI MATTERS IN CYBERSECURITY'),
      const SizedBox(height: 10),
      _infoCard([
        _infoRow(
          'Analyst trust',
          'Verify WHY an alert fired before acting on it',
        ),
        _infoRow(
          'False positives',
          'Context separates real threats from noise',
        ),
        _infoRow('Forensics', 'SHAP values as explainable evidence in reports'),
        _infoRow(
          'Model debug',
          'Reveals if model relies on noisy/irrelevant features',
        ),
        _infoRow('Regulatory', 'GDPR & AI Acts require explainable decisions'),
      ]),
    ],
  );

  // ══════════════════════════════════════════════════════════════
  // REUSABLE WIDGETS  (unchanged from original)
  // ══════════════════════════════════════════════════════════════
  Widget _sectionHeader(IconData icon, String title, String subtitle) =>
      Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.15), AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecond,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        color: AppColors.textSecond,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    ),
  );

  Widget _infoCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(children: rows),
  );

  Widget _infoRow(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: Text(
            k,
            style: const TextStyle(
              color: AppColors.textSecond,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _conceptCard(String t) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.primary.withOpacity(0.25)),
    ),
    child: Text(
      t,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        height: 1.7,
      ),
    ),
  );

  Widget _stepCard(int n, String title, String body) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$n',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.textSecond,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _noteBox(String t) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warningDim,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: AppColors.warning,
          size: 16,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            t,
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _metricGrid(List<List<dynamic>> items) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 2.2,
    children: items.map((item) {
      final color = item[2] as Color;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item[1].toString(),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item[0].toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecond,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );

  Widget _classMetricsTable(List<List<String>> rows) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'CLASS',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'P',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'R',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'F1',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...rows.map(
          (row) => Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.cardBorder, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    row[0],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row[1],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row[2],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row[3],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _attackTable(List<List<dynamic>> rows) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'CLASS',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'SAMPLES',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final row = e.value;
          final color = row[3] as Color;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
            decoration: BoxDecoration(
              color: i % 2 == 0
                  ? Colors.transparent
                  : AppColors.primary.withOpacity(0.03),
              border: const Border(
                top: BorderSide(color: AppColors.cardBorder, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      row[0].toString(),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    row[1].toString(),
                    style: const TextStyle(
                      color: AppColors.textSecond,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    row[2].toString(),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );

  Widget _featureGrid(List<String> features) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: features
        .map(
          (f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Text(
              f,
              style: const TextStyle(
                color: AppColors.textSecond,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
        .toList(),
  );

  Widget _layerDiagram(List<List<dynamic>> layers) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      children: layers.asMap().entries.map((e) {
        final isLast = e.key == layers.length - 1;
        final l = e.value;
        return Column(
          children: [
            _layerRow(
              l[0].toString(),
              l[1].toString(),
              l[2].toString(),
              l[3] as Color,
            ),
            if (!isLast) _arrow(),
          ],
        );
      }).toList(),
    ),
  );

  Widget _vaeArchitectureDiagram() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      children: [
        _layerRow('INPUT', '78', 'Linear', AppColors.primary),
        _arrow(),
        _layerRow('ENCODER', '64', 'Linear + ReLU', AppColors.warning),
        _arrow(),
        _layerRow('ENCODER', '32', 'Linear + ReLU', AppColors.warning),
        _arrow(),
        Row(
          children: [
            Expanded(
              child: _layerRow('fc_mu', '16', 'Linear', AppColors.purple),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _layerRow('fc_logvar', '16', 'Linear', AppColors.purple),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'z = μ + ε·σ   (reparameterization)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.purple.withOpacity(0.8),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        _layerRow('LATENT z', '16', 'Sampled vector', AppColors.purple),
        _arrow(),
        _layerRow('DECODER', '32', 'Linear + ReLU', AppColors.success),
        _arrow(),
        _layerRow('DECODER', '64', 'Linear + ReLU', AppColors.success),
        _arrow(),
        _layerRow('OUTPUT', '78', 'Linear', AppColors.primary),
      ],
    ),
  );

  Widget _layerRow(String label, String dim, String act, Color color) => Row(
    children: [
      SizedBox(
        width: 72,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dim neurons',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· $act',
                style: TextStyle(color: color.withOpacity(0.6), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _arrow() => Padding(
    padding: const EdgeInsets.only(left: 72),
    child: Icon(
      Icons.keyboard_arrow_down_rounded,
      color: AppColors.textSecond.withOpacity(0.4),
      size: 20,
    ),
  );

  Widget _comparisonTable(List<List<String>> rows) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'ASPECT',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'AUTOENCODER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'VAE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.purple,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final row = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
            decoration: BoxDecoration(
              color: i % 2 == 0
                  ? Colors.transparent
                  : AppColors.primary.withOpacity(0.03),
              border: const Border(
                top: BorderSide(color: AppColors.cardBorder, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    row[0],
                    style: const TextStyle(
                      color: AppColors.textSecond,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    row[1],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    row[2],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.purple,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );

  Widget _shapExampleCard() {
    final examples = [
      [
        'Fwd Packet Length Max',
        '+0.42',
        true,
        'Very large packets → strongly indicates DDoS flood',
      ],
      [
        'Bwd IAT Mean',
        '+0.31',
        true,
        'High backward inter-arrival time → attack pattern',
      ],
      [
        'PSH Flag Count',
        '+0.12',
        true,
        'Elevated PSH flags → push-based attack behaviour',
      ],
      [
        'Flow Duration',
        '-0.18',
        false,
        'Short duration → slightly pushed toward benign',
      ],
      [
        'Flow Bytes/s',
        '-0.09',
        false,
        'Low bytes/sec → slight push toward benign',
      ],
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'Example — Flow classified as ATTACK (class 1)',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ...examples.map((e) {
            final positive = e[2] as bool;
            final color = positive ? AppColors.danger : AppColors.success;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.cardBorder, width: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    positive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: color,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e[0].toString(),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              e[1].toString(),
                              style: TextStyle(
                                color: color,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          e[3].toString(),
                          style: const TextStyle(
                            color: AppColors.textSecond,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _shapReferenceTable() {
    final rows = [
      [
        'Large positive (+0.4)',
        'Feature strongly indicates ATTACK',
        AppColors.danger,
      ],
      [
        'Small positive (+0.1)',
        'Feature weakly indicates attack',
        AppColors.warning,
      ],
      [
        'Near zero  (±0.02)',
        'Little influence on prediction',
        AppColors.textSecond,
      ],
      [
        'Small negative (-0.1)',
        'Feature weakly indicates benign',
        AppColors.success,
      ],
      [
        'Large negative (-0.4)',
        'Feature strongly indicates BENIGN',
        AppColors.success,
      ],
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final i = e.key;
          final row = e.value;
          final color = row[2] as Color;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : const Border(
                      top: BorderSide(color: AppColors.cardBorder, width: 0.5),
                    ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    row[0].toString(),
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    row[1].toString(),
                    style: const TextStyle(
                      color: AppColors.textSecond,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
