FROM node:18-alpine

WORKDIR /app

COPY package.json ./
COPY bot.js ./

# Tạo thư mục data để mount volume
RUN mkdir -p /app/data

ENV NODE_ENV=production

CMD ["node", "bot.js"]
