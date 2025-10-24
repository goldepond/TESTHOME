/* =========================================== */
/* Flutter HouseMVP - VWorld API 프록시 서버 */
/* =========================================== */

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();
const PORT = 3001;

/* =========================================== */
/* 1. MIDDLEWARE SETUP */
/* =========================================== */

app.use(cors());
app.use(express.json());

// 요청 로깅
app.use((req, res, next) => {
    console.log(`\n🌐 ${req.method} ${req.url}`);
    next();
});

/* =========================================== */
/* 2. PROXY ROUTES - VWorld API */
/* =========================================== */

/**
 * VWorld Geocoder API 프록시
 * api.vworld.kr/req/address
 */
app.use('/api/geocoder', createProxyMiddleware({
    target: 'https://api.vworld.kr',
    changeOrigin: true,
    secure: false,
    pathRewrite: {
        '^/api/geocoder': '/req/address'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('🌍 [Geocoder API] 프록시 요청:', proxyReq.path);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log('📥 응답 상태:', proxyRes.statusCode);
    },
    onError: (err, req, res) => {
        console.error('❌ [Geocoder API] 프록시 오류:', err.message);
        res.status(500).json({ 
            error: 'Geocoder API 프록시 오류',
            message: err.message 
        });
    }
}));

/**
 * VWorld 토지특성공간정보 API 프록시
 * api.vworld.kr/ned/wfs/getLandCharacteristicsWFS
 */
app.use('/api/land', createProxyMiddleware({
    target: 'https://api.vworld.kr',
    changeOrigin: true,
    secure: false,
    pathRewrite: {
        '^/api/land': '/ned/wfs/getLandCharacteristicsWFS'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('🌍 [토지특성 API] 프록시 요청:', proxyReq.path);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log('📥 응답 상태:', proxyRes.statusCode);
    },
    onError: (err, req, res) => {
        console.error('❌ [토지특성 API] 프록시 오류:', err.message);
        res.status(500).json({ 
            error: '토지특성 API 프록시 오류',
            message: err.message 
        });
    }
}));

/**
 * VWorld 부동산중개업WFS조회 API 프록시
 * api.vworld.kr/ned/wfs/getEstateBrkpgWFS
 */
app.use('/api/broker', createProxyMiddleware({
    target: 'https://api.vworld.kr',
    changeOrigin: true,
    secure: false,
    pathRewrite: {
        '^/api/broker': '/ned/wfs/getEstateBrkpgWFS'
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log('🌍 [부동산중개업 API] 프록시 요청:', proxyReq.path);
    },
    onProxyRes: (proxyRes, req, res) => {
        console.log('📥 응답 상태:', proxyRes.statusCode);
    },
    onError: (err, req, res) => {
        console.error('❌ [부동산중개업 API] 프록시 오류:', err.message);
        res.status(500).json({ 
            error: '부동산중개업 API 프록시 오류',
            message: err.message 
        });
    }
}));

/* =========================================== */
/* 3. SERVER STARTUP */
/* =========================================== */

app.listen(PORT, () => {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🚀 Flutter VWorld API 프록시 서버 시작!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`📡 서버 주소: http://localhost:${PORT}`);
    console.log(`⏰ 시작 시간: ${new Date().toLocaleString('ko-KR')}`);
    console.log('\n📋 사용 가능한 API:');
    console.log('   ✅ /api/geocoder (좌표 변환 - VWorld)');
    console.log('   ✅ /api/land (토지특성 정보 - VWorld)');
    console.log('   ✅ /api/broker (공인중개사 검색 - VWorld)');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
});

/* =========================================== */
/* 4. ERROR HANDLING */
/* =========================================== */

process.on('uncaughtException', (err) => {
    console.error('❌ 처리되지 않은 예외:', err);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ 처리되지 않은 Promise 거부:', reason);
});


