/**
 * Ví Đôi — Telegram Bot Ghi Chép Nhanh Cho Hai Vợ Chồng (Bảo & Oanh)
 * Đồng bộ thời gian thực 2 chiều với Ví Đôi PWA
 * Không cần thư viện ngoài (sử dụng Native fetch & Node.js 18+)
 */

const fs = require('fs');
const path = require('path');

// 1. Cấu hình Môi trường
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '';
const FAMILY_CODE = (process.env.FAMILY_CODE || 'BO8686').toUpperCase();
const FAMILY_PIN = process.env.FAMILY_PIN || '2611';
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

// 3. Cơ sở dữ liệu Cục bộ
function loadDB() {
  if (fs.existsSync(DB_FILE)) {
    try {
      return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
    } catch (e) {
      console.warn('⚠️ Không thể đọc database.json, khởi tạo lại');
    }
  }
  return {
    users: {
      him: { name: 'Bảo', color: '#4C8DFF', role: 'Chồng' },
      her: { name: 'Oanh', color: '#FF7EB6', role: 'Vợ' }
    },
    telegramUsers: {}, // { "12345678": "him", "87654321": "her" }
    wallets: [
      { id: 'vcb', name: 'Ví chung VCB', icon: '🏦', balance: 0, owner: 'S', color: '#7C5CFF,#a78bfa' },
      { id: 'cash', name: 'Tiền mặt (Bảo)', icon: '💵', balance: 0, owner: 'him', color: '#22C55E,#4ade80' },
      { id: 'momo', name: 'Ví riêng (Oanh)', icon: '📱', balance: 0, owner: 'her', color: '#EC4899,#f9a8d4' },
      { id: 'tcb', name: 'Thẻ tín dụng', icon: '💳', balance: 0, owner: 'him', color: '#EF4444,#fb7185' }
    ],
    deletedTxIds: [],
    transactions: []
  };
}

const DB = loadDB();

function saveDB() {
  fs.writeFileSync(DB_FILE, JSON.stringify(DB, null, 2), 'utf8');
}

// 4. Đồng bộ Realtime sang PWA Ví Đôi qua ntfy.sh
async function broadcastToPWA(payload) {
  try {
    const compactPayload = {
      _v: 2,
      deviceId: 'telegram_bot_' + Date.now().toString(36),
      ts: Date.now(),
      familyCode: FAMILY_CODE,
      familyPin: FAMILY_PIN,
      users: DB.users,
      wallets: DB.wallets,
      deletedTxIds: (DB.deletedTxIds || []).slice(-200),
      transactions: (DB.transactions || []).slice(0, 100),
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

function parseWallet(text) {
  const t = text.toLowerCase();
  if (t.includes('vcb') || t.includes('vietcombank') || t.includes('ví chung') || t.includes('vi chung')) return 'vcb';
  if (t.includes('momo') || t.includes('ví riêng') || t.includes('vi rieng')) return 'momo';
  if (t.includes('tcb') || t.includes('techcombank') || t.includes('tin dung') || t.includes('tín dụng') || t.includes('the') || t.includes('thẻ')) return 'tcb';
  if (t.includes('tien mat') || t.includes('tiền mặt') || t.includes('mat') || t.includes('mặt') || t.includes('cash')) return 'cash';
  return null;
}

function parseTextToTransaction(rawText, defaultWho = 'him') {
  const text = rawText.trim();
  const amt = parseAmount(text);
  if (!amt || amt <= 0) return null;

  const lower = text.toLowerCase();

  // 1. Kiểm tra xem có phải Chuyển ví không (Transfer)
  const isTransfer = lower.startsWith('chuyen ') || lower.startsWith('chuyển ') || lower.includes(' sang ') || lower.includes(' qua ');
  if (isTransfer) {
    let fromW = 'vcb';
    let toW = 'cash';
    if (lower.includes('vcb sang tiet kiem') || lower.includes('vcb sang tiết kiệm') || lower.includes('sang tiet kiem')) {
      fromW = 'vcb'; toW = 'tcb';
    } else if (lower.includes('vcb sang tien mat') || lower.includes('vcb qua tien mat') || lower.includes('vcb sang tiền mặt')) {
      fromW = 'vcb'; toW = 'cash';
    } else if (lower.includes('tien mat sang vcb') || lower.includes('tiền mặt sang vcb')) {
      fromW = 'cash'; toW = 'vcb';
    }

    return {
      kind: 't',
      amount: amt,
      title: `Chuyển ví qua Telegram: ${amt.toLocaleString('vi-VN')} ₫`,
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

  // Xác định ví tài khoản
  let walletId = parseWallet(text);
  if (!walletId) {
    // Mặc định ví của người gửi
    walletId = defaultWho === 'her' ? 'momo' : 'cash';
  }

  // Tách title
  let cleanTitle = text
    .replace(/(?:vcb|momo|tcb|tien mat|tiền mặt|the tin dung|thẻ tín dụng)/gi, '')
    .replace(/(?:\d+(?:\.\d+)?\s*(?:tr|k|vnd|đ|₫)?|\b\d{4,10}\b)/gi, '')
    .trim();

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

// 7. Xử lý Lệnh & Tin nhắn người dùng
async function handleUpdate(update) {
  // A. Xử lý Callback Button (Inline keyboard)
  if (update.callback_query) {
    const cq = update.callback_query;
    const data = cq.data || '';
    const chatId = cq.message.chat.id;
    const msgId = cq.message.message_id;

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
        saveDB();
        await broadcastToPWA();
        await sendTelegram('answerCallbackQuery', { callback_query_id: cq.id, text: tx.shared ? 'Đã đổi thành Khoản Chung!' : 'Đã đổi thành Khoản Riêng!' });
        await sendMessage(chatId, `🔄 Giao dịch <b>${tx.title}</b> đã đổi thành: <b>${tx.shared ? '👥 Khoản Chung' : '🔒 Khoản Riêng'}</b>.`);
      }
      return;
    }

    if (data === 'view_wallets') {
      await sendWalletsOverview(chatId);
      return;
    }
  }

  // B. Xử lý Tin nhắn văn bản
  if (!update.message || !update.message.text) return;

  const msg = update.message;
  const chatId = msg.chat.id;
  const text = msg.text.trim();
  const tgUserId = String(msg.from.id);
  const myRole = DB.telegramUsers[tgUserId] || 'him';

  // Lệnh /start
  if (text === '/start') {
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

  // Lệnh /baocao hoặc /thongke
  if (text === '/baocao' || text === '/thongke') {
    const now = new Date();
    const curMonth = now.getMonth();
    const curYear = now.getFullYear();

    let totalExp = 0;
    let totalInc = 0;
    for (const t of DB.transactions) {
      if (t.kind === 'e') totalExp += t.amount;
      else if (t.kind === 'i') totalInc += t.amount;
    }

    return sendMessage(chatId, `📊 <b>Báo cáo Chi tiêu Tháng ${curMonth + 1}/${curYear}:</b>\n\n` +
      `💰 <b>Tổng thu nhập:</b> +${formatVND(totalInc)} ₫\n` +
      `💸 <b>Tổng chi tiêu:</b> -${formatVND(totalExp)} ₫\n` +
      `⚖️ <b>Số dư ròng:</b> ${formatVND(totalInc - totalExp)} ₫\n\n` +
      `<i>Mở ứng dụng Ví Đôi PWA để xem biểu đồ và cơ cấu chi tiết.</i>`
    );
  }

  // Lệnh /help
  if (text === '/help') {
    return sendMessage(chatId, `📖 <b>Hướng dẫn ghi chép siêu tốc qua Telegram:</b>\n\n` +
      `• <b>Chi tiêu ăn uống, mua sắm:</b>\n` +
      `  <code>cf 45k</code>\n` +
      `  <code>ăn sáng 65k tiền mặt</code>\n` +
      `  <code>đi chợ 250k vcb</code>\n` +
      `  <code>xăng xe 120k</code>\n` +
      `  <code>mua đồ shopee 350k tín dụng</code>\n\n` +
      `• <b>Thu nhập / Tiền về:</b>\n` +
      `  <code>lương 25tr vcb</code>\n` +
      `  <code>thu 5tr bán hàng</code>\n\n` +
      `• <b>Chuyển tiền giữa các ví / Tiết kiệm:</b>\n` +
      `  <code>chuyển 5tr vcb sang tiết kiệm</code>\n` +
      `  <code>chuyển 1tr vcb qua tiền mặt</code>\n\n` +
      `• <b>Xem số dư ví:</b> gõ <code>/vi</code>\n` +
      `• <b>Báo cáo tháng:</b> gõ <code>/baocao</code>\n` +
      `• <b>Đổi vai trò:</b> gõ <code>/role him</code> hoặc <code>/role her</code>`
    );
  }

  // C. Phân tích tin nhắn thành Giao dịch
  const parsed = parseTextToTransaction(text, myRole);
  if (!parsed) {
    // Không nhận diện được số tiền
    return sendMessage(chatId, `🤔 Chưa nhận diện được số tiền trong tin nhắn của bạn.\n\nVí dụ mẫu:\n• <code>cf 45k</code>\n• <code>ăn trưa 80k vcb</code>\n• <code>lương 25tr</code>\n\n<i>Gõ <b>/help</b> để xem hướng dẫn đầy đủ.</i>`);
  }

  // Tạo ID giao dịch
  const curTxId = Date.now();
  const day = new Date().getDate();

  const newTx = {
    id: curTxId,
    day: day,
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
  saveDB();

  // Bắn realtime sang PWA
  broadcastToPWA();

  // Phản hồi Telegram với thẻ thông tin đẹp mắt
  const isInc = parsed.kind === 'i';
  const isTrans = parsed.kind === 't';
  const headerIcon = isInc ? '💰' : isTrans ? '🔄' : '💸';
  const amtStr = isInc ? `+${formatVND(parsed.amount)} ₫` : isTrans ? `🔄 ${formatVND(parsed.amount)} ₫` : `-${formatVND(parsed.amount)} ₫`;

  let details = '';
  if (isTrans) {
    details = `• <b>Từ ví:</b> ${getWalletName(parsed.wallet)}\n• <b>Đến ví:</b> ${getWalletName(parsed.toWallet)}`;
  } else {
    details = `• <b>Tài khoản:</b> ${getWalletName(parsed.wallet)}\n• <b>Danh mục:</b> ${parsed.icon} ${parsed.category}`;
  }

  const replyText = `${headerIcon} <b>Đã ghi chép thành công!</b>\n\n` +
    `<b>${parsed.title}</b>: <code>${amtStr}</code>\n` +
    `${details}\n` +
    `• <b>Người ghi:</b> ${formatRole(parsed.who)} (${parsed.shared ? '👥 Chung' : '🔒 Riêng'})\n\n` +
    `⚡ <i>Đã đồng bộ tức thì sang Ví Đôi PWA của cả hai vợ chồng!</i>`;

  return sendMessage(chatId, replyText, {
    reply_markup: {
      inline_keyboard: [
        [
          { text: '🗑 Hủy / Xóa', callback_data: `del_tx_${curTxId}` },
          { text: parsed.shared ? '🔒 Đổi sang Riêng' : '👥 Đổi sang Chung', callback_data: `toggle_shared_${curTxId}` }
        ],
        [
          { text: '📊 Xem số dư ví', callback_data: 'view_wallets' }
        ]
      ]
    }
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
  console.log('🚀 Đang lắng nghe tin nhắn ghi chép từ hai vợ chồng...');

  while (true) {
    await pollUpdates();
  }
}

startBot();
