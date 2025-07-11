# ---- 第 1 阶段：安装依赖 ----
FROM node:20-alpine AS deps

# 启用 corepack 并激活 pnpm（Node20 默认提供 corepack）
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# 仅复制依赖清单，提高构建缓存利用率
COPY package.json pnpm-lock.yaml ./

# 安装所有依赖（含 devDependencies，后续会裁剪）
RUN pnpm install --frozen-lockfile

# ---- 第 2 阶段：构建项目 ----
FROM node:20-alpine AS builder
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app

# 复制依赖
COPY --from=deps /app/node_modules ./node_modules
# 复制全部源代码
COPY . .

# 生成生产构建
RUN pnpm run build

# ---- 第 3 阶段：生成运行时镜像 ----
FROM node:20-alpine AS runner

# 创建非 root 用户
RUN addgroup -g 1001 -S nodejs && adduser -u 1001 -S nextjs -G nodejs

WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

# 复制必要文件
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/next.config.js ./next.config.js
COPY --from=builder /app/config.json ./config.json

# 切换到非特权用户
USER nextjs

EXPOSE 3000

# 使用 next binary 启动
CMD ["node_modules/.bin/next", "start", "-H", "0.0.0.0", "-p", "3000"] 