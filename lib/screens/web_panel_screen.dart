import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebPanelScreen extends StatefulWidget {
  const WebPanelScreen({super.key});

  @override
  State<WebPanelScreen> createState() => _WebPanelScreenState();
}

class _WebPanelScreenState extends State<WebPanelScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _pageTitle = 'Panel Web';
  bool _showLoginMessage = false;
  String _currentUrl = '';
  Timer? _urlCheckTimer;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
              // Ocultar mensaje mientras navega
              _showLoginMessage = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
              // Usar función específica para detectar página de login
              _showLoginMessage = _isLoginPage(url);
            });
            _updatePageTitle();
            
            // Iniciar monitoreo de URL para detectar navegación SPA
            _startUrlMonitoring();
            
            // Debug: imprimir la URL para verificar
            print('WebPanel URL loaded: $url');
            print('Show login message: $_showLoginMessage');
          },
          onWebResourceError: (WebResourceError error) {
            print('Error cargando página web: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://bipealerta.com/login/1'));
  }

  void _updatePageTitle() async {
    final String? title = await _controller.getTitle();
    if (title != null && mounted) {
      setState(() {
        _pageTitle = title;
      });
    }
  }

  void _reloadPage() {
    _controller.reload();
  }

  void _goBack() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
    }
  }

  void _goForward() async {
    if (await _controller.canGoForward()) {
      _controller.goForward();
    }
  }

  bool _isLoginPage(String url) {
    // Verificar si estamos exactamente en la página de login para Blazor WASM
    final uri = Uri.parse(url);
    
    // Solo mostrar mensaje si estamos exactamente en /login
    // Si está en /menu u otra ruta, significa que ya está logueado
    return uri.path == '/login/1' || uri.path == '/login/1/';
  }

  void _startUrlMonitoring() {
    // Verificar la URL cada 1 segundo para detectar cambios en SPA
    _urlCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final currentUrl = await _controller.currentUrl();
        if (currentUrl != null && currentUrl != _currentUrl) {
          print('URL changed from $_currentUrl to $currentUrl');
          
          setState(() {
            _currentUrl = currentUrl;
            _showLoginMessage = _isLoginPage(currentUrl);
          });
          
          print('Show login message: $_showLoginMessage');
        }
      } catch (e) {
        print('Error checking URL: $e');
      }
    });
  }

  void _stopUrlMonitoring() {
    _urlCheckTimer?.cancel();
    _urlCheckTimer = null;
  }

  @override
  void dispose() {
    _stopUrlMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8A56FF),
      body: SafeArea(
        child: Column(
          children: [
            // Header personalizado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8A56FF),
                    Color(0xFF9E73FF),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          _pageTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _reloadPage,
                      ),
                    ],
                  ),
                  // Barra de navegación
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: _goBack,
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                        onPressed: _goForward,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Mensaje de login si es necesario
            if (_showLoginMessage && !_isLoading)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Coloca las mismas credenciales con las que entraste a la app',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // WebView container
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _controller),
                      if (_isLoading)
                        Container(
                          color: Colors.white,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Color(0xFF8A56FF),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Cargando panel web...',
                                  style: TextStyle(
                                    color: Color(0xFF8A56FF),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 