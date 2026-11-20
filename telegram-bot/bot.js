/**
 * Ví Đôi — Telegram Bot Ghi Chép Nhanh Cho Hai Vợ Chồng (Bảo & Oanh)
 * Đồng bộ thời gian thực 2 chiều với Ví Đôi PWA
 * Không cần thư viện ngoài (sử dụng Native fetch & Node.js 18+)
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Tự động đọc cấu hình từ file .env (không cần thư viện ngoài)
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
  try {
    const envContent = fs.readFileSync(envPath, 'utf8');
    envContent.split(/\r?\n/).forEach(line => {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith('#')) {
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx > 0) {
          const key = trimmed.slice(0, eqIdx).trim();
          let val = trimmed.slice(eqIdx + 1).trim();
          if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
            val = val.slice(1, -1);
          }
          if (!process.env[key]) {
            process.env[key] = val;
          }
        }
      }
    });
  } catch (err) {
    console.warn('⚠️ Không thể đọc file .env:', err.message);
  }
}

// 1. Cấu hình Môi trường
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '';
const FAMILY_CODE = (process.env.FAMILY_CODE || 'BO8686').toUpperCase();
const FAMILY_PIN = process.env.FAMILY_PIN || '2611';
const DEFAULT_GEMINI_KEY = Buffer.from('QVEuQWI4Uk42SU90UXROZWh3YXVJaXJ6Tjc5bjgyc2hKeW1oUXBWRHNldUhIc19wVWpKdVE=', 'base64').toString('utf8');
const GEMINI_API_KEY = (process.env.GEMINI_API_KEY && process.env.GEMINI_API_KEY.trim()) || DEFAULT_GEMINI_KEY;
const GEMINI_MODEL = (process.env.GEMINI_MODEL && process.env.GEMINI_MODEL.trim()) || 'gemini-3.5-flash-lite';
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');

if (!BOT_TOKEN) {
  console.error('❌ LỖI: Vui lòng cung cấp TELEGRAM_BOT_TOKEN trong file .env hoặc biến môi trường!');
  console.error('Ví dụ: TELEGRAM_BOT_TOKEN="123456789:ABCdefGhIJKlmNoPQRstuVWXyz"');
  process.exit(1);
}

if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

const DB_FILE = path.join(DATA_DIR, 'database.json');

// 2. Thuật toán Sinh Topic bí mật đồng bộ đám mây (Trùng khớp 100% với PWA index.html)
function hashSecretTopic(code, pin) {
  const str = `BAO_OANH_SECRET_${code}_${pin}_v2`;
  let h1 = 0xdeadbeef ^ str.length, h2 = 0x41c6ce57 ^ str.length;
  for (let i = 0, ch; i < str.length; i++) {
    ch = str.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(36);
}

const CLOUD_TOPIC = 'vidoi_bo_priv_' + hashSecretTopic(FAMILY_CODE, FAMILY_PIN);

// 3. Cơ sở dữ liệu Cục bộ (Hỗ trợ Đa tài khoản: Tiền mặt, ACB, MB, VIB, Thẻ tín dụng...)
function ensureBotWallets(db) {
  const defaultWallets = [
    { id: 'cash', name: 'Tiền mặt', icon: '💵', balance: 0, owner: 'him', color: '#22C55E,#4ade80', match: 'tiền mặt' },
    { id: 'acb', name: 'Ngân hàng ACB', icon: '🏦', balance: 0, owner: 'S', color: '#0066FF,#38bdf8', match: 'acb' },
    { id: 'mb', name: 'Ngân hàng MB', icon: '🏦', balance: 0, owner: 'him', color: '#4F46E5,#818cf8', match: 'mb' },
    { id: 'vib', name: 'Ngân hàng VIB', icon: '🏦', balance: 0, owner: 'him', color: '#F97316,#fb923c', match: 'vib' },
    { id: 'tcb', name: 'Thẻ tín dụng', icon: '💳', balance: 0, owner: 'him', color: '#EF4444,#fb7185', match: 'tín dụng' },
    { id: 'momo', name: 'Ví riêng (Oanh)', icon: '📱', balance: 0, owner: 'her', color: '#EC4899,#f9a8d4', match: 'oanh' }
  ];
  if (!Array.isArray(db.wallets) || db.wallets.length === 0) {
    db.wallets = defaultWallets.map(({ match, ...rest }) => rest);
  } else {
    const cashW = db.wallets.find(w => w.id === 'cash');
    if (cashW && cashW.name === 'Tiền mặt (Bảo)') cashW.name = 'Tiền mặt';
    defaultWallets.forEach(dw => {
      const exists = db.wallets.some(w => w.id === dw.id || (w.name && w.name.toLowerCase().includes(dw.match)));
      if (!exists) {
        const { match, ...cleanW } = dw;
        db.wallets.push(cleanW);
      }
    });
  }
  return db;
}

function loadDB() {
  if (fs.existsSync(DB_FILE)) {
    try {
      const loaded = JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
      return ensureBotWallets(loaded);
    } catch (e) {
      console.warn('⚠️ Không thể đọc database.json, khởi tạo lại');
    }
  }
  return ensureBotWallets({
    users: {
      him: { name: 'Bảo', color: '#4C8DFF', role: 'Chồng' },
      her: { name: 'Oanh', color: '#FF7EB6', role: 'Vợ' }
    },
    telegramUsers: {}, // { "12345678": "him", "87654321": "her" }
    wallets: [],
    deletedTxIds: [],
    transactions: []
  });
}

const DB = loadDB();

function saveDB() {
  fs.writeFileSync(DB_FILE, JSON.stringify(DB, null, 2), 'utf8');
}

// 4. Đồng bộ Realtime 2 chiều (PWA ⇄ Telegram Bot) qua ntfy.sh + Giải mã E2EE
function getBotE2EEKey() {
  return crypto.pbkdf2Sync(FAMILY_PIN, 'ViDoi_E2EE_' + FAMILY_CODE, 100000, 32, 'sha256');
}

function decryptE2EE(packet) {
  if (!packet) return null;
  if (!packet._e2ee || !packet.cipher || !packet.iv) return packet;
  try {
    const key = getBotE2EEKey();
    const iv = Buffer.from(packet.iv, 'base64');
    const fullCipher = Buffer.from(packet.cipher, 'base64');
    if (fullCipher.length <= 16) return null;
    const authTag = fullCipher.subarray(fullCipher.length - 16);
    const data = fullCipher.subarray(0, fullCipher.length - 16);
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(authTag);
    const dec = Buffer.concat([decipher.update(data), decipher.final()]);
    return JSON.parse(dec.toString('utf8'));
  } catch (e) {
    return null;
  }
}

let lastCloudPullTime = 0;

async function pullFromPWA(force = false) {
  const now = Date.now();
  if (!force && (now - lastCloudPullTime < 12000)) return false;
  lastCloudPullTime = now;
  try {
    const res = await fetch(`https://ntfy.sh/${CLOUD_TOPIC}/json?poll=1&since=24h`);
    if (!res.ok) return false;
    const text = await res.text();
    const lines = text.trim().split('\n').filter(Boolean);
    let updated = false;
    for (const line of lines) {
      try {
        const ev = JSON.parse(line);
        if (!ev || ev.event !== 'message') continue;
        let rawMsg = ev.message;
        if (ev.attachment && ev.attachment.url) {
          const attRes = await fetch(ev.attachment.url);
          if (attRes.ok) rawMsg = await attRes.text();
        }
        if (!rawMsg) continue;
        let remote = JSON.parse(rawMsg);
        if (remote && remote._e2ee) remote = decryptE2EE(remote);
        if (!remote || remote._v !== 2 || String(remote.deviceId || '').startsWith('telegram_bot_')) continue;

        // Đồng bộ danh sách Ví & Tài khoản từ App điện thoại sang Bot
        if (Array.isArray(remote.wallets) && remote.wallets.length > 0) {
          const localWMap = new Map((DB.wallets || []).map(w => [w.id, w]));
          for (const rw of remote.wallets) {
            if (!rw || !rw.id) continue;
            if (localWMap.has(rw.id)) {
              const lw = localWMap.get(rw.id);
              lw.name = rw.name || lw.name;
              lw.icon = rw.icon || lw.icon;
              lw.owner = rw.owner || lw.owner;
              lw.color = rw.color || lw.color;
              if ((remote.ts || 0) >= (DB.updatedAt || 0)) {
                lw.balance = rw.balance;
              }
            } else {
              DB.wallets.push(rw);
              localWMap.set(rw.id, rw);
            }
          }
          updated = true;
        }

        // Đồng bộ danh sách Giao dịch & ID đã xóa từ App điện thoại sang Bot để kiểm tra trùng lặp chính xác 100%
        if (Array.isArray(remote.deletedTxIds) && remote.deletedTxIds.length > 0) {
          const delSet = new Set([...(DB.deletedTxIds || []), ...remote.deletedTxIds]);
          if (delSet.size !== (DB.deletedTxIds || []).length) {
            DB.deletedTxIds = Array.from(delSet);
            DB.transactions = (DB.transactions || []).filter(t => !delSet.has(t.id));
            updated = true;
          }
        }
        if (Array.isArray(remote.transactions) && remote.transactions.length > 0) {
          const delSet = new Set(DB.deletedTxIds || []);
          const localTxMap = new Map((DB.transactions || []).map(t => [t.id, t]));
          for (const rTx of remote.transactions) {
            if (!rTx || !rTx.id || delSet.has(rTx.id)) continue;
            if (!localTxMap.has(rTx.id)) {
              DB.transactions.push(rTx);
              localTxMap.set(rTx.id, rTx);
              updated = true;
            }
          }
        }
      } catch (e) {}
    }
    if (updated) {
      ensureBotWallets(DB);
      saveDB();
    }
    return updated;
  } catch (err) {
    return false;
  }
}

async function broadcastToPWA(payload) {
  try {
    DB.updatedAt = Date.now();
    let thumbQuota = 15;
    const compactTxs = (DB.transactions || []).slice(0, 100).map(t => {
      const copy = { ...t };
      if (copy.receiptThumb) {
        if (thumbQuota > 0) thumbQuota--;
        else delete copy.receiptThumb;
      }
      return copy;
    });

    const compactPayload = {
      _v: 2,
      deviceId: 'telegram_bot_' + Date.now().toString(36),
      ts: DB.updatedAt,
      familyCode: FAMILY_CODE,
      familyPin: FAMILY_PIN,
      users: DB.users,
      wallets: DB.wallets,
      deletedTxIds: (DB.deletedTxIds || []).slice(-200),
      transactions: compactTxs,
      ...payload
    };

    const res = await fetch(`https://ntfy.sh/${CLOUD_TOPIC}`, {
      method: 'POST',
      headers: {
        'Title': 'ViDoiTelegramSync',
        'Priority': 'default'
      },
      body: JSON.stringify(compactPayload)
    });

    return res.ok;
  } catch (err) {
    console.warn('⚠️ Lỗi gửi đồng bộ ntfy:', err.message);
    return false;
  }
}

// Đồng bộ ảnh hóa đơn độ phân giải cao từ Telegram Bot lên kênh đám mây cho 2 điện thoại
async function pushReceiptToCloudFromBot(rcptId, dataUrl) {
  if (!rcptId || !dataUrl) return false;
  try {
    const topic = `${CLOUD_TOPIC}_rcpt`;
    const bodyObj = { _rcpt: true, id: rcptId, data: dataUrl, ts: Date.now() };
    const res = await fetch(`https://ntfy.sh/${topic}`, {
      method: 'POST',
      headers: {
        'Title': rcptId,
        'Priority': 'low'
      },
      body: JSON.stringify(bodyObj)
    });
    return res.ok;
  } catch (err) {
    console.warn('⚠️ Lỗi đồng bộ ảnh hóa đơn từ Bot:', err.message);
    return false;
  }
}

// 5. Bộ phân tích Ngôn ngữ Tự nhiên Tiếng Việt (NLP Parser)
const CATEGORY_MAP = [
  { cat: 'Ăn uống', icon: '🍜', keywords: ['an', 'ăn', 'com', 'cơm', 'pho', 'phở', 'bun', 'bún', 'cf', 'cafe', 'cà phê', 'ca phe', 'tra', 'trà', 'lau', 'lẩu', 'nuong', 'nướng', 'nhau', 'nhậu', 'pizza', 'tra sua', 'trà sữa', 'banh', 'bánh'] },
  { cat: 'Chợ & Siêu thị', icon: '🛒', keywords: ['cho', 'chợ', 'sieu thi', 'siêu thị', 'winmart', 'coop', 'bach hoa', 'bách hóa', 'rau', 'thit', 'thịt', 'ca', 'cá', 'trung', 'trứng', 'hoa qua', 'trái cây', 'tap hoa', 'tạp hóa'] },
  { cat: 'Nhà cửa', icon: '🏠', keywords: ['nha', 'nhà', 'thue nha', 'thuê nhà', 'dien', 'điện', 'nuoc', 'nước', 'internet', 'wifi', 'sua nha', 'sửa nhà', 'do gia dung', 'gia dụng', 'noi that', 'nội thất'] },
  { cat: 'Hóa đơn', icon: '💡', keywords: ['hoa don', 'hóa đơn', 'tien dien', 'tiền điện', 'tien nuoc', 'tiền nước', 'tien mang', 'tiền mạng', 'cuoc', 'cước', 'rac', 'rác', 've sinh', 'vệ sinh', 'phi chung cu', 'phí chung cư'] },
  { cat: 'Đi lại', icon: '⛽', keywords: ['xang', 'xăng', 'gui xe', 'gửi xe', 'grab', 'be', 'taxi', 'rua xe', 'rửa xe', 'sua xe', 'sửa xe', 'cau duong', 'cầu đường', 've xe', 'vé xe', 'may bay', 'máy bay'] },
  { cat: 'Con cái', icon: '👶', keywords: ['con', 'bim', 'bỉm', 'sua', 'sữa', 'hoc phi', 'học phí', 'do choi', 'đồ chơi', 'tiem chung', 'tiêm chủng', 'sach vo', 'sách vở'] },
  { cat: 'Mua sắm', icon: '🛍️', keywords: ['mua', 'shopee', 'lazada', 'tiktok', 'quan ao', 'quần áo', 'giay dep', 'giày dép', 'my pham', 'mỹ phẩm', 'dong ho', 'đồng hồ', 'tui', 'túi'] },
  { cat: 'Giải trí', icon: '🎬', keywords: ['xem phim', 'rap', 'rạp', 'du lich', 'du lịch', 'khach san', 'resort', 'choi', 'chơi', 'karaoke', 'game', 'netflix', 'spotify'] },
  { cat: 'Sức khỏe', icon: '💊', keywords: ['thuoc', 'thuốc', 'kham', 'khám', 'benh vien', 'bệnh viện', 'nha khoa', 'rang', 'răng', 'bao hiem', 'bảo hiểm', 'gym', 'yoga', 'vitamin'] },
  { cat: 'Cho vay', icon: '🤝', keywords: ['cho vay', 'cho muon', 'cho mượn'] },
  { cat: 'Gửi tiết kiệm', icon: '🏦', keywords: ['tiet kiem', 'tiết kiệm', 'gui tiet kiem', 'gửi tiết kiệm', 'so tiet kiem', 'sổ tiết kiệm'] },
  { cat: 'Đầu tư', icon: '📈', keywords: ['dau tu', 'đầu tư', 'chung khoan', 'chứng khoán', 'vang', 'vàng', 'crypto', 'coin', 'bds', 'đất'] }
];

const INCOME_MAP = [
  { cat: 'Lương & Thưởng', icon: '💰', keywords: ['luong', 'lương', 'thuong', 'thưởng', 'ung luong', 'ứng lương'] },
  { cat: 'Kinh doanh', icon: '💼', keywords: ['ban hang', 'bán hàng', 'kinh doanh', 'doanh thu', 'lai', 'lãi'] },
  { cat: 'Đầu tư & Lãi', icon: '📈', keywords: ['lai ngan hang', 'lãi ngân hàng', 'co tuc', 'cổ tức', 'chot lai', 'chốt lãi'] },
  { cat: 'Được tặng / Cho', icon: '🎁', keywords: ['tang', 'tặng', 'cho', 'mung', 'mừng', 'li xi', 'lì xì'] },
  { cat: 'Thu nợ', icon: '🤝', keywords: ['thu no', 'thu nợ', 'tra no', 'trả nợ', 'doi no', 'đòi nợ'] }
];

function parseAmount(text) {
  // 1tr5 -> 1500000; 1.5tr -> 1500000; 2tr -> 2000000; 50k -> 50000; 120000 -> 120000
  const normalized = text.toLowerCase().replace(/,/g, '.');

  // Case 1: 1tr5, 2tr8, 10tr2
  const mTrK = normalized.match(/(\d+(?:\.\d+)?)\s*tr\s*(\d+)?/i);
  if (mTrK) {
    const whole = parseFloat(mTrK[1]) * 1000000;
    let frac = 0;
    if (mTrK[2]) {
      const fracNum = parseInt(mTrK[2], 10);
      frac = fracNum < 10 ? fracNum * 100000 : fracNum * 10000;
    }
    return Math.round(whole + frac);
  }

  // Case 2: 50k, 100k, 500k
  const mK = normalized.match(/(\d+(?:\.\d+)?)\s*k\b/i);
  if (mK) {
    return Math.round(parseFloat(mK[1]) * 1000);
  }

  // Case 3: 50000, 100000, 1.000.000
  const cleanDots = normalized.replace(/\.(?=\d{3})/g, '');
  const mNum = cleanDots.match(/\b(\d{3,10})\b/);
  if (mNum) {
    return parseInt(mNum[1], 10);
  }

  return null;
}

function matchKeyword(text, keyword) {
  if (keyword.includes(' ')) {
    return text.includes(keyword);
  }
  const regex = new RegExp(`(^|\\s|[.,!?;:/-])${keyword}($|\\s|[.,!?;:/-])`, 'i');
  return regex.test(text);
}

function removeAccents(str) {
  return String(str || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase();
}

function findWalletByIdOrKeyword(kw) {
  if (!kw) return null;
  const cleanKw = removeAccents(kw).trim();
  if (!cleanKw) return null;
  const exact = DB.wallets.find(w => removeAccents(w.id) === cleanKw);
  if (exact) return exact.id;
  const byName = DB.wallets.find(w => removeAccents(w.name).includes(cleanKw));
  if (byName) return byName.id;
  return null;
}

function ensureDynamicBankWallet(id, name, icon = '🏦', owner = 'him', color = '#0066FF,#38bdf8') {
  const existing = findWalletByIdOrKeyword(id) || findWalletByIdOrKeyword(name);
  if (existing) return existing;
  const newW = { id, name, icon, balance: 0, owner, color };
  DB.wallets.push(newW);
  saveDB();
  return newW.id;
}

function getDefaultWalletForRole(role = 'him') {
  if (DB.defaultWallet && DB.defaultWallet[role]) {
    const exists = DB.wallets.some(w => w.id === DB.defaultWallet[role]);
    if (exists) return DB.defaultWallet[role];
  }
  if (role === 'her') {
    return findWalletByIdOrKeyword('momo') || findWalletByIdOrKeyword('oanh') || DB.wallets[0].id;
  }
  return findWalletByIdOrKeyword('cash') || findWalletByIdOrKeyword('tien mat') || DB.wallets[0].id;
}

function parseWallet(text) {
  if (!text) return null;
  const norm = ' ' + removeAccents(text).replace(/[^a-z0-9]+/g, ' ').trim() + ' ';

  // 1. Quét ưu tiên các từ khóa Ngân hàng & Tài khoản rõ ràng trong câu
  if (/\s(acb|a chau)\s/.test(norm)) {
    return ensureDynamicBankWallet('acb', 'Ngân hàng ACB', '🏦', 'S', '#0066FF,#38bdf8');
  }
  if (/\s(mb|mbbank|quan doi)\s/.test(norm)) {
    return ensureDynamicBankWallet('mb', 'Ngân hàng MB', '🏦', 'him', '#4F46E5,#818cf8');
  }
  if (/\s(vib|myvib|quoc te)\s/.test(norm)) {
    return ensureDynamicBankWallet('vib', 'Ngân hàng VIB', '🏦', 'him', '#F97316,#fb923c');
  }
  if (/\s(tin dung|the tin dung|credit|visa|mastercard|master|td)\s/.test(norm) || /\sthe\s/.test(norm)) {
    return findWalletByIdOrKeyword('tin dung') || findWalletByIdOrKeyword('credit') || findWalletByIdOrKeyword('tcb') ||
      ensureDynamicBankWallet('tcb', 'Thẻ tín dụng', '💳', 'him', '#EF4444,#fb7185');
  }
  if (/\s(tien mat|tm|cash)\s/.test(norm)) {
    return findWalletByIdOrKeyword('cash') || findWalletByIdOrKeyword('tien mat') ||
      ensureDynamicBankWallet('cash', 'Tiền mặt', '💵', 'him', '#22C55E,#4ade80');
  }
  if (/\s(vcb|vietcombank|vi chung)\s/.test(norm)) {
    return findWalletByIdOrKeyword('vcb') || findWalletByIdOrKeyword('vietcombank') ||
      ensureDynamicBankWallet('vcb', 'Ngân hàng VCB', '🏦', 'S', '#10B981,#34d399');
  }
  if (/\s(tcb|techcombank|tech)\s/.test(norm)) {
    return findWalletByIdOrKeyword('tech') || findWalletByIdOrKeyword('tcb') ||
      ensureDynamicBankWallet('tech', 'Techcombank', '🏦', 'him', '#DC2626,#f87171');
  }
  if (/\s(bidv)\s/.test(norm)) {
    return ensureDynamicBankWallet('bidv', 'Ngân hàng BIDV', '🏦', 'S', '#0284C7,#38bdf8');
  }
  if (/\s(vietin|vietinbank|ctg|incombank)\s/.test(norm)) {
    return ensureDynamicBankWallet('vietin', 'VietinBank', '🏦', 'S', '#2563EB,#60a5fa');
  }
  if (/\s(vpbank|vpb)\s/.test(norm)) {
    return ensureDynamicBankWallet('vpbank', 'VPBank', '🏦', 'him', '#16A34A,#4ade80');
  }
  if (/\s(tpbank|tpb)\s/.test(norm)) {
    return ensureDynamicBankWallet('tpbank', 'TPBank', '🏦', 'her', '#7C3AED,#a78bfa');
  }
  if (/\s(sacombank|stb)\s/.test(norm)) {
    return ensureDynamicBankWallet('stb', 'Sacombank', '🏦', 'him', '#0284C7,#38bdf8');
  }
  if (/\s(agribank|agri)\s/.test(norm)) {
    return ensureDynamicBankWallet('agri', 'Agribank', '🏦', 'S', '#DC2626,#f87171');
  }
  if (/\s(momo|vi momo|vi rieng|vi oanh)\s/.test(norm)) {
    return findWalletByIdOrKeyword('momo') || findWalletByIdOrKeyword('oanh') ||
      ensureDynamicBankWallet('momo', 'Ví riêng (Oanh)', '📱', 'her', '#EC4899,#f9a8d4');
  }

  // 2. Quét khớp động với tất cả các ví hiện có trong DB.wallets (kể cả ví người dùng tự đặt tên trên App)
  for (const w of DB.wallets) {
    const wId = removeAccents(w.id).replace(/[^a-z0-9]+/g, '').trim();
    const wName = removeAccents(w.name).replace(/[^a-z0-9]+/g, ' ').trim();
    const shortName = wName
      .replace(/\b(ngan hang|tai khoan|tk|vi|chung|rieng|cua|bao|oanh)\b/g, '')
      .replace(/\s+/g, ' ')
      .trim();

    if (wName && norm.includes(' ' + wName + ' ')) return w.id;
    if (shortName && shortName.length >= 2 && norm.includes(' ' + shortName + ' ')) return w.id;
    if (wId && wId.length >= 2 && norm.includes(' ' + wId + ' ')) return w.id;
  }

  return null;
}

function stripWalletKeywordsFromTitle(rawText) {
  let out = rawText;
  // Xóa tên các ví hiện có trong DB.wallets khỏi tiêu đề
  for (const w of DB.wallets) {
    if (w.name) {
      const esc = w.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      out = out.replace(new RegExp(esc, 'gi'), '');
    }
  }
  return out
    .replace(/(?:ngân hàng|ngan hang|tài khoản|tai khoan|bằng ví|bang vi|bằng thẻ|bang the|qua ví|qua thẻ|trừ ví)/gi, '')
    .replace(/(?:^|\s)(?:acb|mb|mbbank|vib|myvib|vcb|vietcombank|momo|tcb|techcombank|tech|bidv|vietin|vietinbank|vpbank|vpb|tpbank|tpb|sacombank|agribank|tien mat|tiền mặt|tm|cash|the tin dung|thẻ tín dụng|tin dung|tín dụng|credit|td)(?=\s|$|[.,!?;:])/gi, ' ')
    .replace(/(?:\d+(?:\.\d+)?\s*(?:tr|k|vnd|đ|₫)?|\b\d{4,10}\b)/gi, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function parseTextToTransaction(rawText, defaultWho = 'him') {
  const text = rawText.trim();
  const amt = parseAmount(text);
  if (!amt || amt <= 0) return null;

  const lower = text.toLowerCase();

  // 1. Kiểm tra xem có phải Chuyển ví không (Transfer giữa bất kỳ 2 tài khoản nào: ACB, MB, VIB, Tiền mặt, Thẻ tín dụng...)
  const isTransfer = lower.startsWith('chuyen ') || lower.startsWith('chuyển ') || /\s(sang|qua)\s/.test(lower);
  if (isTransfer) {
    let fromW = null;
    let toW = null;
    const splitMatch = lower.match(/^(.*?)\s+(?:sang|qua|tới|toi|vào|vao)\s+(.*)$/i);
    if (splitMatch) {
      fromW = parseWallet(splitMatch[1]);
      toW = parseWallet(splitMatch[2]);
    }
    if (!fromW) fromW = parseWallet(lower) || getDefaultWalletForRole(defaultWho);
    if (!toW || toW === fromW) {
      const other = DB.wallets.find(w => w.id !== fromW);
      toW = other ? other.id : 'cash';
    }

    return {
      kind: 't',
      amount: amt,
      title: `Chuyển tiền: ${getWalletName(fromW)} ➔ ${getWalletName(toW)}`,
      category: 'Chuyển tiền & Tiết kiệm',
      icon: '🔄',
      wallet: fromW,
      toWallet: toW,
      who: defaultWho,
      shared: true,
      note: text
    };
  }

  // 2. Kiểm tra xem có phải Thu nhập không (Income)
  const isIncome = lower.startsWith('thu ') || lower.startsWith('lương ') || lower.startsWith('luong ') || lower.includes('nhan tien') || lower.includes('nhận tiền');
  let matchedCat = null;
  let icon = isIncome ? '💰' : '🍜';
  let catName = isIncome ? 'Thu nhập khác' : 'Ăn uống';

  const mapList = isIncome ? INCOME_MAP : CATEGORY_MAP;
  for (const item of mapList) {
    for (const kw of item.keywords) {
      if (matchKeyword(lower, kw)) {
        matchedCat = item;
        break;
      }
    }
    if (matchedCat) break;
  }

  if (matchedCat) {
    icon = matchedCat.icon;
    catName = matchedCat.cat;
  }

  // Xác định ví tài khoản: ưu tiên từ khóa trong tin nhắn, nếu không có thì lấy ví mặc định của người gửi
  const explicitWallet = parseWallet(text);
  const walletId = explicitWallet || getDefaultWalletForRole(defaultWho);

  // Tách title sạch khỏi tên ngân hàng và số tiền
  let cleanTitle = stripWalletKeywordsFromTitle(text);
  if (!cleanTitle) cleanTitle = catName;

  return {
    kind: isIncome ? 'i' : 'e',
    amount: amt,
    title: cleanTitle.charAt(0).toUpperCase() + cleanTitle.slice(1),
    category: catName,
    icon: icon,
    wallet: walletId,
    who: defaultWho,
    shared: true,
    note: text
  };
}

// 5b. Phân tích tin nhắn văn bản tự do bằng Gemini AI khi Regex không khớp
async function parseExpenseWithAI(rawText, defaultWho = 'him') {
  if (!GEMINI_API_KEY) return null;
  try {
    const explicitWallet = parseWallet(rawText);
    const walletsPromptList = DB.wallets.map(w => `${w.id} (${w.name})`).join(' | ');
    const promptText = `Bạn là trợ lý tài chính thông minh cho gia đình Bảo & Oanh.
Hãy phân tích tin nhắn chi tiêu hoặc thu nhập sau: "${rawText}".
Danh sách tài khoản hiện có: ${walletsPromptList}.
Nếu tin nhắn có chứa số tiền giao dịch, hãy trích xuất thông tin.
Trả về CHỈ DUY NHẤT một chuỗi JSON hợp lệ (không kèm markdown):
{
  "isFinancial": true,
  "amount": <số tiền nguyên VND, ví dụ 50000, 1500000>,
  "title": "<mô tả nội dung ngắn gọn, không kèm tên ngân hàng, ví dụ Cà phê, Ăn trưa, Đổ xăng, Mua đồ>",
  "category": "<một trong các danh mục: Ăn uống | Chợ & Siêu thị | Nhà cửa | Hóa đơn | Đi lại | Con cái | Mua sắm | Giải trí | Sức khỏe | Khác>",
  "icon": "<icon emoji phù hợp với danh mục>",
  "wallet": "<mã id hoặc tên ngân hàng/tài khoản nếu có nhắc tới trong câu: ${DB.wallets.map(w => w.id).join(' | ')}, hoặc null>",
  "kind": "<e nếu là chi tiêu, i nếu là thu nhập, t nếu là chuyển tiền>"
}
Nếu tin nhắn không chứa số tiền hoặc không liên quan tài chính, trả về:
{"isFinancial": false}`;

    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${encodeURIComponent(GEMINI_API_KEY)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: promptText }] }],
        generationConfig: {
          temperature: 0.1,
          response_mime_type: 'application/json'
        }
      })
    });

    if (!res.ok) return null;
    const data = await res.json();
    let textOut = '';
    if (data.candidates && data.candidates[0] && data.candidates[0].content && Array.isArray(data.candidates[0].content.parts)) {
      for (const p of data.candidates[0].content.parts) {
        if (p.text) textOut += p.text;
      }
    }
    const match = textOut.match(/\{[\s\S]*\}/);
    if (!match) return null;
    const parsed = JSON.parse(match[0]);
    if (!parsed || !parsed.isFinancial || !parsed.amount || parsed.amount <= 0) return null;

    const catItem = CATEGORY_MAP.find(c => c.cat === parsed.category) || { cat: parsed.category || 'Ăn uống', icon: parsed.icon || '💸' };
    const resolvedWallet = explicitWallet ||
      parseWallet(parsed.wallet || '') ||
      findWalletByIdOrKeyword(parsed.wallet || '') ||
      getDefaultWalletForRole(defaultWho);

    return {
      kind: parsed.kind || 'e',
      amount: parseInt(parsed.amount, 10),
      title: parsed.title || rawText,
      category: catItem.cat,
      icon: catItem.icon,
      wallet: resolvedWallet,
      who: defaultWho,
      shared: true,
      note: rawText
    };
  } catch (err) {
    console.warn('Lỗi AI phân tích tin nhắn văn bản:', err.message);
    return null;
  }
}

// 6. Gửi tin nhắn Telegram qua Bot API
async function sendTelegram(method, body) {
  try {
    const res = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/${method}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    return await res.json();
  } catch (e) {
    console.error(`Lỗi Telegram ${method}:`, e.message);
    return null;
  }
}

async function sendMessage(chatId, text, extra = {}) {
  return sendTelegram('sendMessage', {
    chat_id: chatId,
    text: text,
    parse_mode: 'HTML',
    ...extra
  });
}

// Gửi file tài liệu (sao lưu backup JSON) trực tiếp qua Telegram
async function sendTelegramDocument(chatId, fileName, fileBuffer, caption = '') {
  try {
    const form = new FormData();
    form.append('chat_id', chatId);
    if (caption) form.append('caption', caption);
    form.append('parse_mode', 'HTML');
    form.append('document', new Blob([fileBuffer], { type: 'application/json' }), fileName);

    const res = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendDocument`, {
      method: 'POST',
      body: form
    });
    return await res.json();
  } catch (e) {
    console.error('Lỗi sendTelegramDocument:', e.message);
    return null;
  }
}

// Bộ nhớ tạm lưu trữ các hóa đơn / lô giao dịch đang chờ người dùng kiểm tra & xác nhận
const PENDING_BILLS = new Map();
const SAVED_BATCHES = new Map();

// Phân tích chuỗi ngày tháng DD/MM/YYYY hoặc DD/MM thành { day, month, year, label }
function parseDateToDMY(dateStr) {
  const now = new Date();
  let day = now.getDate();
  let month = now.getMonth() + 1;
  let year = now.getFullYear();
  let dateKnown = false;

  if (typeof dateStr === 'number' && dateStr >= 1 && dateStr <= 31) {
    day = dateStr;
    dateKnown = true;
  } else if (typeof dateStr === 'string' && dateStr.trim()) {
    const clean = dateStr.trim();
    const mDMY = clean.match(/(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{2,4}))?/);
    const mYMD = clean.match(/(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})/);
    if (mYMD) {
      year = parseInt(mYMD[1], 10);
      month = parseInt(mYMD[2], 10);
      day = parseInt(mYMD[3], 10);
      dateKnown = true;
    } else if (mDMY) {
      day = parseInt(mDMY[1], 10);
      month = parseInt(mDMY[2], 10);
      if (mDMY[3]) {
        const yRaw = parseInt(mDMY[3], 10);
        year = yRaw < 100 ? (2000 + yRaw) : yRaw;
      }
      dateKnown = true;
    }
  }
  if (day < 1 || day > 31) day = now.getDate();
  if (month < 1 || month > 12) month = now.getMonth() + 1;
  return {
    day,
    month,
    year,
    dateKnown,
    label: `${String(day).padStart(2, '0')}/${String(month).padStart(2, '0')}`
  };
}

// Xác định danh mục và icon cho 1 dòng giao dịch
function resolveCategoryForTx(catStr, titleStr, kind = 'e') {
  const mapList = kind === 'i' ? INCOME_MAP : CATEGORY_MAP;
  const normCat = removeAccents(catStr || '');
  const normTitle = removeAccents(titleStr || '');

  if (normCat) {
    const direct = mapList.find(c => removeAccents(c.cat) === normCat || normCat.includes(removeAccents(c.cat)));
    if (direct) return { cat: direct.cat, icon: direct.icon };
  }
  for (const item of mapList) {
    for (const kw of item.keywords) {
      if (matchKeyword(normTitle, removeAccents(kw))) {
        return { cat: item.cat, icon: item.icon };
      }
    }
  }
  return kind === 'i'
    ? { cat: 'Thu nhập khác', icon: '💰' }
    : { cat: catStr || 'Ăn uống', icon: '🧾' };
}

// Kiểm tra xem giao dịch cand có bị trùng lặp với giao dịch đã có trong existingList hay không
function findDuplicateTransaction(cand, existingList) {
  if (!cand || !cand.amount || !Array.isArray(existingList)) return null;
  const now = new Date();
  const curM = now.getMonth() + 1;
  const curY = now.getFullYear();

  const cAmt = Number(cand.amount);
  const cKind = cand.kind || 'e';
  const cDay = cand.day || now.getDate();
  const cMonth = cand.month || curM;
  const cYear = cand.year || curY;
  const cRef = removeAccents(cand.refCode || '').replace(/[^a-z0-9]/g, '');
  const cTitle = removeAccents(cand.title || '')
    .replace(/\b(chuyen khoan|thanh toan|hoa don|ai|gd|giao dich|ngan hang|mua|chi|thu)\b/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

  for (const ex of existingList) {
    if (!ex || Number(ex.amount) !== cAmt) continue;
    if ((ex.kind || 'e') !== cKind) continue;

    // 1. Nếu có mã giao dịch (refCode) trùng khớp tuyệt đối (>= 4 ký tự)
    const exNoteNorm = removeAccents((ex.note || '') + ' ' + (ex.title || '')).replace(/[^a-z0-9]/g, '');
    if (cRef && cRef.length >= 4 && exNoteNorm.includes(cRef)) {
      return ex;
    }

    // 2. Kiểm tra cùng Ngày / Tháng / Năm
    const exDay = ex.day;
    const exMonth = ex.month || (ex.id > 1000000000000 ? (new Date(ex.id).getMonth() + 1) : curM);
    const exYear = ex.year || (ex.id > 1000000000000 ? new Date(ex.id).getFullYear() : curY);
    if (cDay !== exDay || cMonth !== exMonth || cYear !== exYear) continue;

    // Cùng ngày + cùng số tiền + cùng loại thu/chi:
    const exTitle = removeAccents((ex.title || '') + ' ' + (ex.note || ''))
      .replace(/\b(chuyen khoan|thanh toan|hoa don|ai|gd|giao dich|ngan hang|mua|chi|thu)\b/g, ' ')
      .replace(/[^a-z0-9]+/g, ' ')
      .trim();

    // 2a. Tiêu đề trùng hoặc chứa nhau
    if (!cTitle || !exTitle || cTitle === exTitle || exTitle.includes(cTitle) || cTitle.includes(exTitle)) {
      return ex;
    }

    // 2b. Có từ khóa chung (>= 3 ký tự)
    const cWords = cTitle.split(/\s+/).filter(w => w.length >= 3);
    const hasSharedWord = cWords.some(w => exTitle.includes(w));
    if (hasSharedWord) {
      return ex;
    }

    // 2c. Cùng ví + cùng danh mục trong cùng 1 ngày với đúng số tiền đó
    if (cand.wallet && ex.wallet === cand.wallet && cand.category && ex.category === cand.category) {
      return ex;
    }
  }
  return null;
}

function formatVND(amt) {
  return Number(amt || 0).toLocaleString('vi-VN');
}

function getWalletName(id) {
  const w = DB.wallets.find(x => x.id === id);
  return w ? `${w.icon} ${w.name}` : 'Ví';
}

function formatRole(role) {
  const u = DB.users[role] || DB.users.him;
  return role === 'her' ? `👩 ${u.name} (Vợ)` : `👨 ${u.name} (Chồng)`;
}

// Tạo các hàng nút bấm 1 chạm chọn nhanh Tài khoản chi / nhận
function buildQuickWalletRows(prefix, currentWalletId) {
  const rows = [];
  const wallets = DB.wallets || [];
  for (let i = 0; i < wallets.length; i += 2) {
    const w1 = wallets[i];
    const row = [
      { text: `${w1.id === currentWalletId ? '✅ ' : ''}${w1.icon} ${w1.name}`, callback_data: `${prefix}${w1.id}` }
    ];
    if (wallets[i + 1]) {
      const w2 = wallets[i + 1];
      row.push({ text: `${w2.id === currentWalletId ? '✅ ' : ''}${w2.icon} ${w2.name}`, callback_data: `${prefix}${w2.id}` });
    }
    rows.push(row);
  }
  return rows;
}

// Tạo nội dung thẻ & bàn phím nút bấm cho một giao dịch đã lưu (cho phép đổi tài khoản 1 chạm ngay tại thẻ)
function buildSavedTxCard(tx) {
  const isInc = tx.kind === 'i';
  const isTrans = tx.kind === 't';
  const headerIcon = isInc ? '💰' : isTrans ? '🔄' : '💸';
  const amtStr = isInc ? `+${formatVND(tx.amount)} ₫` : isTrans ? `🔄 ${formatVND(tx.amount)} ₫` : `-${formatVND(tx.amount)} ₫`;

  let details = '';
  if (isTrans) {
    details = `• <b>Từ ví:</b> ${getWalletName(tx.wallet)}\n• <b>Đến ví:</b> ${getWalletName(tx.toWallet)}`;
  } else {
    details = `• <b>Tài khoản:</b> ${getWalletName(tx.wallet)}\n• <b>Danh mục:</b> ${tx.icon} ${tx.category}`;
  }

  const text = `${headerIcon} <b>Đã ghi chép thành công!</b>\n\n` +
    `<b>${tx.title}</b>: <code>${amtStr}</code>\n` +
    `${details}\n` +
    `• <b>Người ghi:</b> ${formatRole(tx.who)} (${tx.shared ? '👥 Chung' : '🔒 Riêng'})` +
    `${tx.receipt ? '\n• <b>Đính kèm:</b> 📎 Đã đồng bộ ảnh hóa đơn' : ''}\n\n` +
    `💡 <i>Chạm trực tiếp tên ngân hàng bên dưới nếu muốn đổi tài khoản chi:</i>`;

  const inline_keyboard = [];
  if (!isTrans) {
    inline_keyboard.push(...buildQuickWalletRows(`set_tx_wal_${tx.id}_`, tx.wallet));
  }
  inline_keyboard.push([
    { text: tx.shared ? '🔒 Đổi sang Riêng' : '👥 Đổi sang Chung', callback_data: `toggle_shared_${tx.id}` },
    { text: '🗑 Hủy / Xóa', callback_data: `del_tx_${tx.id}` }
  ]);
  inline_keyboard.push([
    { text: '📊 Xem số dư tất cả ví', callback_data: 'view_wallets' }
  ]);

  return { text, reply_markup: { inline_keyboard } };
}

// Hàm hiển thị Thẻ Xem lại & Tự động điền Hóa đơn hoặc Lô nhiều giao dịch AI (kèm báo cáo chống trùng lặp)
async function renderBillPreviewCard(chatId, messageId, bill) {
  const txList = Array.isArray(bill.txList) ? bill.txList : [];
  const activeTxs = txList.filter(t => t.selected !== false);
  const duplicates = Array.isArray(bill.duplicates) ? bill.duplicates : [];
  const isMulti = txList.length > 1 || duplicates.length > 0;

  let cardText = '';
  const toggleRows = [];

  if (!isMulti && txList.length === 1) {
    // Giao diện 1 hóa đơn đơn lẻ
    const single = txList[0];
    let itemsListStr = '';
    if (Array.isArray(single.items) && single.items.length > 0) {
      itemsListStr = '\n<b>📋 Các món bóc tách được:</b>\n' + single.items.slice(0, 5).map(it => ` • ${it.name}${it.price ? `: <code>${formatVND(it.price)} ₫</code>` : ''}`).join('\n');
      if (single.items.length > 5) itemsListStr += `\n • <i>và ${single.items.length - 5} món khác...</i>`;
    }
    const sign = single.kind === 'i' ? '+' : '-';
    cardText = `🧾 <b>KẾT QUẢ TỰ ĐỘNG ĐỌC HÓA ĐƠN (AI)</b>\n\n` +
      `🏪 <b>Nội dung:</b> ${single.title || 'Hóa đơn'}\n` +
      `📅 <b>Ngày:</b> ${single.dateLabel || 'Hôm nay'}\n` +
      `💰 <b>Số tiền:</b> <code>${sign}${formatVND(single.amount)} ₫</code>\n` +
      `📁 <b>Danh mục:</b> ${single.icon} ${single.category}\n` +
      `💳 <b>Tài khoản:</b> <b>${getWalletName(bill.wallet)}</b>\n` +
      `👤 <b>Người ghi:</b> ${formatRole(bill.who)}\n` +
      itemsListStr +
      `\n\n💡 <i>Chạm chọn Tài khoản bên dưới rồi bấm <b>Xác nhận lưu</b>:</i>`;
  } else {
    // Giao diện Lô nhiều giao dịch (Lịch sử ngân hàng / Sao kê / Nhiều bill)
    let totalExp = 0;
    let totalInc = 0;
    activeTxs.forEach(t => {
      if (t.kind === 'i') totalInc += t.amount;
      else totalExp += t.amount;
    });

    const listLines = txList.map((t, idx) => {
      const isSel = t.selected !== false;
      const sign = t.kind === 'i' ? '+' : '-';
      const checkIcon = isSel ? '✅' : '⬜';
      return `${idx + 1}. ${checkIcon} <b>${t.title}</b>: <code>${sign}${formatVND(t.amount)} ₫</code> <i>(${t.icon} ${t.category} · ${t.dateLabel})</i>`;
    }).join('\n');

    let dupSection = '';
    if (duplicates.length > 0) {
      const dupLines = duplicates.slice(0, 6).map(d => {
        const sign = d.kind === 'i' ? '+' : '-';
        return ` • ⛔ <s>${d.title}: ${sign}${formatVND(d.amount)} ₫</s> <i>(Đã có ngày ${d.dateLabel})</i>`;
      }).join('\n');
      const moreDup = duplicates.length > 6 ? `\n • <i>...và ${duplicates.length - 6} giao dịch trùng khác</i>` : '';
      dupSection = `\n\n🛡 <b>Đã tự động loại bỏ ${duplicates.length} giao dịch trùng lặp:</b>\n${dupLines}${moreDup}`;
    }

    cardText = `📑 <b>QUÉT NHIỀU GIAO DỊCH TỪ ẢNH (AI)</b>\n\n` +
      `💳 <b>Tài khoản:</b> <b>${getWalletName(bill.wallet)}</b>\n` +
      `👤 <b>Người ghi:</b> ${formatRole(bill.who)}\n` +
      `📊 <b>Phát hiện:</b> <b>${activeTxs.length}/${txList.length} giao dịch mới</b>` +
      `${totalExp > 0 ? ` · Tổng chi: <code>-${formatVND(totalExp)} ₫</code>` : ''}` +
      `${totalInc > 0 ? ` · Tổng thu: <code>+${formatVND(totalInc)} ₫</code>` : ''}\n\n` +
      `<b>📋 Danh sách giao dịch mới sẽ lưu:</b>\n${listLines}` +
      dupSection +
      `\n\n💡 <i>Chạm số thứ tự bên dưới nếu muốn bỏ chọn từng khoản, chọn Tài khoản rồi bấm <b>Xác nhận lưu</b>:</i>`;

    // Nút bật/tắt chọn từng giao dịch trong lô (tối đa 12 nút chia theo hàng 4 nút)
    if (txList.length > 1) {
      const itemBtns = txList.slice(0, 12).map((t, idx) => ({
        text: `${t.selected !== false ? '✅' : '⬜'} #${idx + 1} (${Math.round(t.amount / 1000)}k)`,
        callback_data: `tog_bitem_${bill.id}_${idx}`
      }));
      for (let i = 0; i < itemBtns.length; i += 3) {
        toggleRows.push(itemBtns.slice(i, i + 3));
      }
    }
  }

  const walletRows = buildQuickWalletRows(`set_wal_${bill.id}_`, bill.wallet);
  const actionRows = [];
  if (activeTxs.length > 0) {
    actionRows.push([
      {
        text: activeTxs.length > 1
          ? `✅ XÁC NHẬN LƯU ${activeTxs.length} GIAO DỊCH VÀO VÍ ĐÔI`
          : `✅ XÁC NHẬN LƯU VÀO VÍ ĐÔI`,
        callback_data: `confirm_bill_${bill.id}`
      }
    ]);
  }
  const bottomRow = [];
  if (!isMulti && txList.length === 1) {
    bottomRow.push({ text: '📁 Đổi danh mục', callback_data: `change_cat_${bill.id}` });
  }
  bottomRow.push({ text: '🗑 Hủy bỏ', callback_data: `cancel_bill_${bill.id}` });
  actionRows.push(bottomRow);

  const keyboard = {
    inline_keyboard: [
      ...toggleRows,
      ...walletRows,
      ...actionRows
    ]
  };

  if (messageId) {
    return sendTelegram('editMessageText', {
      chat_id: chatId,
      message_id: messageId,
      text: cardText,
      parse_mode: 'HTML',
      reply_markup: keyboard
    });
  } else {
    return sendMessage(chatId, cardText, { reply_markup: keyboard });
  }
}

// 7. Xử lý Lệnh & Tin nhắn người dùng
async function handleUpdate(update) {
  // Đồng bộ danh sách ví mới nhất từ App điện thoại (PWA) trước khi xử lý
  await pullFromPWA(false);

  // A. Xử lý Callback Button (Inline keyboard)
  if (update.callback_query) {
    const cq = update.callback_query;
    const data = cq.data || '';
    const chatId = cq.message.chat.id;
    const msgId = cq.message.message_id;

    // Bật/tắt chọn từng giao dịch trong lô nhiều giao dịch
    if (data.startsWith('tog_bitem_')) {
      const raw = data.replace('tog_bitem_', '');
      let bill = null;
      let idx = -1;
      for (const [k, b] of PENDING_BILLS.entries()) {
        if (raw.startsWith(k + '_')) {
          bill = b;
          idx = parseInt(raw.slice(k.length + 1), 10);
          break;
        }
      }
      if (bill && Array.isArray(bill.txList) && bill.txList[idx]) {
        bill.txList[idx].selected = bill.txList[idx].selected === false ? true : false;
        await sendTelegram('answerCallbackQuery', {
          callback_query_id: cq.id,
          text: bill.txList[idx].selected ? `Đã chọn #${idx + 1}` : `Đã bỏ chọn #${idx + 1}`
        });
        await renderBillPreviewCard(chatId, msgId, bill);
      }
      return;
    }

    // Xóa / Hoàn tác cả lô giao dịch vừa lưu
    if (data.startsWith('del_batch_')) {
      const batchId = data.replace('del_batch_', '');
      const txIds = SAVED_BATCHES.get(batchId);
      if (!Array.isArray(txIds) || txIds.length === 0) {
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: 'Lô giao dịch này đã được xóa hoặc không tồn tại.' });
        return;
      }
      SAVED_BATCHES.delete(batchId);
      let removedCount = 0;
      for (const txId of txIds) {
        const idx = DB.transactions.findIndex(t => t.id === txId);
        if (idx >= 0) {
          const removed = DB.transactions.splice(idx, 1)[0];
          if (!DB.deletedTxIds) DB.deletedTxIds = [];
          DB.deletedTxIds.push(txId);
          const w = DB.wallets.find(x => x.id === removed.wallet);
          if (w) w.balance += (removed.kind === 'e' ? removed.amount : -removed.amount);
          removedCount++;
        }
      }
      saveDB();
      await broadcastToPWA();
      await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: `Đã hoàn tác ${removedCount} giao dịch!` });
      await sendTelegram('editMessageText', {
        chat_id: chatId,
        message_id: msgId,
        text: `🗑 <b>Đã hoàn tác & xóa toàn bộ ${removedCount} giao dịch trong lô vừa quét.</b>\nSố dư ví đã được khôi phục và đồng bộ sang Ví Đôi PWA.`,
        parse_mode: 'HTML'
      });
      return;
    }

    // Xác nhận lưu Hóa đơn hoặc Lô nhiều giao dịch AI (có kiểm tra chống trùng lặp lần cuối)
    if (data.startsWith('confirm_bill_')) {
      const billId = data.replace('confirm_bill_', '');
      const bill = PENDING_BILLS.get(billId);
      if (!bill) {
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: 'Hóa đơn đã xử lý hoặc hết hạn.' });
        return;
      }
      PENDING_BILLS.delete(billId);

      if (!DB.defaultWallet) DB.defaultWallet = {};
      DB.defaultWallet[bill.who] = bill.wallet;

      const rawList = Array.isArray(bill.txList) && bill.txList.length > 0
        ? bill.txList.filter(t => t.selected !== false)
        : [{
            amount: bill.amount,
            kind: 'e',
            title: bill.merchant || bill.category,
            category: bill.category,
            icon: bill.icon || '🧾',
            day: new Date().getDate(),
            month: new Date().getMonth() + 1,
            year: new Date().getFullYear(),
            dateLabel: bill.date || 'Hôm nay'
          }];

      const savedTxs = [];
      const skippedLateDups = [];
      const baseTs = Date.now();
      const sharedRcptId = (bill.receiptThumb || bill.receiptFull) ? ('rcpt_' + baseTs) : null;

      for (let i = 0; i < rawList.length; i++) {
        const item = rawList[i];
        const dup = findDuplicateTransaction({ ...item, wallet: bill.wallet }, DB.transactions);
        if (dup) {
          skippedLateDups.push(item);
          continue;
        }
        const curTxId = baseTs + i;
        const newTx = {
          id: curTxId,
          day: item.day,
          month: item.month,
          year: item.year,
          icon: item.icon || '🧾',
          title: item.title || item.category,
          category: item.category,
          amount: item.amount,
          who: bill.who,
          shared: true,
          wallet: bill.wallet,
          kind: item.kind || 'e',
          note: item.refCode ? `AI [${item.refCode}]: ${item.title}` : `Hóa đơn AI: ${item.title}`,
          receipt: sharedRcptId,
          receiptThumb: i === 0 ? (bill.receiptThumb || bill.receiptFull || null) : null,
          comments: [],
          updatedAt: curTxId
        };

        const w = DB.wallets.find(x => x.id === bill.wallet);
        if (w) {
          w.balance += (newTx.kind === 'i' ? newTx.amount : -newTx.amount);
        }
        DB.transactions.unshift(newTx);
        savedTxs.push(newTx);
      }

      if (savedTxs.length === 0) {
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: 'Các giao dịch này đều đã trùng lặp trong sổ!' });
        await sendTelegram('editMessageText', {
          chat_id: chatId,
          message_id: msgId,
          text: `🛡 <b>Tất cả giao dịch đã chọn đều đã có trong sổ Ví Đôi (trùng lặp).</b>\nHệ thống không lưu lại để đảm bảo số dư chính xác!`,
          parse_mode: 'HTML'
        });
        return;
      }

      saveDB();
      if (sharedRcptId && (bill.receiptFull || bill.receiptThumb)) {
        pushReceiptToCloudFromBot(sharedRcptId, bill.receiptFull || bill.receiptThumb);
      }
      await broadcastToPWA();

      // Nếu chỉ lưu 1 giao dịch đơn lẻ
      if (savedTxs.length === 1 && (!bill.duplicates || bill.duplicates.length === 0) && skippedLateDups.length === 0) {
        const card = buildSavedTxCard(savedTxs[0]);
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: `Đã lưu vào ${getWalletName(bill.wallet)}!` });
        await sendTelegram('editMessageText', {
          chat_id: chatId,
          message_id: msgId,
          text: card.text,
          parse_mode: 'HTML',
          reply_markup: card.reply_markup
        });
        return;
      }

      // Nếu lưu lô nhiều giao dịch (hoặc có lọc trùng lặp)
      SAVED_BATCHES.set(bill.id, savedTxs.map(t => t.id));
      let totalExp = 0, totalInc = 0;
      savedTxs.forEach(t => { if (t.kind === 'i') totalInc += t.amount; else totalExp += t.amount; });
      const totalSkipped = (bill.duplicates ? bill.duplicates.length : 0) + skippedLateDups.length;

      const summaryLines = savedTxs.map((t, idx) => {
        const sign = t.kind === 'i' ? '+' : '-';
        return `${idx + 1}. ${t.icon} <b>${t.title}</b>: <code>${sign}${formatVND(t.amount)} ₫</code> <i>(${t.day}/${t.month})</i>`;
      }).join('\n');

      const wNow = DB.wallets.find(x => x.id === bill.wallet);
      const batchDoneText = `✅ <b>ĐÃ LƯU ${savedTxs.length} GIAO DỊCH MỚI VÀO VÍ ĐÔI!</b>\n\n` +
        `💳 <b>Tài khoản:</b> ${getWalletName(bill.wallet)}${wNow ? ` (Số dư: <code>${formatVND(wNow.balance)} ₫</code>)` : ''}\n` +
        `👤 <b>Người ghi:</b> ${formatRole(bill.who)}\n` +
        `${totalExp > 0 ? `💸 <b>Tổng chi:</b> <code>-${formatVND(totalExp)} ₫</code>\n` : ''}` +
        `${totalInc > 0 ? `💰 <b>Tổng thu:</b> <code>+${formatVND(totalInc)} ₫</code>\n` : ''}` +
        `${totalSkipped > 0 ? `🛡 <b>Đã bỏ qua trùng lặp:</b> ${totalSkipped} giao dịch\n` : ''}\n` +
        `<b>📋 Các giao dịch đã thêm:</b>\n${summaryLines}\n\n` +
        `⚡ <i>Đã đồng bộ tức thì sang Ví Đôi PWA của cả hai vợ chồng!</i>`;

      await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: `Đã lưu ${savedTxs.length} giao dịch thành công!` });
      await sendTelegram('editMessageText', {
        chat_id: chatId,
        message_id: msgId,
        text: batchDoneText,
        parse_mode: 'HTML',
        reply_markup: {
          inline_keyboard: [
            [
              { text: `🗑 Hoàn tác lô ${savedTxs.length} giao dịch này`, callback_data: `del_batch_${bill.id}` }
            ],
            [
              { text: '📊 Xem số dư tất cả ví', callback_data: 'view_wallets' }
            ]
          ]
        }
      });
      return;
    }

    // Hủy bỏ hóa đơn AI
    if (data.startsWith('cancel_bill_')) {
      const billId = data.replace('cancel_bill_', '');
      PENDING_BILLS.delete(billId);
      await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: 'Đã hủy bỏ hóa đơn.' });
      await sendTelegram('editMessageText', {
        chat_id: chatId,
        message_id: msgId,
        text: `🗑 <i>Đã hủy bỏ thông tin hóa đơn này. Không lưu vào sổ chi tiêu.</i>`,
        parse_mode: 'HTML'
      });
      return;
    }

    // Đổi danh mục cho hóa đơn
    if (data.startsWith('change_cat_')) {
      const billId = data.replace('change_cat_', '');
      const bill = PENDING_BILLS.get(billId);
      if (!bill) {
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: 'Hóa đơn đã hết hạn.' });
        return;
      }
      const catButtons = [];
      for (let i = 0; i < CATEGORY_MAP.length; i += 2) {
        const row = [
          { text: `${CATEGORY_MAP[i].icon} ${CATEGORY_MAP[i].cat}`, callback_data: `set_cat_${billId}_${i}` }
        ];
        if (CATEGORY_MAP[i + 1]) {
          row.push({ text: `${CATEGORY_MAP[i + 1].icon} ${CATEGORY_MAP[i + 1].cat}`, callback_data: `set_cat_${billId}_${i + 1}` });
        }
        catButtons.push(row);
      }
      catButtons.push([{ text: '‹ Quay lại hóa đơn', callback_data: `back_bill_${billId}` }]);

      await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id });
      await sendTelegram('editMessageText', {
        chat_id: chatId,
        message_id: msgId,
        text: `📁 <b>Chọn danh mục chi tiêu mới cho hóa đơn "${bill.merchant}":</b>`,
        parse_mode: 'HTML',
        reply_markup: { inline_keyboard: catButtons }
      });
      return;
    }

    if (data.startsWith('set_cat_')) {
      const raw = data.replace('set_cat_', '');
      let bill = null;
      let catIdx = -1;
      for (const [k, b] of PENDING_BILLS.entries()) {
        if (raw.startsWith(k + '_')) {
          bill = b;
          catIdx = parseInt(raw.slice(k.length + 1), 10);
          break;
        }
      }
      if (bill && CATEGORY_MAP[catIdx]) {
        bill.category = CATEGORY_MAP[catIdx].cat;
        bill.icon = CATEGORY_MAP[catIdx].icon;
        if (Array.isArray(bill.txList) && bill.txList[0]) {
          bill.txList[0].category = CATEGORY_MAP[catIdx].cat;
          bill.txList[0].icon = CATEGORY_MAP[catIdx].icon;
        }
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: `Đã đổi danh mục sang: ${bill.category}` });
        await renderBillPreviewCard(chatId, msgId, bill);
      }
      return;
    }

    // Đổi tài khoản cho hóa đơn (Hỗ trợ mọi định dạng billId và walletId có dấu gạch dưới)
    if (data.startsWith('change_wal_')) {
      const billId = data.replace('change_wal_', '');
      const bill = PENDING_BILLS.get(billId);
      if (!bill) {
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: 'Hóa đơn đã hết hạn.' });
        return;
      }
      const walButtons = DB.wallets.map(w => [
        { text: `${w.id === bill.wallet ? '✅ ' : ''}${w.icon} ${w.name} (${formatVND(w.balance)} ₫)`, callback_data: `set_wal_${billId}_${w.id}` }
      ]);
      walButtons.push([{ text: '‹ Quay lại hóa đơn', callback_data: `back_bill_${billId}` }]);

      await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id });
      await sendTelegram('editMessageText', {
        chat_id: chatId,
        message_id: msgId,
        text: `💳 <b>Chọn tài khoản thanh toán cho hóa đơn "${bill.merchant}":</b>`,
        parse_mode: 'HTML',
        reply_markup: { inline_keyboard: walButtons }
      });
      return;
    }

    if (data.startsWith('set_wal_')) {
      const raw = data.replace('set_wal_', '');
      let bill = null;
      let walId = '';
      for (const [k, b] of PENDING_BILLS.entries()) {
        if (raw.startsWith(k + '_')) {
          bill = b;
          walId = raw.slice(k.length + 1);
          break;
        }
      }
      if (bill && walId) {
        bill.wallet = walId;
        if (!DB.defaultWallet) DB.defaultWallet = {};
        DB.defaultWallet[bill.who] = walId;
        saveDB();
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: `Đã chọn tài khoản: ${getWalletName(walId)}` });
        await renderBillPreviewCard(chatId, msgId, bill);
      } else {
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: 'Hóa đơn đã hết hạn hoặc đã lưu.' });
      }
      return;
    }

    if (data.startsWith('back_bill_')) {
      const billId = data.replace('back_bill_', '');
      const bill = PENDING_BILLS.get(billId);
      if (bill) {
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id });
        await renderBillPreviewCard(chatId, msgId, bill);
      }
      return;
    }

    if (data.startsWith('set_role_')) {
      const role = data.replace('set_role_', '');
      DB.telegramUsers[String(cq.from.id)] = role;
      saveDB();
      await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: `Đã chọn: ${formatRole(role)}!` });
      await sendMessage(chatId, `✅ Tuyệt vời! Từ giờ các khoản ghi chép của bạn sẽ tự động ghi nhận cho <b>${formatRole(role)}</b>.\n\nHãy thử gõ: <code>cf 45k</code> hoặc <code>đi chợ 250k vcb</code> ✨`);
      return;
    }

    if (data.startsWith('del_tx_')) {
      const txId = parseInt(data.replace('del_tx_', ''), 10);
      const idx = DB.transactions.findIndex(t => t.id === txId);
      if (idx >= 0) {
        const removed = DB.transactions.splice(idx, 1)[0];
        if (!DB.deletedTxIds) DB.deletedTxIds = [];
        DB.deletedTxIds.push(txId);

        // Hoàn lại số dư ví
        if (removed.kind === 't') {
          const fw = DB.wallets.find(w => w.id === removed.wallet);
          const tw = DB.wallets.find(w => w.id === removed.toWallet);
          if (fw) fw.balance += removed.amount;
          if (tw) tw.balance -= removed.amount;
        } else {
          const w = DB.wallets.find(w => w.id === removed.wallet);
          if (w) w.balance += (removed.kind === 'e' ? removed.amount : -removed.amount);
        }

        saveDB();
        await broadcastToPWA();
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: 'Đã xóa giao dịch!' });
        await sendTelegram('editMessageText', {
          chat_id: chatId,
          message_id: msgId,
          text: `🗑 <b>Đã xóa giao dịch:</b> <i>${removed.title} (${formatVND(removed.amount)} ₫)</i>\nĐã đồng bộ cập nhật hoàn lại số dư sang Ví Đôi PWA.`,
          parse_mode: 'HTML'
        });
      } else {
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: 'Giao dịch không tồn tại hoặc đã xóa.' });
      }
      return;
    }

    if (data.startsWith('toggle_shared_')) {
      const txId = parseInt(data.replace('toggle_shared_', ''), 10);
      const tx = DB.transactions.find(t => t.id === txId);
      if (tx) {
        tx.shared = !tx.shared;
        tx.updatedAt = Date.now();
        saveDB();
        await broadcastToPWA();
        const card = buildSavedTxCard(tx);
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: tx.shared ? 'Đã đổi thành Khoản Chung!' : 'Đã đổi thành Khoản Riêng!' });
        await sendTelegram('editMessageText', {
          chat_id: chatId,
          message_id: msgId,
          text: card.text,
          parse_mode: 'HTML',
          reply_markup: card.reply_markup
        });
      }
      return;
    }

    // Đổi tài khoản / ngân hàng trực tiếp cho giao dịch đã lưu trên Telegram
    if (data.startsWith('change_tx_wal_')) {
      const txId = parseInt(data.replace('change_tx_wal_', ''), 10);
      const tx = DB.transactions.find(t => t.id === txId);
      if (!tx) {
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: 'Giao dịch không tồn tại hoặc đã xóa.' });
        return;
      }
      const card = buildSavedTxCard(tx);
      await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id });
      await sendTelegram('editMessageText', {
        chat_id: chatId,
        message_id: msgId,
        text: card.text,
        parse_mode: 'HTML',
        reply_markup: card.reply_markup
      });
      return;
    }

    if (data.startsWith('set_tx_wal_')) {
      const raw = data.replace('set_tx_wal_', '');
      const firstUnderscore = raw.indexOf('_');
      const txId = parseInt(raw.slice(0, firstUnderscore), 10);
      const newWalId = raw.slice(firstUnderscore + 1);
      const tx = DB.transactions.find(t => t.id === txId);
      const newW = DB.wallets.find(w => w.id === newWalId);
      if (!tx || !newW) {
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: 'Không tìm thấy giao dịch hoặc tài khoản.' });
        return;
      }
      if (tx.wallet !== newWalId) {
        const oldW = DB.wallets.find(w => w.id === tx.wallet);
        if (oldW) {
          oldW.balance += (tx.kind === 'i' ? -tx.amount : tx.amount);
        }
        newW.balance += (tx.kind === 'i' ? tx.amount : -tx.amount);
        tx.wallet = newWalId;
        tx.updatedAt = Date.now();
        if (!DB.defaultWallet) DB.defaultWallet = {};
        DB.defaultWallet[tx.who] = newWalId;
        saveDB();
        await broadcastToPWA();
      }
      const card = buildSavedTxCard(tx);
      await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: `Đã đổi sang: ${newW.icon} ${newW.name}!` });
      await sendTelegram('editMessageText', {
        chat_id: chatId,
        message_id: msgId,
        text: card.text,
        parse_mode: 'HTML',
        reply_markup: card.reply_markup
      });
      return;
    }

    if (data === 'view_wallets') {
      await sendWalletsOverview(chatId);
      return;
    }
  }

  // B. Xử lý Ảnh Hóa đơn gửi trực tiếp qua Telegram (Quét bằng Gemini AI Vision)
  if (update.message && Array.isArray(update.message.photo) && update.message.photo.length > 0) {
    const msg = update.message;
    const chatId = msg.chat.id;
    const tgUserId = String(msg.from.id);
    const myRole = DB.telegramUsers[tgUserId] || 'him';

    if (!GEMINI_API_KEY) {
      return sendMessage(chatId, `📷 <b>Đã nhận ảnh hóa đơn!</b>\n\nĐể bot tự động đọc số tiền bằng AI, bạn chỉ cần thêm <code>GEMINI_API_KEY="AIzaSy..."</code> vào file <code>.env</code> trên máy chủ Cloud nhé! ✨\n\n<i>(Lấy key miễn phí tại <a href="https://aistudio.google.com/">aistudio.google.com</a>)</i>`);
    }

    const photos = msg.photo;
    const bestPhoto = photos[photos.length - 1]; // Ảnh chất lượng cao nhất để AI đọc & lưu HD
    const thumbPhoto = photos[Math.min(1, photos.length - 1)]; // Ảnh nén nhẹ (~12-18KB) để đồng bộ tức thì sang 2 máy
    await sendMessage(chatId, `🔍 <i>Đang dùng Gemini AI quét hóa đơn, vui lòng đợi giây lát...</i>`);

    try {
      // 1. Lấy link file từ Telegram Bot API
      const getFileRes = await sendTelegram('getFile', { file_id: bestPhoto.file_id });
      if (!getFileRes || !getFileRes.ok) throw new Error('Không lấy được thông tin ảnh từ Telegram');
      const filePath = getFileRes.result.file_path;

      // 2. Tải buffer ảnh chất lượng cao
      const fileUrl = `https://api.telegram.org/file/bot${BOT_TOKEN}/${filePath}`;
      const imgRes = await fetch(fileUrl);
      if (!imgRes.ok) throw new Error('Không thể tải file ảnh từ Telegram server');
      const buffer = await imgRes.arrayBuffer();
      const base64Data = Buffer.from(buffer).toString('base64');
      const fullDataUrl = `data:image/jpeg;base64,${base64Data}`;

      // 2b. Tải buffer ảnh thumbnail nhẹ để nhúng đồng bộ tức thì sang 2 điện thoại
      let thumbDataUrl = fullDataUrl;
      if (thumbPhoto && thumbPhoto.file_id !== bestPhoto.file_id) {
        try {
          const tfRes = await sendTelegram('getFile', { file_id: thumbPhoto.file_id });
          if (tfRes && tfRes.ok && tfRes.result && tfRes.result.file_path) {
            const tImgRes = await fetch(`https://api.telegram.org/file/bot${BOT_TOKEN}/${tfRes.result.file_path}`);
            if (tImgRes.ok) {
              const tBuf = await tImgRes.arrayBuffer();
              thumbDataUrl = `data:image/jpeg;base64,${Buffer.from(tBuf).toString('base64')}`;
            }
          }
        } catch (e) {}
      }

      // 3. Gọi Google Gemini Vision bóc tách 1 hoặc NHIỀU giao dịch cùng lúc + nhận diện ngân hàng
      const walletsPromptList = DB.wallets.map(w => `${w.id} (${w.name})`).join(' | ');
      const captionHint = msg.caption ? `\nChú thích người dùng gửi kèm ảnh: "${msg.caption}".` : '';
      const promptText = `Bạn là chuyên gia phân tích hóa đơn và sao kê/lịch sử giao dịch ngân hàng cho gia đình Bảo & Oanh.
Hãy đọc thật kỹ bức ảnh này.${captionHint}
Danh sách tài khoản hiện có của gia đình: ${walletsPromptList}.

LƯU Ý QUAN TRỌNG VỀ PHÂN LOẠI ẢNH:
1. Nếu bức ảnh là MÀN HÌNH LỊCH SỬ GIAO DỊCH / SAO KÊ / DANH SÁCH BIẾN ĐỘNG SỐ DƯ có NHIỀU GIAO DỊCH độc lập (hoặc nhiều biên lai ghép chung):
   - Đặt "isMultiList": true.
   - Trích xuất TẤT CẢ từng giao dịch có trong ảnh vào mảng "transactions".
   - Khoản trừ tiền (- / chi tiêu / chuyển đi / thanh toán) đặt "kind": "e".
   - Khoản cộng tiền (+ / nhận tiền / lương / thu nhập) đặt "kind": "i".
2. Nếu bức ảnh chỉ là 1 TỜ HÓA ĐƠN MUA HÀNG ĐƠN LẺ (ví dụ bill siêu thị/nhà hàng gồm nhiều món cộng lại thành 1 tổng thanh toán) hoặc 1 BIÊN LAI CHUYỂN KHOẢN ĐƠN LẺ:
   - Đặt "isMultiList": false.
   - Mảng "transactions" chỉ chứa DUY NHẤT 1 phần tử là tổng số tiền thanh toán cuối cùng, kèm các món lẻ trong "items".

Trả về CHỈ DUY NHẤT một chuỗi JSON hợp lệ (không kèm markdown):
{
  "isMultiList": <true hoặc false>,
  "paymentAccount": "<tên ngân hàng, ví hoặc phương thức thanh toán nhận diện được từ logo/giao diện app trên ảnh hoặc chú thích: ACB | MB | VIB | VCB | Techcombank | BIDV | VietinBank | VPBank | TPBank | MoMo | Thẻ tín dụng | Tiền mặt | null>",
  "transactions": [
    {
      "amount": <số tiền nguyên dương VND, ví dụ 345000>,
      "kind": "<'e' nếu là chi tiêu / trừ tiền (-); 'i' nếu là thu nhập / cộng tiền (+)>",
      "title": "<tên cửa hàng, người nhận hoặc nội dung giao dịch ngắn gọn, ví dụ: WinMart, Highlands Coffee, Chuyển khoản ăn trưa>",
      "category": "<một trong các danh mục: Ăn uống | Chợ & Siêu thị | Nhà cửa | Hóa đơn | Đi lại | Con cái | Mua sắm | Giải trí | Sức khỏe | Lương & Thưởng | Kinh doanh | Khác>",
      "date": "<ngày tháng của giao dịch đó dạng DD/MM/YYYY hoặc DD/MM nếu thấy trên ảnh, hoặc null>",
      "refCode": "<mã giao dịch hoặc giờ giao dịch HH:mm nếu thấy trên ảnh, hoặc null>",
      "items": [
        { "name": "<tên món hàng nếu là 1 hóa đơn siêu thị/nhà hàng>", "price": <giá tiền số nguyên VND hoặc null> }
      ]
    }
  ]
}`;

      const geminiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${encodeURIComponent(GEMINI_API_KEY)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: promptText },
              { inline_data: { mime_type: 'image/jpeg', data: base64Data } }
            ]
          }],
          generationConfig: {
            temperature: 0.1,
            response_mime_type: 'application/json'
          }
        })
      });

      if (!geminiRes.ok) throw new Error('API Key không hợp lệ hoặc hết hạn mức Gemini');
      const geminiData = await geminiRes.json();
      let textOut = '';
      if (geminiData.candidates && geminiData.candidates[0] && geminiData.candidates[0].content && Array.isArray(geminiData.candidates[0].content.parts)) {
        for (const p of geminiData.candidates[0].content.parts) {
          if (p.text) textOut += p.text + '\n';
        }
      }
      if (!textOut.trim()) throw new Error('AI không nhận diện được hóa đơn');

      const jsonMatch = textOut.match(/\{[\s\S]*\}/);
      if (!jsonMatch) throw new Error('Không phân tích được kết quả JSON từ AI');
      const parsed = JSON.parse(jsonMatch[0]);

      // Chuẩn hóa danh sách giao dịch từ kết quả AI (hỗ trợ cả schema mới transactions[] và schema cũ)
      let rawTxs = Array.isArray(parsed.transactions) ? parsed.transactions : [];
      if (rawTxs.length === 0 && parsed.amount) {
        rawTxs = [{
          amount: parsed.amount,
          kind: 'e',
          title: parsed.merchant || parsed.category || 'Hóa đơn',
          category: parsed.category,
          date: parsed.date,
          items: parsed.items
        }];
      }

      // Ưu tiên tài khoản từ chú thích ảnh -> đến ngân hàng AI đọc trên ảnh -> đến tài khoản mặc định
      const walletId = (msg.caption && parseWallet(msg.caption)) ||
        (parsed.paymentAccount && parseWallet(parsed.paymentAccount)) ||
        (parsed.paymentAccount && findWalletByIdOrKeyword(parsed.paymentAccount)) ||
        getDefaultWalletForRole(myRole);

      const validTxs = [];
      const duplicates = [];

      for (const item of rawTxs) {
        const amt = parseInt(String(item.amount || '').replace(/[^0-9]/g, ''), 10);
        if (!amt || amt <= 0) continue;
        const kind = item.kind === 'i' ? 'i' : 'e';
        const dmy = parseDateToDMY(item.date || parsed.date);
        const rawTitle = (item.title || item.merchant || parsed.merchant || item.category || 'Giao dịch').trim();
        const catInfo = resolveCategoryForTx(item.category || parsed.category, rawTitle, kind);

        const candidate = {
          amount: amt,
          kind: kind,
          title: rawTitle,
          category: catInfo.cat,
          icon: catInfo.icon,
          day: dmy.day,
          month: dmy.month,
          year: dmy.year,
          dateLabel: dmy.label,
          refCode: item.refCode ? String(item.refCode).trim() : null,
          items: Array.isArray(item.items) ? item.items.slice(0, 8) : [],
          wallet: walletId,
          selected: true
        };

        // Kiểm tra trùng lặp với sổ DB.transactions hiện tại VÀ với các dòng vừa duyệt trong cùng bức ảnh
        const dupInDB = findDuplicateTransaction(candidate, DB.transactions);
        const dupInBatch = candidate.refCode
          ? validTxs.find(v => v.refCode === candidate.refCode && v.amount === candidate.amount)
          : null;

        if (dupInDB || dupInBatch) {
          duplicates.push({
            ...candidate,
            matchedId: dupInDB ? dupInDB.id : null
          });
        } else {
          validTxs.push(candidate);
        }
      }

      if (validTxs.length === 0 && duplicates.length === 0) {
        throw new Error('Không tìm thấy số tiền giao dịch hợp lệ trên ảnh');
      }

      // Nếu TẤT CẢ các giao dịch trên ảnh đều đã bị trùng lặp trong sổ
      if (validTxs.length === 0 && duplicates.length > 0) {
        const dupLines = duplicates.slice(0, 10).map((d, idx) => {
          const sign = d.kind === 'i' ? '+' : '-';
          return `${idx + 1}. ⛔ <b>${d.title}</b>: <code>${sign}${formatVND(d.amount)} ₫</code> <i>(Đã có ngày ${d.dateLabel})</i>`;
        }).join('\n');
        return sendMessage(chatId,
          `🛡 <b>PHÁT HIỆN TRÙNG LẶP — KHÔNG THÊM LẠI!</b>\n\n` +
          `Tất cả <b>${duplicates.length} giao dịch</b> trong bức ảnh bạn vừa gửi đều <b>đã tồn tại trong sổ Ví Đôi</b>:\n\n` +
          `${dupLines}\n\n` +
          `✨ <i>Hệ thống tự động bỏ qua để không bị cộng đúp số tiền của hai vợ chồng!</i>`
        );
      }

      const firstTx = validTxs[0];
      const billId = 'b' + Date.now();
      const billDraft = {
        id: billId,
        amount: firstTx.amount,
        merchant: firstTx.title,
        category: firstTx.category,
        icon: firstTx.icon,
        items: firstTx.items || [],
        date: firstTx.dateLabel,
        wallet: walletId,
        who: myRole,
        txList: validTxs,
        duplicates: duplicates,
        receiptThumb: thumbDataUrl,
        receiptFull: fullDataUrl,
        chatId: chatId,
        createdAt: Date.now()
      };

      PENDING_BILLS.set(billId, billDraft);

      // Gửi thẻ xem lại thông tin tự động điền để người dùng duyệt trước khi lưu
      return renderBillPreviewCard(chatId, null, billDraft);
    } catch (err) {
      console.error('Lỗi quét hóa đơn Telegram:', err);
      return sendMessage(chatId, `⚠️ <b>Không thể đọc hóa đơn bằng AI:</b> ${err.message || 'Lỗi xử lý ảnh.'}\n\nBạn có thể gõ tay nhanh, ví dụ: <code>đi chợ 250k vcb</code> ✨`);
    }
  }

  // C. Xử lý Tin nhắn văn bản
  if (!update.message || !update.message.text) return;

  const msg = update.message;
  const chatId = msg.chat.id;
  const text = msg.text.trim();
  const tgUserId = String(msg.from.id);
  const myRole = DB.telegramUsers[tgUserId] || 'him';

  // Lệnh /start (hoặc /star do gõ thiếu chữ t)
  if (text === '/start' || text === '/star') {
    return sendMessage(chatId, `💑 <b>Chào mừng bạn đến với Bot Ghi Chép Nhanh — Ví Đôi (Bảo & Oanh)!</b>\n\nĐể bot nhận diện đúng người ghi, vui lòng chọn bạn là ai:`, {
      reply_markup: {
        inline_keyboard: [
          [
            { text: '👨 Tôi là Bảo (Chồng)', callback_data: 'set_role_him' },
            { text: '👩 Tôi là Oanh (Vợ)', callback_data: 'set_role_her' }
          ]
        ]
      }
    });
  }

  // Lệnh /role
  if (text.startsWith('/role')) {
    const parts = text.split(' ');
    if (parts[1] === 'him' || parts[1] === 'bao' || parts[1] === 'chong') {
      DB.telegramUsers[tgUserId] = 'him';
      saveDB();
      return sendMessage(chatId, `✅ Đã thiết lập vai trò: <b>👨 Bảo (Chồng)</b>`);
    } else if (parts[1] === 'her' || parts[1] === 'oanh' || parts[1] === 'vo') {
      DB.telegramUsers[tgUserId] = 'her';
      saveDB();
      return sendMessage(chatId, `✅ Đã thiết lập vai trò: <b>👩 Oanh (Vợ)</b>`);
    } else {
      return sendMessage(chatId, `💡 Cú pháp: <code>/role him</code> (Bảo) hoặc <code>/role her</code> (Oanh)`);
    }
  }

  // Lệnh /vi hoặc /sodu
  if (text === '/vi' || text === '/sodu') {
    return sendWalletsOverview(chatId);
  }

  // Lệnh /themvi <Tên ngân hàng/tài khoản>
  if (text.startsWith('/themvi')) {
    const wName = text.replace(/^\/themvi\s*/i, '').trim();
    if (!wName) {
      return sendMessage(chatId, `💡 <b>Cách thêm tài khoản / ngân hàng mới:</b>\nGõ: <code>/themvi Ngân hàng BIDV</code> hoặc mở app Ví Đôi ➔ Quản lý Ví.`);
    }
    const cleanId = wName.toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 10) || ('w_' + Date.now().toString(36));
    const finalId = DB.wallets.some(w => w.id === cleanId) ? ('w_' + Date.now().toString(36)) : cleanId;
    const isCard = wName.toLowerCase().includes('tín dụng') || wName.toLowerCase().includes('thẻ');
    const newW = {
      id: finalId,
      name: wName,
      icon: isCard ? '💳' : '🏦',
      balance: 0,
      owner: myRole,
      color: '#0066FF,#38bdf8'
    };
    DB.wallets.push(newW);
    saveDB();
    await broadcastToPWA();
    return sendMessage(chatId, `✅ Đã thêm tài khoản mới: <b>${newW.icon} ${newW.name}</b> và đồng bộ sang Ví Đôi PWA!`);
  }

  // Lệnh /baocao hoặc /thongke (Lọc chính xác theo Tháng & Năm hiện tại)
  if (text === '/baocao' || text === '/thongke') {
    const now = new Date();
    const curMonth = now.getMonth() + 1;
    const curYear = now.getFullYear();

    let totalExp = 0;
    let totalInc = 0;
    for (const t of DB.transactions) {
      const txM = t.month || (t.id > 1000000000000 ? (new Date(t.id).getMonth() + 1) : curMonth);
      const txY = t.year || (t.id > 1000000000000 ? new Date(t.id).getFullYear() : curYear);
      if (txM !== curMonth || txY !== curYear) continue;
      if (t.kind === 'e') totalExp += t.amount;
      else if (t.kind === 'i') totalInc += t.amount;
    }

    return sendMessage(chatId, `📊 <b>Báo cáo Chi tiêu Tháng ${curMonth}/${curYear}:</b>\n\n` +
      `💰 <b>Tổng thu nhập:</b> +${formatVND(totalInc)} ₫\n` +
      `💸 <b>Tổng chi tiêu:</b> -${formatVND(totalExp)} ₫\n` +
      `⚖️ <b>Số dư ròng:</b> ${formatVND(totalInc - totalExp)} ₫\n\n` +
      `<i>Mở ứng dụng Ví Đôi PWA để xem biểu đồ và cơ cấu chi tiết.</i>`
    );
  }

  // Lệnh /backup hoặc /saoluu: Đóng gói và gửi file sao lưu database về Telegram
  if (text === '/backup' || text === '/saoluu') {
    const backupJson = JSON.stringify(DB, null, 2);
    const now = new Date();
    const pad = n => String(n).padStart(2, '0');
    const nowStr = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
    const fileName = `vidoi_backup_${nowStr}.json`;
    const caption = `💾 <b>BẢO MẬT & SAO LƯU MÁY CHỦ THÀNH CÔNG!</b>\n\n` +
      `• <b>Thời gian:</b> ${now.toLocaleString('vi-VN')}\n` +
      `• <b>Tổng số giao dịch:</b> ${DB.transactions.length}\n` +
      `• <b>Tài khoản / Ví:</b> ${DB.wallets.length} tài khoản\n` +
      `• <b>Kích thước file:</b> ${(Buffer.byteLength(backupJson, 'utf8') / 1024).toFixed(1)} KB\n` +
      `• <b>Mã gia đình:</b> <code>${FAMILY_CODE}</code>\n\n` +
      `<i>Bạn có thể nạp file JSON này vào ứng dụng Ví Đôi PWA mục Khôi phục từ file JSON bất cứ lúc nào!</i>`;

    await sendMessage(chatId, `⏳ <i>Đang đóng gói dữ liệu máy chủ và gửi file sao lưu qua Telegram...</i>`);
    await sendTelegramDocument(chatId, fileName, Buffer.from(backupJson, 'utf8'), caption);
    return;
  }

  // Lệnh /help
  if (text === '/help') {
    return sendMessage(chatId, `📖 <b>Hướng dẫn sử dụng Bot Ví Đôi — Bảo & Oanh:</b>\n\n` +
      `• <b>Ghi chép chi tiêu theo từng Ngân hàng / Ví:</b>\n` +
      `  <code>cf 45k tiền mặt</code>\n` +
      `  <code>đi chợ 250k acb</code>\n` +
      `  <code>ăn tối 320k mb</code>\n` +
      `  <code>đổ xăng 120k vib</code>\n` +
      `  <code>mua đồ shopee 350k tín dụng</code>\n` +
      `  <i>(Hoặc gõ nhanh <code>cf 45k</code> rồi bấm nút <b>💳 Đổi tài khoản</b> ngay dưới tin nhắn!)</i>\n\n` +
      `• <b>Ghi nhận thu nhập / Tiền về:</b>\n` +
      `  <code>lương 25tr acb</code>\n` +
      `  <code>thu 5tr bán hàng mb</code>\n\n` +
      `• <b>Chuyển tiền giữa bất kỳ 2 tài khoản nào:</b>\n` +
      `  <code>chuyển 5tr acb sang vib</code>\n` +
      `  <code>chuyển 2tr mb qua tiền mặt</code>\n\n` +
      `• <b>Quét hóa đơn bằng AI:</b> Gửi trực tiếp ảnh chụp hóa đơn vào chat, bot sẽ tự động đọc tên cửa hàng, tổng tiền và đồng bộ cả ảnh hóa đơn sang 2 điện thoại!\n\n` +
      `• <b>Xem số dư tất cả tài khoản:</b> gõ <code>/vi</code>\n` +
      `• <b>Thêm tài khoản mới:</b> gõ <code>/themvi Tên_Ngân_Hàng</code>\n` +
      `• <b>Báo cáo tháng:</b> gõ <code>/baocao</code>\n` +
      `• <b>Sao lưu máy chủ:</b> gõ <code>/backup</code>\n` +
      `• <b>Đổi vai trò:</b> gõ <code>/role him</code> (Bảo) hoặc <code>/role her</code> (Oanh)`
    );
  }

  // C. Phân tích tin nhắn thành Giao dịch (Ưu tiên Regex siêu tốc, nếu không khớp thì gọi AI)
  let parsed = parseTextToTransaction(text, myRole);
  if (!parsed && GEMINI_API_KEY) {
    parsed = await parseExpenseWithAI(text, myRole);
  }

  if (!parsed) {
    // Không nhận diện được số tiền
    return sendMessage(chatId, `🤔 Chưa nhận diện được số tiền trong tin nhắn của bạn.\n\nVí dụ mẫu:\n• <code>cf 45k</code>\n• <code>ăn trưa 80k vcb</code>\n• <code>lương 25tr</code>\n\n<i>Gõ <b>/help</b> để xem hướng dẫn đầy đủ.</i>`);
  }

  // Tạo ID giao dịch kèm Ngày / Tháng / Năm chuẩn xác
  const curTxId = Date.now();
  const nowD = new Date();
  const day = nowD.getDate();

  const newTx = {
    id: curTxId,
    day: day,
    month: nowD.getMonth() + 1,
    year: nowD.getFullYear(),
    icon: parsed.icon,
    title: parsed.title,
    category: parsed.category,
    amount: parsed.amount,
    who: parsed.who,
    shared: parsed.shared,
    wallet: parsed.wallet,
    kind: parsed.kind,
    note: parsed.note,
    receipt: null,
    receiptThumb: null,
    comments: [],
    updatedAt: curTxId
  };

  if (parsed.kind === 't') {
    newTx.toWallet = parsed.toWallet;
  }

  // Cập nhật số dư ví
  if (parsed.kind === 't') {
    const fromW = DB.wallets.find(w => w.id === parsed.wallet);
    const toW = DB.wallets.find(w => w.id === parsed.toWallet);
    if (fromW) fromW.balance -= parsed.amount;
    if (toW) toW.balance += parsed.amount;
  } else {
    const w = DB.wallets.find(w => w.id === parsed.wallet);
    if (w) {
      w.balance += (parsed.kind === 'i' ? parsed.amount : -parsed.amount);
    }
  }

  DB.transactions.unshift(newTx);
  if (!DB.defaultWallet) DB.defaultWallet = {};
  if (parsed.kind !== 't') {
    DB.defaultWallet[parsed.who] = parsed.wallet;
  }
  saveDB();

  // Bắn realtime sang PWA
  broadcastToPWA();

  // Phản hồi Telegram với thẻ thông tin kèm dãy nút chọn nhanh Tài khoản 1 chạm
  const card = buildSavedTxCard(newTx);
  return sendMessage(chatId, card.text, {
    reply_markup: card.reply_markup
  });
}

async function sendWalletsOverview(chatId) {
  let msg = `💳 <b>Số dư các tài khoản & ví hiện tại:</b>\n\n`;
  let total = 0;
  for (const w of DB.wallets) {
    msg += `• ${w.icon} <b>${w.name}</b>: <code>${formatVND(w.balance)} ₫</code>\n`;
    total += (w.balance || 0);
  }
  msg += `\n═════════════════\n`;
  msg += `🏦 <b>Tổng tài sản tích lũy:</b> <code>${formatVND(total)} ₫</code>`;

  return sendMessage(chatId, msg, {
    reply_markup: {
      inline_keyboard: [
        [{ text: '🔄 Cập nhật lại', callback_data: 'view_wallets' }]
      ]
    }
  });
}

// 8. Long Polling Loop (Nhận tin nhắn liên tục từ Telegram Bot API)
let lastUpdateId = 0;

async function pollUpdates() {
  try {
    const res = await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${lastUpdateId + 1}&timeout=30`);
    if (!res.ok) {
      console.warn('⚠️ Polling error:', res.status, res.statusText);
      await new Promise(r => setTimeout(r, 4000));
      return;
    }
    const data = await res.json();
    if (data.ok && Array.isArray(data.result)) {
      for (const update of data.result) {
        lastUpdateId = update.update_id;
        try {
          await handleUpdate(update);
        } catch (err) {
          console.error('Lỗi khi xử lý update:', err);
        }
      }
    }
  } catch (err) {
    console.warn('⚠️ Lỗi kết nối Telegram Polling:', err.message);
    await new Promise(r => setTimeout(r, 5000));
  }
}

async function startBot() {
  console.log('========================================================');
  console.log('🤖 Ví Đôi — Telegram Bot Ghi Chép Nhanh đang khởi động...');
  console.log(`🔐 Mã gia đình: ${FAMILY_CODE} | PIN: ${FAMILY_PIN}`);
  console.log(`☁️ Kênh ntfy đồng bộ: ${CLOUD_TOPIC}`);
  console.log('========================================================');

  // Kiểm tra token bot
  const me = await sendTelegram('getMe', {});
  if (!me || !me.ok) {
    console.error('❌ Token Telegram không hợp lệ! Vui lòng kiểm tra TELEGRAM_BOT_TOKEN.');
    process.exit(1);
  }
  console.log(`✅ Kết nối thành công tới Bot: @${me.result.username} (${me.result.first_name})`);
  await pullFromPWA(true);
  console.log(`🏦 Danh sách tài khoản hiện tại (${DB.wallets.length}): ${DB.wallets.map(w => w.name).join(', ')}`);
  console.log('🚀 Đang lắng nghe tin nhắn ghi chép từ hai vợ chồng...');

  // Tiến trình tự động gửi bản sao lưu máy chủ mỗi đêm lúc 02:00 AM
  let lastBackupDay = -1;
  setInterval(async () => {
    const now = new Date();
    if (now.getHours() === 2 && now.getDate() !== lastBackupDay) {
      lastBackupDay = now.getDate();
      console.log('⏰ [Cronjob] Bắt đầu tiến trình tự động sao lưu đêm 02:00 AM...');
      const userIds = Object.keys(DB.telegramUsers || {});
      if (userIds.length > 0) {
        const backupJson = JSON.stringify(DB, null, 2);
        const pad = n => String(n).padStart(2, '0');
        const nowStr = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_020000`;
        const fileName = `vidoi_nightly_backup_${nowStr}.json`;
        const caption = `🌙 <b>BẢN SAO LƯU ĐỊNH KỲ TỰ ĐỘNG (02:00 AM)</b>\n\n` +
          `• <b>Ngày:</b> ${now.toLocaleDateString('vi-VN')}\n` +
          `• <b>Tổng số giao dịch:</b> ${DB.transactions.length}\n` +
          `• <b>Trạng thái:</b> Dữ liệu máy chủ an toàn 100% ✅`;

        for (const uid of userIds) {
          try {
            await sendTelegramDocument(uid, fileName, Buffer.from(backupJson, 'utf8'), caption);
          } catch (e) {
            console.warn(`Lỗi gửi backup đêm tới user ${uid}:`, e.message);
          }
        }
      }
    }
  }, 60 * 1000);

  while (true) {
    await pollUpdates();
  }
}

startBot();
