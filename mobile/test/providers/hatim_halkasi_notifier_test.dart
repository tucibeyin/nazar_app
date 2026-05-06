import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nazar_app/models/hatim_room.dart';
import 'package:nazar_app/providers/hatim_halkasi_provider.dart';
import 'package:nazar_app/services/api_service.dart';

class _MockApiService extends Mock implements ApiService {}

HatimRoom _room({String code = 'ABC123', int juzCount = 30}) => HatimRoom(
      code: code,
      createdAt: '2026-01-01T00:00:00',
      juzler: List.generate(
        juzCount,
        (i) => JuzItem(juzNum: i + 1, durum: JuzDurum.bos),
      ),
    );

void main() {
  late _MockApiService mockApi;
  late HatimHalkasiNotifier notifier;

  setUp(() {
    mockApi = _MockApiService();
    notifier = HatimHalkasiNotifier(mockApi);
  });

  tearDown(() => notifier.dispose());

  group('HatimHalkasiNotifier.createRoom', () {
    test('başarılı → roomCode ve juzler ayarlanır', () async {
      when(() => mockApi.createHatimRoom())
          .thenAnswer((_) async => _room(code: 'XYZ789'));

      await notifier.createRoom();

      expect(notifier.state.roomCode, 'XYZ789');
      expect(notifier.state.juzler.length, 30);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('ApiException → error mesajı ayarlanır, roomCode null kalır', () async {
      when(() => mockApi.createHatimRoom())
          .thenThrow(const ApiException('Oda oluşturulamadı.'));

      await notifier.createRoom();

      expect(notifier.state.roomCode, isNull);
      expect(notifier.state.error, 'Oda oluşturulamadı.');
      expect(notifier.state.isLoading, isFalse);
    });
  });

  group('HatimHalkasiNotifier.joinRoom', () {
    test('başarılı → roomCode ayarlanır', () async {
      when(() => mockApi.getHatimRoom('CODE01'))
          .thenAnswer((_) async => _room(code: 'CODE01'));

      await notifier.joinRoom('code01'); // büyük harfe çevrilmeli

      expect(notifier.state.roomCode, 'CODE01');
      expect(notifier.state.isLoading, isFalse);
    });

    test('ApiException → error ayarlanır', () async {
      when(() => mockApi.getHatimRoom(any()))
          .thenThrow(const ApiException('Oda bulunamadı.', statusCode: 404));

      await notifier.joinRoom('YANLISOD');

      expect(notifier.state.roomCode, isNull);
      expect(notifier.state.error, 'Oda bulunamadı.');
    });
  });

  group('HatimHalkasiNotifier.updateJuz', () {
    setUp(() async {
      when(() => mockApi.createHatimRoom())
          .thenAnswer((_) async => _room());
      when(() => mockApi.updateHatimJuz(any(), any(), any()))
          .thenAnswer((_) async {});
      await notifier.createRoom();
    });

    test('optimistic update cüzün durumunu hemen değiştirir', () async {
      await notifier.updateJuz(5, JuzDurum.alindi);

      final juz = notifier.state.juzler.firstWhere((j) => j.juzNum == 5);
      expect(juz.durum, JuzDurum.alindi);
    });

    test('API\'ye durum adını string olarak gönderir', () async {
      await notifier.updateJuz(3, JuzDurum.okundu);

      verify(() => mockApi.updateHatimJuz('ABC123', 3, 'okundu')).called(1);
    });

    test('API hatası → rollback ve error mesajı', () async {
      when(() => mockApi.updateHatimJuz(any(), any(), any()))
          .thenThrow(const ApiException('Güncelleme başarısız.'));
      when(() => mockApi.getHatimRoom(any()))
          .thenAnswer((_) async => _room()); // refresh için

      await notifier.updateJuz(1, JuzDurum.alindi);

      expect(notifier.state.error, 'Güncelleme başarısız.');
    });

    test('boş cüz → \'bos\' olarak güncellenebilir', () async {
      await notifier.updateJuz(10, JuzDurum.alindi);
      await notifier.updateJuz(10, JuzDurum.bos);

      verify(() => mockApi.updateHatimJuz('ABC123', 10, 'bos')).called(1);
      final juz = notifier.state.juzler.firstWhere((j) => j.juzNum == 10);
      expect(juz.durum, JuzDurum.bos);
    });
  });

  group('HatimHalkasiNotifier.leaveRoom', () {
    test('state tamamen sıfırlanır', () async {
      when(() => mockApi.createHatimRoom())
          .thenAnswer((_) async => _room(code: 'XY1'));
      await notifier.createRoom();
      expect(notifier.state.roomCode, isNotNull);

      notifier.leaveRoom();

      expect(notifier.state.roomCode, isNull);
      expect(notifier.state.juzler, isEmpty);
      expect(notifier.state.isLoading, isFalse);
    });
  });

  group('HatimHalkasiNotifier.refresh', () {
    test('roomCode yoksa API çağrısı yapılmaz', () async {
      await notifier.refresh();
      verifyNever(() => mockApi.getHatimRoom(any()));
    });

    test('roomCode varsa juzler güncellenir', () async {
      when(() => mockApi.createHatimRoom())
          .thenAnswer((_) async => _room(code: 'R1'));

      final refreshedJuzler = List.generate(
        30,
        (i) => JuzItem(
          juzNum: i + 1,
          durum: i == 0 ? JuzDurum.okundu : JuzDurum.bos,
        ),
      );
      when(() => mockApi.getHatimRoom('R1')).thenAnswer((_) async =>
          HatimRoom(code: 'R1', createdAt: '', juzler: refreshedJuzler));

      await notifier.createRoom();
      await notifier.refresh();

      expect(notifier.state.juzler.first.durum, JuzDurum.okundu);
    });
  });
}
