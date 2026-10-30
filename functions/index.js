const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

initializeApp();

exports.adminDeleteUser = onRequest(
  { region: 'asia-southeast1', cors: true },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: { message: 'Chỉ chấp nhận POST.' } });
      return;
    }

    try {
      const authorization = req.get('authorization') || '';
      const match = authorization.match(/^Bearer (.+)$/i);
      if (!match) {
        res.status(401).json({ error: { message: 'Vui lòng đăng nhập lại.' } });
        return;
      }

      const caller = await getAuth().verifyIdToken(match[1]);
      const callerProfile = await getFirestore().collection('users').doc(caller.uid).get();
      if (callerProfile.data()?.role !== 'admin') {
        res.status(403).json({ error: { message: 'Chỉ quản trị viên mới có thể xóa tài khoản.' } });
        return;
      }

      const uid = req.body?.data?.uid;
      if (typeof uid !== 'string' || !uid) {
        res.status(400).json({ error: { message: 'Thiếu mã tài khoản cần xóa.' } });
        return;
      }
      if (uid === caller.uid) {
        res.status(400).json({ error: { message: 'Không thể xóa tài khoản quản trị đang đăng nhập.' } });
        return;
      }

      const db = getFirestore();
      const profileRef = db.collection('users').doc(uid);
      const target = await profileRef.get();
      if (target.data()?.role === 'admin') {
        res.status(400).json({ error: { message: 'Không thể xóa tài khoản quản trị khác từ danh sách người đọc.' } });
        return;
      }

      try {
        await getStorage().bucket('appdoctruyen-5b8a7.firebasestorage.app').file(`users/${uid}/avatar`).delete({ ignoreNotFound: true });
      } catch (error) {
        console.warn('Could not remove user avatar:', error.message);
      }
      await getAuth().deleteUser(uid);
      await profileRef.delete();
      res.status(200).json({ result: { deleted: true } });
    } catch (error) {
      console.error('adminDeleteUser failed:', error);
      const status = error.code === 'auth/id-token-expired' || error.code === 'auth/invalid-id-token' ? 401 : 500;
      res.status(status).json({ error: { message: status === 401 ? 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.' : 'Không thể xóa tài khoản lúc này.' } });
    }
  },
);
