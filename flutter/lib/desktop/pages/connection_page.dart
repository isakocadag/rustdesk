// main window right pane

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/popup_menu.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_hbb/models/peer_model.dart';

import '../../common.dart';
import '../../common/formatter/id_formatter.dart';
import '../../common/widgets/peer_tab_page.dart';
import '../../common/widgets/autocomplete.dart';
import 'ossis_personnel_session.dart';
import '../../models/platform_model.dart';
import '../../utils/multi_window_manager.dart';
import '../../desktop/widgets/material_mod_popup_menu.dart' as mod_menu;

const bool kOssisPersonnelConnectionBuild = bool.fromEnvironment(
  'OSSIS_PERSONNEL',
  defaultValue: false,
);

class OnlineStatusWidget extends StatefulWidget {
  const OnlineStatusWidget({Key? key, this.onSvcStatusChanged})
      : super(key: key);

  final VoidCallback? onSvcStatusChanged;

  @override
  State<OnlineStatusWidget> createState() => _OnlineStatusWidgetState();
}

/// State for the connection page.
class _OnlineStatusWidgetState extends State<OnlineStatusWidget> {
  final _svcStopped = Get.find<RxBool>(tag: 'stop-service');
  final _svcIsUsingPublicServer = true.obs;
  Timer? _updateTimer;

  double get em => 14.0;
  double? get height => bind.isIncomingOnly() ? null : em * 3;

  void onUsePublicServerGuide() {
    const url = "https://ossisbilisim.com";
    canLaunchUrlString(url).then((can) {
      if (can) {
        launchUrlString(url);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _updateTimer = periodic_immediate(Duration(seconds: 1), () async {
      updateStatus();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIncomingOnly = bind.isIncomingOnly();
    startServiceWidget() => Offstage(
          offstage: !_svcStopped.value,
          child: InkWell(
                  onTap: () async {
                    await start_service(true);
                  },
                  child: Text(translate("Start service"),
                      style: TextStyle(
                          decoration: TextDecoration.underline, fontSize: em)))
              .marginOnly(left: em),
        );

    setupServerWidget() => Flexible(
          child: Offstage(
            offstage: !(!_svcStopped.value &&
                stateGlobal.svcStatus.value == SvcStatus.ready &&
                _svcIsUsingPublicServer.value),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(', ', style: TextStyle(fontSize: em)),
                Flexible(
                  child: InkWell(
                    onTap: onUsePublicServerGuide,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            translate('setup_server_tip'),
                            style: TextStyle(
                                decoration: TextDecoration.underline,
                                fontSize: em),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );

    basicWidget() => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 8,
              width: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _svcStopped.value ||
                        stateGlobal.svcStatus.value == SvcStatus.connecting
                    ? kColorWarn
                    : (stateGlobal.svcStatus.value == SvcStatus.ready
                        ? Color.fromARGB(255, 50, 190, 166)
                        : Color.fromARGB(255, 224, 79, 95)),
              ),
            ).marginSymmetric(horizontal: em),
            Container(
              width: isIncomingOnly ? 226 : null,
              child: _buildConnStatusMsg(),
            ),
            // stop
            if (!isIncomingOnly) startServiceWidget(),
            // ready && public
            // No need to show the guide if is custom client.
            if (!isIncomingOnly) setupServerWidget(),
          ],
        );

    return Container(
      height: height,
      child: Obx(() => isIncomingOnly
          ? Column(
              children: [
                basicWidget(),
                Align(
                        child: startServiceWidget(),
                        alignment: Alignment.centerLeft)
                    .marginOnly(top: 2.0, left: 22.0),
              ],
            )
          : basicWidget()),
    ).paddingOnly(right: isIncomingOnly ? 8 : 0);
  }

  _buildConnStatusMsg() {
    widget.onSvcStatusChanged?.call();
    return Text(
      _svcStopped.value
          ? translate("Service is not running")
          : stateGlobal.svcStatus.value == SvcStatus.connecting
              ? translate("connecting_status")
              : stateGlobal.svcStatus.value == SvcStatus.notReady
                  ? translate("not_ready_status")
                  : translate('Ready'),
      style: TextStyle(fontSize: em),
    );
  }

  updateStatus() async {
    final status =
        jsonDecode(await bind.mainGetConnectStatus()) as Map<String, dynamic>;
    final statusNum = status['status_num'] as int;
    if (statusNum == 0) {
      stateGlobal.svcStatus.value = SvcStatus.connecting;
    } else if (statusNum == -1) {
      stateGlobal.svcStatus.value = SvcStatus.notReady;
    } else if (statusNum == 1) {
      stateGlobal.svcStatus.value = SvcStatus.ready;
    } else {
      stateGlobal.svcStatus.value = SvcStatus.notReady;
    }
    _svcIsUsingPublicServer.value = await bind.mainIsUsingPublicServer();
    try {
      stateGlobal.videoConnCount.value = status['video_conn_count'] as int;
    } catch (_) {}
  }
}

class _OssisPersonnelChatPanel extends StatefulWidget {
  const _OssisPersonnelChatPanel();

  @override
  State<_OssisPersonnelChatPanel> createState() =>
      _OssisPersonnelChatPanelState();
}

class _OssisPersonnelChatPanelState extends State<_OssisPersonnelChatPanel> {
  final _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = const [];
  String? _peerId;
  bool _refreshing = false;
  bool _sending = false;

  bool get _connected => _peerId != null;

  @override
  void initState() {
    super.initState();
    rustDeskWinManager.ossisRemoteChatRevision.addListener(_refreshChat);
    rustDeskWinManager.registerActiveWindowListener(_refreshChat);
    _refreshChat();
  }

  @override
  void dispose() {
    rustDeskWinManager.ossisRemoteChatRevision.removeListener(_refreshChat);
    rustDeskWinManager.unregisterActiveWindowListener(_refreshChat);
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _refreshChat() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final result = await rustDeskWinManager.invokeRemoteDesktopMethod(
        kWindowEventGetRemoteChat,
      );
      if (!mounted) return;
      if (result is! String || result.isEmpty) {
        if (_connected || _messages.isNotEmpty) {
          setState(() {
            _peerId = null;
            _messages = const [];
          });
        }
        return;
      }
      final payload = jsonDecode(result);
      if (payload is! Map<String, dynamic>) return;
      final rawMessages = payload['messages'];
      final messages = rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      setState(() {
        _peerId = payload['peerId']?.toString();
        _messages = messages;
      });
    } catch (_) {
      if (mounted && _connected) {
        setState(() {
          _peerId = null;
          _messages = const [];
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_connected || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await rustDeskWinManager.invokeRemoteDesktopMethod(
        kWindowEventSendRemoteChat,
        text,
      );
      if (sent == true) {
        _messageController.clear();
        await _refreshChat();
      } else {
        showToast('Mesaj gönderilemedi: aktif bağlantı yok.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _timeText(dynamic value) {
    final time = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF17212C),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF293644)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    color: Color(0xFFD92D3A), size: 19),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'MÜŞTERİ SOHBETİ',
                    style: TextStyle(
                      color: Color(0xFFAAB5C1),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _connected
                        ? const Color(0xFF41C985)
                        : const Color(0xFF596674),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF293644)),
          Expanded(
            child: !_connected
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Sohbet, müşteri bağlantısı kurulduğunda burada açılır.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF7F8B98),
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Henüz mesaj yok.',
                          style: TextStyle(color: Color(0xFF7F8B98)),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final own = message['own'] == true;
                          return Align(
                            alignment: own
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 235),
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
                              decoration: BoxDecoration(
                                color: own
                                    ? const Color(0xFF7A2630)
                                    : const Color(0xFF263544),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      message['text']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _timeText(message['time']),
                                    style: const TextStyle(
                                      color: Color(0xFFAAB5C1),
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: _connected && !_sending,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _connected
                          ? 'Bir mesaj yazın'
                          : 'Bağlantı bekleniyor',
                      filled: true,
                      fillColor: const Color(0xFF0F161E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF354352)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _connected && !_sending ? _sendMessage : null,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFD92D3A),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 19),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Connection page for connecting to a remote peer.
class ConnectionPage extends StatefulWidget {
  const ConnectionPage({Key? key}) : super(key: key);

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

/// State for the connection page.
class _ConnectionPageState extends State<ConnectionPage>
    with SingleTickerProviderStateMixin, WindowListener {
  /// Controller for the id input bar.
  final _idController = IDTextEditingController();

  final RxBool _idInputFocused = false.obs;
  final FocusNode _idFocusNode = FocusNode();
  final TextEditingController _idEditingController = TextEditingController();

  String selectedConnectionType = 'Connect';

  bool isWindowMinimized = false;
  bool _ossisExitStarted = false;

  final AllPeersLoader _allPeersLoader = AllPeersLoader();

  // https://github.com/flutter/flutter/issues/157244
  Iterable<Peer> _autocompleteOpts = [];

  final _menuOpen = false.obs;

  @override
  void initState() {
    super.initState();
    _allPeersLoader.init(setState);
    _idFocusNode.addListener(onFocusChanged);
    if (_idController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lastRemoteId = await bind.mainGetLastRemoteId();
        if (lastRemoteId != _idController.id) {
          setState(() {
            _idController.id = lastRemoteId;
          });
        }
      });
    }
    Get.put<TextEditingController>(_idEditingController);
    Get.put<IDTextEditingController>(_idController);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    _idController.dispose();
    windowManager.removeListener(this);
    _allPeersLoader.clear();
    _idFocusNode.removeListener(onFocusChanged);
    _idFocusNode.dispose();
    _idEditingController.dispose();
    if (Get.isRegistered<IDTextEditingController>()) {
      Get.delete<IDTextEditingController>();
    }
    if (Get.isRegistered<TextEditingController>()) {
      Get.delete<TextEditingController>();
    }
    super.dispose();
  }

  @override
  void onWindowEvent(String eventName) {
    super.onWindowEvent(eventName);
    if (eventName == 'minimize') {
      isWindowMinimized = true;
    } else if (eventName == 'maximize' || eventName == 'restore') {
      if (isWindowMinimized && isWindows) {
        // windows can't update when minimized.
        Get.forceAppUpdate();
      }
      isWindowMinimized = false;
    }
  }

  @override
  void onWindowEnterFullScreen() {
    // Remove edge border by setting the value to zero.
    stateGlobal.resizeEdgeSize.value = 0;
  }

  @override
  void onWindowLeaveFullScreen() {
    // Restore edge border to default edge size.
    stateGlobal.resizeEdgeSize.value = stateGlobal.isMaximized.isTrue
        ? kMaximizeEdgeSize
        : windowResizeEdgeSize;
  }

  @override
  void onWindowClose() {
    super.onWindowClose();
    if (isWindows) {
      if (_ossisExitStarted) return;
      _ossisExitStarted = true;
      Future<void>(() async {
        await rustDeskWinManager.closeAllSubWindows();
        await gFFI.serverModel.closeAll();
        await gFFI.close();
        await windowManager.setPreventClose(false);
        await windowManager.close();
        exit(0);
      });
      return;
    }
    bind.mainOnMainWindowClose();
  }

  void onFocusChanged() {
    _idInputFocused.value = _idFocusNode.hasFocus;
    if (_idFocusNode.hasFocus) {
      if (_allPeersLoader.needLoad) {
        _allPeersLoader.getAllPeers();
      }

      final textLength = _idEditingController.value.text.length;
      // Select all to facilitate removing text, just following the behavior of address input of chrome.
      _idEditingController.selection =
          TextSelection(baseOffset: 0, extentOffset: textLength);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoingOnly = bind.isOutgoingOnly();
    if (kOssisPersonnelConnectionBuild) {
      return _buildOssisPersonnelPage(context, isOutgoingOnly);
    }
    return Column(
      children: [
        Expanded(
            child: Column(
          children: [
            Row(
              children: [
                Flexible(child: _buildRemoteIDTextField(context)),
              ],
            ).marginOnly(top: 22),
            SizedBox(height: 12),
            Divider().paddingOnly(right: 12),
            Expanded(child: PeerTabPage()),
          ],
        ).paddingOnly(left: 12.0)),
        if (!isOutgoingOnly) const Divider(height: 1),
        if (!isOutgoingOnly) OnlineStatusWidget()
      ],
    );
  }

  Widget _buildOssisPersonnelPage(
    BuildContext context,
    bool isOutgoingOnly,
  ) {
    const surface = Color(0xFF0F161E);
    const panel = Color(0xFF17212C);
    const border = Color(0xFF293644);
    const accent = Color(0xFFD92D3A);
    final bottomDockHeight =
        (MediaQuery.sizeOf(context).height * .24).clamp(180.0, 260.0);

    return Container(
      color: surface,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 200,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: panel,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(color: border),
                        ),
                        child: _buildRemoteIDTextField(context),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF25191E), Color(0xFF17212C)],
                            ),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(color: const Color(0xFF503039)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings_outlined,
                                    color: accent,
                                    size: 27,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Güvenli Personel Bağlantısı',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Müşterinin ekrandaki OSSIS ID numarasını girin. Bağlantı isteği müşterinin onayına sunulur ve onay sonrasında oturum araçları açılır.',
                                style: TextStyle(
                                  color: Color(0xFFA8B3BF),
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _runPersonnelSessionAction(
                                        kWindowEventOpenRemoteChat,
                                        'Sohbet için aktif bağlantı yok.',
                                      ),
                                      icon:
                                          const Icon(Icons.chat_bubble_outline),
                                      label: const Text('Metin Sohbeti'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _runPersonnelSessionAction(
                                        kWindowEventToggleRemoteVoice,
                                        'Sesli görüşme için aktif bağlantı yok.',
                                      ),
                                      icon: const Icon(
                                          Icons.headset_mic_outlined),
                                      label: const Text('Sesli Görüşme'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(Icons.devices_other_outlined, color: accent, size: 19),
                    SizedBox(width: 9),
                    Text(
                      'MÜŞTERİLER VE SON OTURUMLAR',
                      style: TextStyle(
                        color: Color(0xFF9CA8B5),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: border),
                    ),
                    child: PeerTabPage(),
                  ),
                ),
                if (!isOutgoingOnly) ...[
                  const SizedBox(height: 10),
                  const OnlineStatusWidget(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: bottomDockHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: _OssisPersonnelChatPanel()),
                const SizedBox(width: 14),
                SizedBox(
                  width: 610,
                  child: _buildPersonnelAccountPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonnelAccountPanel() {
    return AnimatedBuilder(
      animation: OssisPersonnelSession.instance,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF17212C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF293644)),
        ),
        child: Row(
          children: [
            _buildPersonnelAccountValue(
              Icons.account_circle_outlined,
              'PERSONEL',
              OssisPersonnelSession.instance.displayName,
            ),
            const SizedBox(width: 10),
            _buildPersonnelAccountValue(
              Icons.toll_outlined,
              'KREDİ',
              OssisPersonnelSession.instance.creditText,
            ),
            const SizedBox(width: 10),
            _buildPersonnelAccountValue(
              Icons.hourglass_bottom_rounded,
              'KALAN SÜRE',
              OssisPersonnelSession.instance.remainingTimeText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonnelAccountValue(
    IconData icon,
    String label,
    String value,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F161E),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFF354352)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFD92D3A), size: 25),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF8D9AAA),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runPersonnelSessionAction(
    String action,
    String unavailableMessage,
  ) async {
    final handled = await rustDeskWinManager.invokeRemoteDesktopAction(action);
    if (!handled) showToast(unavailableMessage);
  }

  /// Callback for the connect button.
  /// Connects to the selected peer.
  void onConnect(
      {bool isFileTransfer = false,
      bool isViewCamera = false,
      bool isTerminal = false}) {
    var id = _idController.id;
    connect(context, id,
        isFileTransfer: isFileTransfer,
        isViewCamera: isViewCamera,
        isTerminal: isTerminal);
  }

  /// UI for the remote ID TextField.
  /// Search for a peer.
  Widget _buildRemoteIDTextField(BuildContext context) {
    var w = Container(
      width: 320 + 20 * 2,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(13)),
          border: Border.all(color: Theme.of(context).colorScheme.background)),
      child: Ink(
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Yeni Destek Bağlantısı',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ).marginOnly(bottom: 15),
            Row(
              children: [
                Expanded(
                    child: RawAutocomplete<Peer>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      _autocompleteOpts = const Iterable<Peer>.empty();
                    } else if (_allPeersLoader.peers.isEmpty &&
                        !_allPeersLoader.isPeersLoaded) {
                      Peer emptyPeer = Peer(
                        id: '',
                        username: '',
                        hostname: '',
                        alias: '',
                        platform: '',
                        tags: [],
                        hash: '',
                        password: '',
                        forceAlwaysRelay: false,
                        rdpPort: '',
                        rdpUsername: '',
                        loginName: '',
                        device_group_name: '',
                        note: '',
                      );
                      _autocompleteOpts = [emptyPeer];
                    } else {
                      String textWithoutSpaces =
                          textEditingValue.text.replaceAll(" ", "");
                      if (int.tryParse(textWithoutSpaces) != null) {
                        textEditingValue = TextEditingValue(
                          text: textWithoutSpaces,
                          selection: textEditingValue.selection,
                        );
                      }
                      String textToFind = textEditingValue.text.toLowerCase();
                      _autocompleteOpts = _allPeersLoader.peers
                          .where((peer) =>
                              peer.id.toLowerCase().contains(textToFind) ||
                              peer.username
                                  .toLowerCase()
                                  .contains(textToFind) ||
                              peer.hostname
                                  .toLowerCase()
                                  .contains(textToFind) ||
                              peer.alias.toLowerCase().contains(textToFind))
                          .toList();
                      _allPeersLoader.queryOnlines(_autocompleteOpts);
                    }
                    return _autocompleteOpts;
                  },
                  focusNode: _idFocusNode,
                  textEditingController: _idEditingController,
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    updateTextAndPreserveSelection(
                        fieldTextEditingController, _idController.text);
                    return Obx(() => TextField(
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.visiblePassword,
                          focusNode: fieldFocusNode,
                          style: const TextStyle(
                            fontFamily: 'WorkSans',
                            fontSize: 22,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          cursorColor:
                              Theme.of(context).textTheme.titleLarge?.color,
                          decoration: InputDecoration(
                              filled: false,
                              counterText: '',
                              hintText: _idInputFocused.value
                                  ? null
                                  : 'Cihaz ID’sini girin',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 13)),
                          controller: fieldTextEditingController,
                          inputFormatters: [IDTextInputFormatter()],
                          onChanged: (v) {
                            _idController.id = v;
                          },
                          onSubmitted: (_) {
                            onConnect();
                          },
                        ).workaroundFreezeLinuxMint());
                  },
                  onSelected: (option) {
                    setState(() {
                      _idController.id = option.id;
                      FocusScope.of(context).unfocus();
                    });
                  },
                  optionsViewBuilder: (BuildContext context,
                      AutocompleteOnSelected<Peer> onSelected,
                      Iterable<Peer> options) {
                    options = _autocompleteOpts;
                    double maxHeight = options.length * 50;
                    if (options.length == 1) {
                      maxHeight = 52;
                    } else if (options.length == 3) {
                      maxHeight = 146;
                    } else if (options.length == 4) {
                      maxHeight = 193;
                    }
                    maxHeight = maxHeight.clamp(0, 200);

                    return Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Material(
                                elevation: 4,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: maxHeight,
                                    maxWidth: 319,
                                  ),
                                  child: _allPeersLoader.peers.isEmpty &&
                                          !_allPeersLoader.isPeersLoaded
                                      ? Container(
                                          height: 80,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ))
                                      : Padding(
                                          padding:
                                              const EdgeInsets.only(top: 5),
                                          child: ListView(
                                            children: options
                                                .map((peer) =>
                                                    AutocompletePeerTile(
                                                        onSelect: () =>
                                                            onSelected(peer),
                                                        peer: peer))
                                                .toList(),
                                          ),
                                        ),
                                ),
                              ))),
                    );
                  },
                )),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 13.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                SizedBox(
                  height: 28.0,
                  child: ElevatedButton(
                    onPressed: () {
                      onConnect();
                    },
                    child: const Text('Bağlantıyı Başlat'),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 28.0,
                  width: 28.0,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        var offset = Offset(0, 0);
                        return Obx(() => InkWell(
                              child: _menuOpen.value
                                  ? Transform.rotate(
                                      angle: pi,
                                      child: Icon(IconFont.more, size: 14),
                                    )
                                  : Icon(IconFont.more, size: 14),
                              onTapDown: (e) {
                                offset = e.globalPosition;
                              },
                              onTap: () async {
                                _menuOpen.value = true;
                                final x = offset.dx;
                                final y = offset.dy;
                                await mod_menu
                                    .showMenu(
                                  context: context,
                                  position: RelativeRect.fromLTRB(x, y, x, y),
                                  items: [
                                    (
                                      'Transfer file',
                                      () => onConnect(isFileTransfer: true)
                                    ),
                                    (
                                      'View camera',
                                      () => onConnect(isViewCamera: true)
                                    ),
                                    (
                                      '${translate('Terminal')} (beta)',
                                      () => onConnect(isTerminal: true)
                                    ),
                                  ]
                                      .map((e) => MenuEntryButton<String>(
                                            childBuilder: (TextStyle? style) =>
                                                Text(
                                              translate(e.$1),
                                              style: style,
                                            ),
                                            proc: () => e.$2(),
                                            padding: EdgeInsets.symmetric(
                                                horizontal:
                                                    kDesktopMenuPadding.left),
                                            dismissOnClicked: true,
                                          ))
                                      .map((e) => e.build(
                                          context,
                                          const MenuConfig(
                                              commonColor: CustomPopupMenuTheme
                                                  .commonColor,
                                              height:
                                                  CustomPopupMenuTheme.height,
                                              dividerHeight:
                                                  CustomPopupMenuTheme
                                                      .dividerHeight)))
                                      .expand((i) => i)
                                      .toList(),
                                  elevation: 8,
                                )
                                    .then((_) {
                                  _menuOpen.value = false;
                                });
                              },
                            ));
                      },
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
    return Container(
        constraints: const BoxConstraints(maxWidth: 600), child: w);
  }
}
