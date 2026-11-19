/// この端末のFCMトークンを外すことを、サーバーに拒否されたことを表す例外（機能仕様書4.1.7）
class TokenUnregisterDeniedException implements Exception {
  const TokenUnregisterDeniedException();
}
