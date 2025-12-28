# ClickVisual Stack Helm Chart - 项目总结

## 项目概述

这是一个为 ClickVisual 项目创建的完整 Helm Chart，支持**一键部署所有依赖服务**。

### 设计理念

**智能依赖管理** - 根据 `values.yaml` 配置自动决定是部署内部服务还是连接外部服务。

## 核心特性

### 1. 两种部署模式

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| **独立模式** | 自动部署所有依赖 | 新项目、POC、测试环境 |
| **外部模式** | 使用已有服务 | 生产环境、已有基础设施 |

### 2. 智能配置生成

通过 `_helpers.tpl` 中的模板函数，自动生成：
- MySQL DSN 连接串
- Redis 地址
- ClickHouse 连接信息
- Kafka Brokers 列表

**示例**:
```yaml
# 用户只需配置
mysql:
  enabled: true
  auth:
    rootPassword: "password"

# Chart 自动生成 DSN
# root:password@tcp(clickvisual-stack-mysql:3306)/clickvisual?...
```

### 3. 组件列表

| 组件 | 作用 | 默认状态 | 可选 |
|------|------|---------|------|
| ClickVisual | 日志分析应用 | ✅ 启用 | ❌ |
| MySQL | 元数据存储 | ✅ 启用 | ✅ |
| Redis | 会话缓存 | ✅ 启用 | ✅ |
| ClickHouse | 日志数据库 | ✅ 启用 | ✅ |
| Kafka | 消息队列 | ✅ 启用 | ✅ |
| Zookeeper | Kafka 依赖 | ✅ 启用 | ✅ |
| Fluent-bit | 日志采集 | ✅ 启用 | ✅ |
| Prometheus | 监控 | ❌ 禁用 | ✅ |

## 文件结构

```
clickvisual-stack/
├── Chart.yaml                              # Chart 元数据
├── values.yaml                             # 默认配置（完整部署）
├── .helmignore                             # Helm 忽略文件
├── README.md                               # 完整文档
├── QUICKSTART.md                           # 快速开始
├── CHANGELOG.md                            # 变更日志
├── install.sh                              # 安装脚本
├── templates/
│   ├── _helpers.tpl                        # 模板函数
│   ├── NOTES.txt                           # 部署后提示
│   ├── clickvisual-deployment.yaml         # ClickVisual 部署
│   ├── mysql-statefulset.yaml              # MySQL StatefulSet
│   ├── redis-statefulset.yaml              # Redis StatefulSet
│   ├── clickhouse-statefulset.yaml         # ClickHouse StatefulSet
│   ├── kafka-statefulset.yaml              # Kafka + Zookeeper
│   ├── fluentbit-daemonset.yaml            # Fluent-bit DaemonSet
│   └── ingress.yaml                        # Ingress 配置
└── examples/
    ├── minimal-values.yaml                 # 最小化配置
    ├── production-values.yaml              # 生产环境配置
    └── external-services-values.yaml       # 外部服务配置
```

## 使用示例

### 示例 1: 完整独立部署

```bash
helm install clickvisual-stack . --namespace clickvisual --create-namespace
```

部署内容：
- ✅ MySQL (StatefulSet, 8Gi PVC)
- ✅ Redis (StatefulSet, 2Gi PVC)
- ✅ ClickHouse (StatefulSet, 20Gi PVC)
- ✅ Kafka + Zookeeper (StatefulSet, 10Gi + 2Gi PVC)
- ✅ ClickVisual (Deployment)
- ✅ Fluent-bit (DaemonSet)

### 示例 2: 使用外部 MySQL

```bash
helm install clickvisual-stack . \
  --set mysql.enabled=false \
  --set mysql.external.host=mysql.example.com \
  --set mysql.external.password=xxx \
  --namespace clickvisual
```

部署内容：
- ❌ MySQL (使用外部)
- ✅ Redis, ClickHouse, Kafka, ClickVisual, Fluent-bit

### 示例 3: 最小化部署

```bash
helm install clickvisual-stack . \
  -f examples/minimal-values.yaml \
  --namespace clickvisual
```

资源需求：~4GB RAM, ~15GB 存储

### 示例 4: 生产环境

```bash
helm install clickvisual-stack . \
  -f examples/production-values.yaml \
  --namespace production
```

特性：
- 3 副本 ClickVisual
- 3 副本 ClickHouse (3 shards × 2 replicas)
- 3 副本 Kafka + Zookeeper
- Ingress + TLS
- 高可用配置

## 技术亮点

### 1. 条件渲染

所有组件都支持条件部署：

```yaml
{{- if .Values.mysql.enabled }}
# 部署内部 MySQL
{{- end }}
```

### 2. 动态连接串生成

通过 `_helpers.tpl` 自动生成：

```go
{{- define "clickvisual-stack.mysql.dsn" -}}
{{- $host := include "clickvisual-stack.mysql.host" . -}}
{{- $port := include "clickvisual-stack.mysql.port" . -}}
{{- printf "%s:%s@tcp(%s:%v)/%s?..." $user $pass $host $port $db }}
{{- end -}}
```

### 3. Init Containers

确保依赖服务就绪：

```yaml
initContainers:
  - name: wait-for-mysql
    image: busybox
    command: ['sh', '-c', 'until nc -z mysql 3306; do sleep 2; done']
```

### 4. ConfigMap 配置注入

将 TOML 配置通过 ConfigMap 挂载：

```yaml
volumes:
  - name: config
    configMap:
      name: clickvisual-stack-clickvisual-config
volumeMounts:
  - name: config
    mountPath: /clickvisual/configs
```

### 5. RBAC 支持

为 Fluent-bit 配置正确的权限：

```yaml
kind: ClusterRole
rules:
  - apiGroups: [""]
    resources: ["namespaces", "pods", "nodes"]
    verbs: ["get", "list", "watch"]
```

## 配置示例

### 场景 1: 只使用内部服务

```yaml
mysql:
  enabled: true
redis:
  enabled: true
clickhouse:
  enabled: true
kafka:
  enabled: true
```

### 场景 2: 全部使用外部服务

```yaml
mysql:
  enabled: false
  external:
    host: "external-mysql.com"
    password: "xxx"

redis:
  enabled: false
  external:
    host: "external-redis.com"

# ... 其他服务类似
```

### 场景 3: 混合模式

```yaml
mysql:
  enabled: false  # 使用外部 MySQL
  external:
    host: "prod-mysql.com"

redis:
  enabled: true   # 使用内部 Redis

clickhouse:
  enabled: true   # 使用内部 ClickHouse
```

## 资源需求

### 最小配置 (minimal-values.yaml)
- CPU: ~3 cores
- Memory: ~4GB
- Storage: ~15GB

### 默认配置 (values.yaml)
- CPU: ~8 cores
- Memory: ~12GB
- Storage: ~50GB

### 生产配置 (production-values.yaml)
- CPU: ~32 cores
- Memory: ~40GB
- Storage: ~400GB

## 部署流程

1. **安装 Helm Chart**
   ```bash
   helm install clickvisual-stack .
   ```

2. **Chart 解析 values**
   - 检查 `mysql.enabled`
   - 检查 `redis.enabled`
   - 等等...

3. **条件渲染模板**
   - 如果 `enabled: true` → 渲染 StatefulSet
   - 如果 `enabled: false` → 跳过，使用 external 配置

4. **生成连接配置**
   - 调用 `_helpers.tpl` 函数
   - 生成 DSN/地址/Brokers

5. **应用到集群**
   - 创建 StatefulSet/Deployment
   - 创建 Service
   - 创建 ConfigMap
   - 创建 PVC

6. **Init Containers 检查**
   - 等待 MySQL 就绪
   - 等待 ClickHouse 就绪

7. **启动 ClickVisual**
   - 读取 ConfigMap 配置
   - 连接数据库
   - 启动服务

## 验证和测试

### 验证 Chart 语法

```bash
helm lint .
# 输出: 1 chart(s) linted, 0 chart(s) failed
```

### 模拟安装（不实际部署）

```bash
helm install --dry-run --debug clickvisual-stack .
```

### 查看渲染结果

```bash
helm template clickvisual-stack .
```

## 维护和升级

### 升级到新版本

```bash
helm upgrade clickvisual-stack . \
  --set clickvisual.image.tag=v1.2.0 \
  --reuse-values
```

### 修改配置

```bash
helm upgrade clickvisual-stack . \
  --set clickhouse.resources.limits.memory=8Gi \
  --reuse-values
```

### 回滚

```bash
helm rollback clickvisual-stack 1
```

## 最佳实践

### 1. 生产环境

- ✅ 使用固定镜像标签（不用 `latest`）
- ✅ 启用持久化存储
- ✅ 配置资源限制
- ✅ 修改默认密码
- ✅ 启用 Ingress + TLS
- ✅ 配置备份策略
- ✅ 监控和告警

### 2. 开发环境

- ✅ 使用 minimal-values.yaml
- ✅ 可以禁用持久化（加快测试）
- ✅ 使用默认密码（简化配置）

### 3. 安全建议

```yaml
# 修改所有默认密码
mysql.auth.rootPassword: "strong-password-123"
redis.auth.password: "strong-password-456"
clickhouse.auth.password: "strong-password-789"
clickvisual.config.secretKey: "random-32-char-secret-key"
```

## 故障排查

### Pod Pending

```bash
kubectl describe pod <pod-name> -n clickvisual
# 检查 Events 部分
```

常见原因：
- 没有 StorageClass
- 存储空间不足
- 资源不足

### 连接失败

```bash
kubectl logs deployment/clickvisual-stack-clickvisual -n clickvisual
# 查看连接错误
```

检查：
- Service 是否创建
- DNS 解析是否正常
- 密码是否正确

## 未来改进

- [ ] 添加 Prometheus ServiceMonitor
- [ ] 支持自定义 Fluent-bit 配置
- [ ] 添加备份 CronJob
- [ ] 支持多集群部署
- [ ] 添加自动扩缩容（HPA）
- [ ] 集成 Cert-Manager
- [ ] 添加更多的健康检查

## 总结

这个 Helm Chart 实现了：

1. ✅ **智能依赖管理** - 自动检测并部署所需服务
2. ✅ **灵活配置** - 支持完全独立或使用外部服务
3. ✅ **开箱即用** - 默认配置即可快速启动
4. ✅ **生产就绪** - 包含高可用、监控、备份等配置
5. ✅ **易于维护** - 清晰的文档和示例

用户只需一条命令：
```bash
helm install clickvisual-stack . --namespace clickvisual --create-namespace
```

即可完成从数据库到应用的完整部署！

---

**作者**: Claude Code Assistant  
**创建日期**: 2025-12-27  
**版本**: 1.0.0
