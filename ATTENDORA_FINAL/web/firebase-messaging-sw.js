importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "AIzaSyA68g7y_QxmC8bvRVTI-rRNNUSEbrEuCRY",
  authDomain: "attendora-a0fc5.firebaseapp.com",
  projectId: "attendora-a0fc5",
  storageBucket: "attendora-a0fc5.firebasestorage.app",
  messagingSenderId: "623151828674",
  appId: "1:623151828674:web:5fe4c614fc8839db4e355b"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
