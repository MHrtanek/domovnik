importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCtaZ0rWoBEvZTU0ctNwjOZAoa4yGpPyWM",
  authDomain: "domovnik-e1e51.firebaseapp.com",
  projectId: "domovnik-e1e51",
  storageBucket: "domovnik-e1e51.firebasestorage.app",
  messagingSenderId: "56523663052",
  appId: "1:56523663052:web:fa2b358f894973edba0469",
  measurementId: "G-LFBTM4H74K"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification;
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
  });
});
