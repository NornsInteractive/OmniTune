import 'package:flutter_test/flutter_test.dart';

import 'package:music/features/sources/data/webdav/webdav_remote_client.dart';

void main() {
  test('parses encoded href values with spaces and unicode characters', () {
    const xml = '''
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/remote.php/dav/files/demo/</d:href>
    <d:propstat>
      <d:status>HTTP/1.1 200 OK</d:status>
      <d:prop>
        <d:displayname>demo</d:displayname>
        <d:resourcetype><d:collection/></d:resourcetype>
      </d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/demo/Album%20One/</d:href>
    <d:propstat>
      <d:status>HTTP/1.1 200 OK</d:status>
      <d:prop>
        <d:displayname>Album One</d:displayname>
        <d:resourcetype><d:collection/></d:resourcetype>
      </d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/demo/%E5%91%A8%E6%9D%B0%E4%BC%A6%20-%20%E7%AE%80%E5%8D%95%E7%88%B1.flac</d:href>
    <d:propstat>
      <d:status>HTTP/1.1 200 OK</d:status>
      <d:prop>
        <d:displayname>周杰伦 - 简单爱.flac</d:displayname>
        <d:resourcetype />
        <d:getcontenttype>audio/flac</d:getcontenttype>
        <d:getcontentlength>1024</d:getcontentlength>
      </d:prop>
    </d:propstat>
  </d:response>
</d:multistatus>
''';

    final result = parseWebDavDirectoryResponse(
      xmlContent: xml,
      requestPath: '/',
      baseUri: Uri.parse('https://dav.example.com/remote.php/dav/files/demo/'),
      requestUri: Uri.parse(
        'https://dav.example.com/remote.php/dav/files/demo/',
      ),
    );

    expect(result.length, 2);
    expect(result.first.path, '/Album One/');
    expect(result.first.name, 'Album One');
    expect(result.last.path, '/周杰伦 - 简单爱.flac');
    expect(result.last.name, '周杰伦 - 简单爱.flac');
  });

  test('resolves relative href values against the current request path', () {
    const xml = '''
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>Album%20One/</d:href>
    <d:propstat>
      <d:status>HTTP/1.1 200 OK</d:status>
      <d:prop>
        <d:displayname>Album One</d:displayname>
        <d:resourcetype><d:collection/></d:resourcetype>
      </d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>song%20one.flac</d:href>
    <d:propstat>
      <d:status>HTTP/1.1 200 OK</d:status>
      <d:prop>
        <d:displayname>song one.flac</d:displayname>
        <d:resourcetype />
        <d:getcontenttype>audio/flac</d:getcontenttype>
      </d:prop>
    </d:propstat>
  </d:response>
</d:multistatus>
''';

    final result = parseWebDavDirectoryResponse(
      xmlContent: xml,
      requestPath: '/Music/',
      baseUri: Uri.parse('https://dav.example.com/remote.php/webdav/'),
      requestUri: Uri.parse('https://dav.example.com/remote.php/webdav/Music/'),
    );

    expect(result.length, 2);
    expect(result.first.path, '/Music/Album One/');
    expect(result.last.path, '/Music/song one.flac');
  });
}
