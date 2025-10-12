// Web worker for SQLite operations
self.importScripts('sql-wasm.js');
let db;

self.onmessage = async function(e) {
  const msg = e.data;
  switch (msg.type) {
    case 'init':
      const SQL = await initSqlJs({
        locateFile: file => msg.config.baseUrl + file
      });
      db = new SQL.Database();
      self.postMessage({ type: 'initialized' });
      break;
    case 'exec':
      try {
        const result = db.exec(msg.sql);
        self.postMessage({ type: 'result', data: result });
      } catch (err) {
        self.postMessage({ type: 'error', error: err.message });
      }
      break;
  }
}; 