importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyBUXkTRUhJT5heLAmdybesfEPBlsuys9AI",
  authDomain: "device-streaming-1d7576c5.firebaseapp.com",
  projectId: "device-streaming-1d7576c5",
  storageBucket: "device-streaming-1d7576c5.appspot.com",
  messagingSenderId: "288451811584",
  appId: "1:288451811584:web:8e4f1f176c09ad6d86bbe5"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
