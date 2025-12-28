# ClickVisual Complete Stack Helm Chart

一个完整的 ClickVisual 技术栈 Helm Chart，支持一键部署所有依赖服务。

## 功能特性

- **智能依赖管理**：自动检测并部署所需的依赖服务
- **两种部署模式**：
  - **独立模式**（默认）：自动部署 MySQL、Redis、ClickHouse、Kafka 等所有依赖
  - **外部模式**：连接已有的外部服务
- **开箱即用**：默认配置即可快速启动完整的日志分析平台
- **高度可定制**：所有组件的资源、存储、配置都可自定义

## 架构组件

部署后的完整技术栈包括：

| 组件 | 作用 | 默认启用 | 可选 |
|------|------|---------|------|
| **ClickVisual** | 日志分析 Web 应用 | ✅ | ❌ |
| **MySQL** | 元数据存储 | ✅ | ✅ |
| **Redis** | 会话缓存 | ✅ | ✅ |
| **ClickHouse** | 日志数据存储 | ✅ | ✅ |
| **Kafka** | 消息队列 | ✅ | ✅ |
| **Zookeeper** | Kafka 依赖 | ✅ | ✅ |
| **Fluent-bit** | 日志采集器 | ✅ | ✅ |
| **Prometheus** | 监控（可选） | ❌ | ✅ |

## 前置要求

- Kubernetes >= 1.17
- Helm >= 3.0.0
- 可用的 StorageClass（用于持久化存储）
- 至少 8GB 可用内存（完整部署）

## 快速开始

### 方式 1: 完全独立部署（推荐新手）

使用默认配置，一键部署所有组件：

```bash
# 创建命名空间
kubectl create namespace clickvisual

# 部署完整技术栈
helm install clickvisual-stack ./clickvisual-stack \
  --namespace clickvisual \
  --wait

# 等待所有 Pod 就绪（约 2-5 分钟）
kubectl get pods -n clickvisual -w
```

部署完成后，访问 ClickVisual：

```bash
# 端口转发
kubectl port-forward -n clickvisual svc/clickvisual-stack-clickvisual 19001:19001

# 浏览器访问 http://localhost:19001
# 默认账号: clickvisual
# 默认密码: clickvisual
```

### 方式 2: 使用外部服务

如果你已有 MySQL、Redis 等服务，可以禁用内部部署：

```bash
helm install clickvisual-stack ./clickvisual-stack \
  --namespace clickvisual \
  --set mysql.enabled=false \
  --set mysql.external.host=your-mysql-host \
  --set mysql.external.port=3306 \
  --set mysql.external.password=your-password \
  --set redis.enabled=false \
  --set redis.external.host=your-redis-host \
  --wait
```

### 方式 3: 自定义 values.yaml

创建自定义配置文件 `my-values.yaml`：

```yaml
# 禁用不需要的组件
prometheus:
  enabled: false

# 自定义资源配置
clickvisual:
  replicaCount: 2
  resources:
    limits:
      cpu: 2000m
      memory: 1Gi

# 使用外部 MySQL
mysql:
  enabled: false
  external:
    host: "mysql.example.com"
    port: 3306
    database: "clickvisual"
    username: "root"
    password: "your-password"

# 启用 Ingress
clickvisual:
  ingress:
    enabled: true
    className: "nginx"
    hosts:
      - host: clickvisual.example.com
        paths:
          - path: /
            pathType: Prefix
```

部署：

```bash
helm install clickvisual-stack ./clickvisual-stack \
  --namespace clickvisual \
  -f my-values.yaml \
  --wait
```

## 配置说明

### 全局配置

```yaml
global:
  # 默认 StorageClass（留空使用集群默认）
  storageClass: ""

  # 自定义命名空间（通常通过 --namespace 指定）
  namespaceOverride: ""
```

### ClickVisual 配置

```yaml
clickvisual:
  enabled: true
  replicaCount: 1

  image:
    repository: clickvisual/clickvisual
    tag: "latest"
    pullPolicy: IfNotPresent

  # 服务配置
  service:
    type: ClusterIP
    port: 19001

  # 应用配置
  config:
    # 会话加密密钥（生产环境请修改）
    secretKey: "change-me-in-production"

    # 应用访问地址
    rootURL: "http://localhost:19001"

    # 日志级别: debug, info, warn, error
    logLevel: "info"

    # 启用多副本模式（需要 Redis）
    isMultiCopy: false

    # OAuth 配置（可选）
    oauth:
      github:
        enabled: false
        clientId: ""
        clientSecret: ""
      gitlab:
        enabled: false
        clientId: ""
        clientSecret: ""

  # Ingress 配置
  ingress:
    enabled: false
    className: "nginx"
    annotations: {}
    hosts:
      - host: clickvisual.local
        paths:
          - path: /
            pathType: Prefix
    tls: []

  # 资源配置
  resources:
    limits:
      cpu: 1000m
      memory: 512Mi
    requests:
      cpu: 500m
      memory: 256Mi
```

### MySQL 配置

```yaml
mysql:
  # 启用内部 MySQL（false 则使用外部）
  enabled: true

  # 外部 MySQL 配置
  external:
    host: ""
    port: 3306
    database: "clickvisual"
    username: "root"
    password: ""

  # 内部 MySQL 配置
  auth:
    rootPassword: "shimo"
    database: "clickvisual"

  primary:
    persistence:
      enabled: true
      size: 8Gi
      storageClass: ""

    service:
      type: ClusterIP
      port: 3306

    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
      requests:
        cpu: 500m
        memory: 512Mi
```

### Redis 配置

```yaml
redis:
  enabled: true

  external:
    host: ""
    port: 6379
    password: ""
    database: 0

  auth:
    enabled: false
    password: ""

  master:
    persistence:
      enabled: true
      size: 2Gi

    service:
      type: ClusterIP
      port: 6379

    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 250m
        memory: 256Mi
```

### ClickHouse 配置

```yaml
clickhouse:
  enabled: true

  external:
    host: ""
    port: 9000
    httpPort: 8123
    username: "default"
    password: ""
    database: "default"

  auth:
    username: "root"
    password: "shimo"

  shards: 1
  replicaCount: 1

  persistence:
    enabled: true
    size: 20Gi

  service:
    type: ClusterIP
    ports:
      tcp: 9000
      http: 8123

  resources:
    limits:
      cpu: 2000m
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 2Gi
```

### Kafka 配置

```yaml
kafka:
  enabled: true

  external:
    brokers: []  # ["kafka-1:9092", "kafka-2:9092"]

  replicaCount: 1

  persistence:
    enabled: true
    size: 10Gi

  service:
    type: ClusterIP
    port: 9092

  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi

  # Zookeeper 配置
  zookeeper:
    enabled: true
    replicaCount: 1
    persistence:
      enabled: true
      size: 2Gi
```

### Fluent-bit 配置

```yaml
fluentbit:
  enabled: true

  image:
    repository: fluent/fluent-bit
    tag: "2.2.0"

  # 集群名称（用于日志标识）
  clusterName: "kubernetes-cluster"

  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
```

## 常见操作

### 查看部署状态

```bash
# 查看所有 Pod
kubectl get pods -n clickvisual

# 查看服务
kubectl get svc -n clickvisual

# 查看持久化卷
kubectl get pvc -n clickvisual

# 查看日志
kubectl logs -n clickvisual deployment/clickvisual-stack-clickvisual
```

### 访问 ClickVisual

#### 方式 1: 端口转发（开发/测试）

```bash
kubectl port-forward -n clickvisual svc/clickvisual-stack-clickvisual 19001:19001
# 访问 http://localhost:19001
```

#### 方式 2: NodePort（内网访问）

```bash
# 修改 service type
helm upgrade clickvisual-stack ./clickvisual-stack \
  --namespace clickvisual \
  --set clickvisual.service.type=NodePort \
  --reuse-values
```

#### 方式 3: Ingress（生产推荐）

```bash
# 启用 Ingress
helm upgrade clickvisual-stack ./clickvisual-stack \
  --namespace clickvisual \
  --set clickvisual.ingress.enabled=true \
  --set clickvisual.ingress.hosts[0].host=clickvisual.example.com \
  --reuse-values
```

### 升级部署

```bash
# 升级到新版本
helm upgrade clickvisual-stack ./clickvisual-stack \
  --namespace clickvisual \
  --set clickvisual.image.tag=v1.2.0 \
  --reuse-values
```

### 扩容 ClickVisual

```bash
# 增加副本数
helm upgrade clickvisual-stack ./clickvisual-stack \
  --namespace clickvisual \
  --set clickvisual.replicaCount=3 \
  --set clickvisual.config.isMultiCopy=true \
  --set redis.enabled=true \
  --reuse-values
```

### 备份与恢复

#### 备份 MySQL

```bash
# 导出数据
kubectl exec -n clickvisual clickvisual-stack-mysql-0 -- \
  mysqldump -uroot -pshimo clickvisual > backup.sql
```

#### 恢复 MySQL

```bash
# 导入数据
kubectl exec -i -n clickvisual clickvisual-stack-mysql-0 -- \
  mysql -uroot -pshimo clickvisual < backup.sql
```

### 卸载

```bash
# 删除部署（保留 PVC）
helm uninstall clickvisual-stack -n clickvisual

# 删除 PVC（数据将丢失！）
kubectl delete pvc -n clickvisual -l app.kubernetes.io/instance=clickvisual-stack

# 删除命名空间
kubectl delete namespace clickvisual
```

## 故障排查

### Pod 一直处于 Pending 状态

检查 PVC 状态：
```bash
kubectl get pvc -n clickvisual
kubectl describe pvc -n clickvisual <pvc-name>
```

可能原因：
- 没有可用的 StorageClass
- 存储空间不足

解决方案：
```bash
# 使用指定的 StorageClass
helm upgrade clickvisual-stack ./clickvisual-stack \
  --namespace clickvisual \
  --set global.storageClass=your-storage-class \
  --reuse-values
```

### ClickVisual 无法连接数据库

检查 Pod 日志：
```bash
kubectl logs -n clickvisual deployment/clickvisual-stack-clickvisual
```

检查数据库连接：
```bash
# 测试 MySQL 连接
kubectl exec -it -n clickvisual clickvisual-stack-mysql-0 -- mysql -uroot -pshimo

# 测试 ClickHouse 连接
kubectl exec -it -n clickvisual clickvisual-stack-clickhouse-0 -- clickhouse-client
```

### Fluent-bit 无法发送日志

检查 Kafka 状态：
```bash
kubectl logs -n clickvisual daemonset/clickvisual-stack-fluentbit
kubectl exec -it -n clickvisual clickvisual-stack-kafka-0 -- kafka-topics.sh --list --bootstrap-server localhost:9092
```

### 内存不足（OOMKilled）

增加资源限制：
```bash
helm upgrade clickvisual-stack ./clickvisual-stack \
  --namespace clickvisual \
  --set clickhouse.resources.limits.memory=8Gi \
  --reuse-values
```

## 生产环境建议

### 1. 修改默认密码

```yaml
mysql:
  auth:
    rootPassword: "your-strong-password"

clickhouse:
  auth:
    password: "your-strong-password"

redis:
  auth:
    enabled: true
    password: "your-strong-password"

clickvisual:
  config:
    secretKey: "your-random-secret-key-32-chars"
```

### 2. 启用持久化存储

确保所有组件都启用了持久化：

```yaml
mysql.primary.persistence.enabled: true
redis.master.persistence.enabled: true
clickhouse.persistence.enabled: true
kafka.persistence.enabled: true
```

### 3. 配置资源限制

根据实际负载调整：

```yaml
clickvisual:
  replicaCount: 3
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi

clickhouse:
  replicaCount: 3
  resources:
    limits:
      cpu: 4000m
      memory: 8Gi
```

### 4. 启用 Ingress + TLS

```yaml
clickvisual:
  ingress:
    enabled: true
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hosts:
      - host: clickvisual.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: clickvisual-tls
        hosts:
          - clickvisual.yourdomain.com
```

### 5. 配置高可用

```yaml
# ClickVisual 多副本 + Redis
clickvisual:
  replicaCount: 3
  config:
    isMultiCopy: true

redis:
  enabled: true

# ClickHouse 集群
clickhouse:
  shards: 3
  replicaCount: 2

# Kafka 集群
kafka:
  replicaCount: 3
  zookeeper:
    replicaCount: 3
```

## 监控和告警

启用 Prometheus 监控：

```yaml
prometheus:
  enabled: true
  server:
    retention: "15d"
    persistence:
      enabled: true
      size: 20Gi

  alertmanager:
    enabled: true
```

## 性能优化

### ClickHouse 优化

```yaml
clickhouse:
  resources:
    limits:
      cpu: 8000m
      memory: 16Gi
  persistence:
    size: 100Gi
```

### Kafka 优化

```yaml
kafka:
  resources:
    limits:
      cpu: 2000m
      memory: 4Gi
  persistence:
    size: 50Gi
```

## 更多信息

- [ClickVisual 官方文档](https://clickvisual.net)
- [GitHub 仓库](https://github.com/clickvisual/clickvisual)
- [问题反馈](https://github.com/clickvisual/clickvisual/issues)

## 许可证

本 Helm Chart 遵循 ClickVisual 项目的许可证。
