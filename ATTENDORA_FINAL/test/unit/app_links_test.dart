import 'package:attendora/core/config/app_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeDownloadUrl - Google Drive', () {
    const direct = 'https://drive.google.com/uc?export=download&id=1AbC_dEf-9';

    test('converts a /file/d/ID/view share link to a direct download', () {
      expect(
        normalizeDownloadUrl(
          'https://drive.google.com/file/d/1AbC_dEf-9/view?usp=sharing',
        ).toString(),
        direct,
      );
    });

    test('converts an open?id= link', () {
      expect(
        normalizeDownloadUrl(
          'https://drive.google.com/open?id=1AbC_dEf-9',
        ).toString(),
        direct,
      );
    });

    test('keeps an existing uc?export=download link working', () {
      expect(
        normalizeDownloadUrl(
          'https://drive.google.com/uc?id=1AbC_dEf-9&export=download',
        ).toString(),
        direct,
      );
    });

    test('tolerates surrounding whitespace from a paste', () {
      expect(
        normalizeDownloadUrl(
          '  https://drive.google.com/file/d/1AbC_dEf-9/view  \n',
        ).toString(),
        direct,
      );
    });
  });

  group('normalizeDownloadUrl - other hosts', () {
    test('passes a normal https link through unchanged', () {
      expect(
        normalizeDownloadUrl('https://example.com/app.apk').toString(),
        'https://example.com/app.apk',
      );
    });

    test('a Drive folder or unrelated Drive page is left alone', () {
      expect(
        normalizeDownloadUrl('https://drive.google.com/drive/folders/abc')
            .toString(),
        'https://drive.google.com/drive/folders/abc',
      );
    });
  });

  group('normalizeDownloadUrl - refuses anything that is not a web link', () {
    // The value comes from Firestore and ends up in launchUrl(), so only
    // http(s) may ever get through.
    for (final bad in [
      '',
      '   ',
      'not a url',
      'javascript:alert(1)',
      'file:///etc/passwd',
      'intent://scan/#Intent;scheme=zxing;end',
      'data:text/html,<script>1</script>',
      'ftp://example.com/app.apk',
      'https://',
    ]) {
      test('rejects "$bad"', () {
        expect(normalizeDownloadUrl(bad), isNull);
      });
    }
  });
}
