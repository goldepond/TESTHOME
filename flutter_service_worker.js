'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter.js": "888483df48293866f9f41d3d9274a779",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"test_markers.html": "ebff7a4622b209f07e7a34923d44e25b",
"manifest.json": "91e10b3469e398983e5b53fa03920a8c",
"sqflite_sw.dart": "61f0685ad3fee3cb0c704980964ba08d",
"index.html": "ebf8de0916ee38a66fcfd9cbe19c2abc",
"/": "ebf8de0916ee38a66fcfd9cbe19c2abc",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin.json": "eb9d33a780709e51b30e71582f09ffdd",
"assets/assets/sample_house3.jpg": "c094b59880cb344d2bcc13adbc7fa7b5",
"assets/assets/testcase.json": "ebe43026c5e5dc265988cf4142e828cb",
"assets/assets/contracts/whathouse/whathouse_pdf.pdf": "254f5b12bf6c509671e830f53c1472e9",
"assets/assets/contracts/whathouse/whathouse_10.html": "07c19161a85e61357f0815c4ab7aceab",
"assets/assets/contracts/whathouse/whathouse_11.html": "14e327fd8d91b8aab187339ef315938a",
"assets/assets/contracts/whathouse/whathouse_06.html": "7fc962e32ed84baf5369fed11db31ef3",
"assets/assets/contracts/whathouse/whathouse_02.html": "d775c4ed252dec71716b39d5daf0b43e",
"assets/assets/contracts/whathouse/whathouse_07.html": "0972744e270373f2714610116ebf5df9",
"assets/assets/contracts/whathouse/whathouse_12.html": "9526389165d54fef24671bd4ef81579c",
"assets/assets/contracts/whathouse/whathouse_style.css": "bbb5e47ba3d63f66dd0b04974e6a846b",
"assets/assets/contracts/whathouse/whathouse_custom.css": "8d54bef13cac2d452c2ee20979a247ca",
"assets/assets/contracts/whathouse/whathouse_01.html": "0a837fda4c0afd1983e9cf3b65a8bbc1",
"assets/assets/contracts/whathouse/whathouse_09.html": "48ae148c33f80f0762d4606fda24206e",
"assets/assets/contracts/whathouse/whathouse_08.html": "fe0a1fb8854bc56fdcfc02aa8b431bed",
"assets/assets/contracts/whathouse/whathouse_05.html": "025ce9e08055c878663008defc98bee0",
"assets/assets/contracts/whathouse/whathouse_04.html": "4bf5311255040d181a32d9561235f2b7",
"assets/assets/contracts/whathouse/whathouse_03.html": "aa0456e3fe6c4506fd8f712739252d88",
"assets/assets/contracts/House_Lease_Agreement/contract_generator.js": "8236d241cb8e65d243762aa8cccab320",
"assets/assets/contracts/House_Lease_Agreement/House_Lease_Agreement_5.html": "f86cbddf633cdb4c1fff15aff5e6ade8",
"assets/assets/contracts/House_Lease_Agreement/HL.pdf": "fadb1d03b9b728b3bdb81a07d6729ef5",
"assets/assets/contracts/House_Lease_Agreement/House_Lease_Agreement_3.html": "b36290f9c0b16c1d4a5b798164b09fae",
"assets/assets/contracts/House_Lease_Agreement/House_Lease_Agreement_style.css": "ed95fdc203c125034b71ff1baaf8b9c2",
"assets/assets/contracts/House_Lease_Agreement/index.html": "02af9dea6485c1e69f243074a2f8419c",
"assets/assets/contracts/House_Lease_Agreement/House_Lease_Agreement_2.html": "dcda6f6c463f0a39f6565aa2a0c08a94",
"assets/assets/contracts/House_Lease_Agreement/House_Lease_Agreement.html": "cc46a402b072cafcb28d43329b38e522",
"assets/assets/contracts/House_Lease_Agreement/House_Lease_Agreement_1.html": "a5711a7ac29c1f4338e5a84eccc0e6d2",
"assets/assets/contracts/House_Lease_Agreement/House_Lease_Agreement_4.html": "2f1f0aed6d7343c8dde7ffb3005a1761",
"assets/assets/contracts/House_Lease_Agreement/contract_input.html": "39e411b99e4d902482bed225cf0ab37b",
"assets/assets/fonts/static/NotoSansKR-Black.ttf": "15e2e9d1b8e380eafc51a606a7e671d6",
"assets/assets/fonts/static/NotoSansKR-Thin.ttf": "b59719d81a60f284b7c372c7891689fd",
"assets/assets/fonts/static/NotoSansKR-Regular.ttf": "e910afbd441c5247227fb4a731d65799",
"assets/assets/fonts/static/NotoSansKR-Light.ttf": "e61301e66b058697c6031c39edb7c0d2",
"assets/assets/fonts/static/NotoSansKR-Bold.ttf": "671db5f821991c90d7f8499bcf9fed7e",
"assets/assets/fonts/static/NotoSansKR-ExtraBold.ttf": "db13746e4342665b3fb5571c353f8c46",
"assets/assets/fonts/static/NotoSansKR-Medium.ttf": "4dee649c78a37741c4f5d9fdb69ea434",
"assets/assets/fonts/static/NotoSansKR-ExtraLight.ttf": "33e4ba0602de9a23075c13d344127395",
"assets/assets/fonts/static/NotoSansKR-SemiBold.ttf": "90c2026b48704ad2560e68249b15b7f5",
"assets/assets/sample_house2.jpg": "02e21990fd3f70465c21a745082a77b6",
"assets/assets/testcase.txt": "268e7a8c45f7f95f582f10660217883c",
"assets/assets/sample_house.jpg": "132cfe3a01db62ad3e33abb53ae46dad",
"assets/fonts/MaterialIcons-Regular.otf": "b84083ee8a5ceb3cc3040fe5d00064df",
"assets/NOTICES": "b31362e8f967bdcda162f152e9c139d2",
"assets/packages/flutter_naver_map/assets/font/Inter-fnm-scalebar-ss540.otf": "0dcd56f6f89392eb4a438991e0e4692d",
"assets/packages/flutter_naver_map/assets/icon/location_overlay_sub_icon_face.png": "7068b8f349f637d4f1e0403da60cd11b",
"assets/packages/flutter_naver_map/assets/icon/location_overlay_sub_icon.png": "cbcc0806d9a1e8c4b995f7ade0c3bcb9",
"assets/packages/flutter_naver_map/assets/icon/location_overlay_icon.png": "c18d8758d9d961b87fb1e8522e89dc66",
"assets/packages/flutter_naver_map/version.json": "d15b08d82524cddeffb5c6491ad397fc",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/FontManifest.json": "6debbc0a5366ecf828b8f441708d73df",
"assets/AssetManifest.bin": "3b750997061045ef792098e17b89f10b",
"assets/AssetManifest.json": "a483b9de704f7f1dd19bf4ed915e8bfc",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"sqflite_sw.js": "d2f78d266fa8653fc0a92c284fe71704",
"sql-wasm.js": "ae7f97c3e8695a30c1ecb294affa311b",
"flutter_bootstrap.js": "502d677b2fa36f590a8d476548f073a9",
"version.json": "f1294059d4d6ec2edb9b517c808a0670",
"main.dart.js": "d78ce1f4af7b8b3b70ce3d0e6fb347a2"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
