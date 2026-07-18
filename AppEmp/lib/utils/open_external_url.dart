import 'open_external_url_stub.dart'
    if (dart.library.html) 'open_external_url_web.dart' as impl;

/// فتح رابط خارجي بشكل موثوق على الويب والموبايل.
bool openExternalUrl(String url) => impl.openExternalUrl(url);
