library social_embed_webview;

import 'package:flutter/material.dart';
import 'package:social_embed_webview/utils/common-utils.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SocialEmbed extends StatefulWidget {
  final dynamic socialMediaObj;
  final Color? backgroundColor;
  final Widget? loadingWidget;

  const SocialEmbed({
    Key? key,
    required this.socialMediaObj,
    this.backgroundColor,
    this.loadingWidget,
  }) : super(key: key);

  @override
  _SocialEmbedState createState() => _SocialEmbedState();
}

class _SocialEmbedState extends State<SocialEmbed> with WidgetsBindingObserver {
  double _height = 300;
  late final WebViewController wbController;
  late String htmlBody;
  ValueNotifier<bool> _isLoadingContent = ValueNotifier(true);
  double? aspectRatio;

  @override
  void initState() {
    super.initState();
    if (widget.socialMediaObj.supportMediaController)
      WidgetsBinding.instance.addObserver(this);
    aspectRatio = widget.socialMediaObj.aspectRatio;
  }

  @override
  void dispose() {
    if (widget.socialMediaObj.supportMediaController)
      WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.detached:
        wbController.runJavascript(widget.socialMediaObj.stopVideoScript);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        wbController.runJavascript(widget.socialMediaObj.pauseVideoScript);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final webView  = WebView(
        initialUrl: htmlToURI(getHtmlBody()),
        javascriptChannels:
        <JavascriptChannel>[_getHeightJavascriptChannel()].toSet(),
        javascriptMode: JavascriptMode.unrestricted,
        initialMediaPlaybackPolicy:
        AutoMediaPlaybackPolicy.require_user_action_for_all_media_types,
        onWebViewCreated: (wbc) {
          wbController = wbc;
        },
        onPageFinished: (str) {
          final color = colorToHtmlRGBA(getBackgroundColor(context));
          wbController
              .runJavascript('document.body.style= "background-color: $color"');
          if (widget.socialMediaObj.aspectRatio == null)
            wbController.runJavascript('setTimeout(() => sendHeight(), 0)');
          _isLoadingContent.value = false;
        },
        navigationDelegate: (navigation) async {
          final url = navigation.url;
          if (navigation.isForMainFrame && await canLaunchUrlString(url)) {
            launchUrlString(url, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        });
    return ValueListenableBuilder<bool>(
        valueListenable: _isLoadingContent,
        builder: (_, isContentLoading, child) {
          return isContentLoading
              ? (widget.loadingWidget ??
                  Center(
                    child: CircularProgressIndicator(),
                  ))
              : (aspectRatio != null)
                  ? AspectRatio(aspectRatio: aspectRatio!, child: webView)
                  : SizedBox(
                      height: _height,
                      child: SizedBox(height: _height, child: webView),
                    );
        });
    // return (aspectRatio != null)
    //     ? Stack(
    //         children: [
    //           ValueListenableBuilder<bool>(
    //               valueListenable: _isLoadingContent,
    //               builder: (_, isContentLoading, child) {
    //                 return isContentLoading
    //                     ? (widget.loadingWidget ??
    //                         Center(
    //                           child: CircularProgressIndicator(),
    //                         ))
    //                     : AspectRatio(aspectRatio: aspectRatio!, child: webView);
    //               }),
    //         ],
    //       )
    //     : Stack(
    //         children: [
    //           ValueListenableBuilder<bool>(
    //               valueListenable: _isLoadingContent,
    //               builder: (_, isContentLoading, child) {
    //                 return isContentLoading
    //                     ? SizedBox(
    //                         height: _height,
    //                         child: widget.loadingWidget ??
    //                             Center(
    //                               child: CircularProgressIndicator(),
    //                             ),
    //                       )
    //                     : SizedBox(height: _height, child: webView);
    //               }),
    //         ],
    //       );
  }

  JavascriptChannel _getHeightJavascriptChannel() {
    return JavascriptChannel(
        name: 'PageHeight',
        onMessageReceived: (JavascriptMessage message) {
          _setHeight(double.parse(message.message));
        });
  }

  void _setHeight(double height) {
    setState(() {
      _height = height + widget.socialMediaObj.bottomMargin;
    });
  }

  Color getBackgroundColor(BuildContext context) {
    return widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
  }

  String getHtmlBody() => """
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            *{box-sizing: border-box;margin:0px; padding:0px;}
              #widget {
                        display: flex;
                        justify-content: center;
                        margin: 0 auto;
                        max-width:100%;
                    }
          </style>
        </head>
        <body>
          <div id="widget" style="${widget.socialMediaObj.htmlInlineStyling}">${widget.socialMediaObj.htmlBody}</div>
          ${(widget.socialMediaObj.aspectRatio == null) ? dynamicHeightScriptSetup : ''}
          ${(widget.socialMediaObj.canChangeSize) ? dynamicHeightScriptCheck : ''}
        </body>
      </html>
    """;

  static const String dynamicHeightScriptSetup = """
    <script type="text/javascript">
      const widget = document.getElementById('widget');
      const sendHeight = () => PageHeight.postMessage(widget.clientHeight);
    </script>
  """;

  static const String dynamicHeightScriptCheck = """
    <script type="text/javascript">
      const onWidgetResize = (widgets) => sendHeight();
      const resize_ob = new ResizeObserver(onWidgetResize);
      resize_ob.observe(widget);
    </script>
  """;
}
