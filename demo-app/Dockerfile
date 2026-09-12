FROM node:22-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev 2>/dev/null || npm install
COPY . ./
ENV PORT=8080 NODE_ENV=production
EXPOSE 8080
CMD ["node", "server.js"]
