/// The one local profile of this app (no accounts, no server).
const kLocalUid = 'local';

class AppSession {
  final String uid;
  final String email;
  const AppSession(this.uid, {this.email = ''});
  bool get guest => true;
}
