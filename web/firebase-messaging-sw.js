importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyC5Yj9ZeV5tUF8e_K05vxHbYrVJ7nQvW84',
  appId: '1:1018586798653:web:904da780b6004266cae854',
  messagingSenderId: '1018586798653',
  projectId: 'houseproject-18f44',
  authDomain: 'houseproject-18f44.firebaseapp.com',
  storageBucket: 'houseproject-18f44.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  const notification = message.notification;
  if (!notification) return;

  return self.registration.showNotification(notification.title, {
    body: notification.body,
    icon: '/icons/Icon-192.png',
    data: message.data,
  });
});
