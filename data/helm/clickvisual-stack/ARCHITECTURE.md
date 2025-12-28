# ClickVisual Stack Helm Chart 架构文档

## 架构概述

这个 Helm Chart 部署了一个**完整的微服务架构**，每个组件都是**独立的 Kubernetes 资源**。

## 重要说明

⚠️ **这不是一个 Pod 里的多个容器！**

每个服务都有：
- ✅ 独立的 Deployment/StatefulSet/DaemonSet
- ✅ 独立的 Service
- ✅ 独立的 PVC (需要持久化的服务)
- ✅ 独立的 ConfigMap (需要配置的服务)

## 部署的资源清单

### 1. MySQL 数据库

**资源类型**: StatefulSet
**文件**: `templates/mysql-statefulset.yaml`

```yaml
StatefulSet:  clickvisual-stack-mysql
  └─ Pod:     clickvisual-stack-mysql-0
      └─ Container: mysql:5.7.37
      └─ PVC: data-clickvisual-stack-mysql-0 (8Gi)

Service:      clickvisual-stack-mysql
  └─ Type:    ClusterIP
  └─ Port:    3306

ConfigMap:    clickvisual-stack-mysql-initdb
```

**作用**: 存储 ClickVisual 的元数据（用户、配置、权限等）

---

### 2. Redis 缓存

**资源类型**: StatefulSet
**文件**: `templates/redis-statefulset.yaml`

```yaml
StatefulSet:  clickvisual-stack-redis
  └─ Pod:     clickvisual-stack-redis-0
      └─ Container: redis:7.0-alpine
      └─ PVC: data-clickvisual-stack-redis-0 (2Gi)

Service:      clickvisual-stack-redis-master
  └─ Type:    ClusterIP
  └─ Port:    6379
```

**作用**:
- 会话存储（多副本模式）
- 缓存加速

---

### 3. ClickHouse 日志数据库

**资源类型**: StatefulSet
**文件**: `templates/clickhouse-statefulset.yaml`

```yaml
StatefulSet:  clickvisual-stack-clickhouse
  └─ Pod:     clickvisual-stack-clickhouse-0
      └─ Container: clickhouse/clickhouse-server:23.4.1
      └─ PVC: data-clickvisual-stack-clickhouse-0 (20Gi)

Service:      clickvisual-stack-clickhouse
  └─ Type:    ClusterIP
  └─ Ports:   9000 (Native), 8123 (HTTP)

ConfigMap:    clickvisual-stack-clickhouse-config
```

**作用**: 存储和查询海量日志数据

---

### 4. Zookeeper 协调服务

**资源类型**: StatefulSet
**文件**: `templates/kafka-statefulset.yaml`

```yaml
StatefulSet:  clickvisual-stack-zookeeper
  └─ Pod:     clickvisual-stack-zookeeper-0
      └─ Container: zookeeper:3.8
      └─ PVC:
          - data-clickvisual-stack-zookeeper-0 (2Gi)
          - datalog-clickvisual-stack-zookeeper-0 (1Gi)

Service:      clickvisual-stack-zookeeper
  └─ Type:    ClusterIP
  └─ Ports:   2181 (Client), 2888 (Follower), 3888 (Election)
```

**作用**: Kafka 的元数据协调和领导者选举

---

### 5. Kafka 消息队列

**资源类型**: StatefulSet
**文件**: `templates/kafka-statefulset.yaml`

```yaml
StatefulSet:  clickvisual-stack-kafka
  └─ Pod:     clickvisual-stack-kafka-0
      └─ Container: bitnami/kafka:3.6
      └─ PVC: data-clickvisual-stack-kafka-0 (10Gi)

Service:      clickvisual-stack-kafka
  └─ Type:    ClusterIP
  └─ Port:    9092
```

**作用**: 日志数据的消息队列缓冲

**数据流**: Fluent-bit → Kafka → ClickHouse (由 ClickVisual 消费)

---

### 6. ClickVisual Web 应用

**资源类型**: Deployment
**文件**: `templates/clickvisual-deployment.yaml`

```yaml
Deployment:   clickvisual-stack-clickvisual
  └─ ReplicaSet: clickvisual-stack-clickvisual-xxxxxxxxx
      └─ Pod(s): clickvisual-stack-clickvisual-xxxxxxxxx-xxxxx
          └─ Container: clickvisual/clickvisual:latest
          └─ InitContainers:
              - wait-for-mysql (确保 MySQL 就绪)
              - wait-for-clickhouse (确保 ClickHouse 就绪)

Service:      clickvisual-stack-clickvisual
  └─ Type:    ClusterIP
  └─ Ports:   19001 (HTTP), 19011 (Governor)

ConfigMap:    clickvisual-stack-clickvisual-config
  └─ 包含:    default.toml (应用配置)
```

**作用**: 日志查询和分析的 Web 界面

**特性**:
- 支持多副本 (replicaCount)
- InitContainers 确保依赖就绪
- 配置通过 ConfigMap 注入

---

### 7. Fluent-bit 日志采集器

**资源类型**: DaemonSet
**文件**: `templates/fluentbit-daemonset.yaml`

```yaml
DaemonSet:    clickvisual-stack-fluentbit
  └─ Pod(s):  每个节点一个 Pod
      └─ Container: fluent/fluent-bit:2.2.0

ServiceAccount:     clickvisual-stack-fluentbit
ClusterRole:        clickvisual-stack-fluentbit
ClusterRoleBinding: clickvisual-stack-fluentbit

ConfigMap:          clickvisual-stack-fluentbit-config
  └─ 包含:
      - fluent-bit.conf
      - input-kubernetes.conf
      - filter-kubernetes.conf
      - output-kafka.conf
      - parsers.conf
```

**作用**: 采集每个节点上的容器日志

**RBAC 权限**:
- 读取 Pods、Nodes、Namespaces 信息
- 访问容器日志文件

**HostPath 挂载**:
- `/var/log` (日志目录)
- `/var/lib/docker/containers` (容器日志)

---

### 8. Ingress (可选)

**资源类型**: Ingress
**文件**: `templates/ingress.yaml`

```yaml
Ingress:      clickvisual-stack-clickvisual
  └─ Rules:   根据配置的 hosts
  └─ Backend: clickvisual-stack-clickvisual:19001
```

**作用**: 对外暴露 ClickVisual Web 界面

**启用条件**: `clickvisual.ingress.enabled: true`

---

## 资源统计

| 资源类型 | 数量 | 组件 |
|---------|------|------|
| **StatefulSet** | 5 | MySQL, Redis, ClickHouse, Kafka, Zookeeper |
| **Deployment** | 1 | ClickVisual |
| **DaemonSet** | 1 | Fluent-bit |
| **Service** | 6 | 每个应用独立的服务 |
| **ConfigMap** | 4 | 配置文件 |
| **PVC** | 7 | 持久化存储 |
| **Ingress** | 0-1 | 可选 |
| **RBAC** | 3 | ServiceAccount, ClusterRole, ClusterRoleBinding |

## 网络拓扑

```
┌──────────────────────────────────────────────────────────────┐
│                        外部用户                               │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
              ┌─────────────┐
              │   Ingress   │ (可选)
              └──────┬──────┘
                     │
                     ▼
        ┌────────────────────────────┐
        │  ClickVisual Service       │
        │  (ClusterIP:19001)         │
        └────────────┬───────────────┘
                     │
                     ▼
        ┌────────────────────────────┐
        │  ClickVisual Deployment    │
        │  ┌─────────────────────┐   │
        │  │ Pod 1               │   │
        │  │ Pod 2 (可选)        │   │
        │  │ Pod 3 (可选)        │   │
        │  └─────────────────────┘   │
        └──┬──┬──┬────────────────┬──┘
           │  │  │                │
    ┌──────┘  │  │                └────────┐
    │         │  │                         │
    ▼         ▼  ▼                         ▼
┌────────┐ ┌────────┐ ┌────────────┐ ┌──────────┐
│ MySQL  │ │ Redis  │ │ ClickHouse │ │  Kafka   │
│ Svc    │ │ Svc    │ │    Svc     │ │   Svc    │
└───┬────┘ └───┬────┘ └─────┬──────┘ └────┬─────┘
    │          │            │              │
    ▼          ▼            ▼              ▼
┌────────┐ ┌────────┐ ┌────────────┐ ┌──────────┐
│ MySQL  │ │ Redis  │ │ ClickHouse │ │  Kafka   │
│  Pod   │ │  Pod   │ │    Pod     │ │   Pod    │
│   0    │ │   0    │ │     0      │ │    0     │
└────────┘ └────────┘ └────────────┘ └────┬─────┘
                                           │
                                           │ 依赖
                                           ▼
                                    ┌──────────────┐
                                    │  Zookeeper   │
                                    │  Service     │
                                    └──────┬───────┘
                                           │
                                           ▼
                                    ┌──────────────┐
                                    │  Zookeeper   │
                                    │    Pod 0     │
                                    └──────────────┘

┌─────────────────────────────────────────────────────────────┐
│           Fluent-bit DaemonSet (每个节点)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ Node 1   │  │ Node 2   │  │ Node 3   │                  │
│  │ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │                  │
│  │ │ Pod  │ │  │ │ Pod  │ │  │ │ Pod  │ │                  │
│  │ └──┬───┘ │  │ └──┬───┘ │  │ └──┬───┘ │                  │
│  └────┼─────┘  └────┼─────┘  └────┼─────┘                  │
└───────┼─────────────┼─────────────┼────────────────────────┘
        │             │             │
        └─────────────┴─────────────┴────────► Kafka Service
```

## 数据流

### 日志采集流程

```
容器日志文件
    │
    ▼
/var/log/containers/*.log
    │
    ▼
Fluent-bit (DaemonSet)
    │ (采集、解析、过滤)
    ▼
Kafka (消息队列)
    │
    ▼
ClickVisual (消费 Kafka)
    │
    ▼
ClickHouse (存储)
    │
    ▼
ClickVisual Web (查询展示)
```

### 元数据流程

```
用户操作 (Web UI)
    │
    ▼
ClickVisual
    │
    ├──► MySQL (用户、权限、配置)
    ├──► Redis (会话、缓存)
    └──► ClickHouse (日志查询)
```

## Pod 间通信

所有通信都通过 **Kubernetes Service** 进行：

| 源 | 目标 | Service 名称 | 端口 |
|----|------|-------------|------|
| ClickVisual | MySQL | clickvisual-stack-mysql | 3306 |
| ClickVisual | Redis | clickvisual-stack-redis-master | 6379 |
| ClickVisual | ClickHouse | clickvisual-stack-clickhouse | 9000/8123 |
| ClickVisual | Kafka | clickvisual-stack-kafka | 9092 |
| Fluent-bit | Kafka | clickvisual-stack-kafka | 9092 |
| Kafka | Zookeeper | clickvisual-stack-zookeeper | 2181 |

## 存储架构

### StatefulSet 持久化存储

每个 StatefulSet 的 Pod 都有独立的 PVC：

```
MySQL StatefulSet
└─ clickvisual-stack-mysql-0
    └─ data-clickvisual-stack-mysql-0 (8Gi)
        └─ /var/lib/mysql

Redis StatefulSet
└─ clickvisual-stack-redis-0
    └─ data-clickvisual-stack-redis-0 (2Gi)
        └─ /data

ClickHouse StatefulSet
└─ clickvisual-stack-clickhouse-0
    └─ data-clickvisual-stack-clickhouse-0 (20Gi)
        └─ /var/lib/clickhouse

Zookeeper StatefulSet
└─ clickvisual-stack-zookeeper-0
    ├─ data-clickvisual-stack-zookeeper-0 (2Gi)
    │   └─ /data
    └─ datalog-clickvisual-stack-zookeeper-0 (1Gi)
        └─ /datalog

Kafka StatefulSet
└─ clickvisual-stack-kafka-0
    └─ data-clickvisual-stack-kafka-0 (10Gi)
        └─ /bitnami/kafka
```

### 总存储需求

| 组件 | PVC 大小 | 可配置 |
|------|---------|--------|
| MySQL | 8Gi | ✅ `mysql.primary.persistence.size` |
| Redis | 2Gi | ✅ `redis.master.persistence.size` |
| ClickHouse | 20Gi | ✅ `clickhouse.persistence.size` |
| Zookeeper | 3Gi (2+1) | ✅ `kafka.zookeeper.persistence.size` |
| Kafka | 10Gi | ✅ `kafka.persistence.size` |
| **总计** | **43Gi** | |

## 配置管理

### ConfigMap 使用

| ConfigMap | 用途 | 挂载到 |
|-----------|------|--------|
| clickvisual-stack-clickvisual-config | ClickVisual 应用配置 (TOML) | `/clickvisual/configs` |
| clickvisual-stack-clickhouse-config | ClickHouse 用户配置 (XML) | `/etc/clickhouse-server/users.d/` |
| clickvisual-stack-fluentbit-config | Fluent-bit 采集配置 | `/fluent-bit/etc/` |
| clickvisual-stack-mysql-initdb | MySQL 初始化 SQL | `/docker-entrypoint-initdb.d` |

## 扩展性

### 支持扩展的组件

| 组件 | 扩展类型 | 配置参数 |
|------|---------|---------|
| **ClickVisual** | 水平扩展 | `clickvisual.replicaCount` |
| **ClickHouse** | 分片+副本 | `clickhouse.shards`, `clickhouse.replicaCount` |
| **Kafka** | 水平扩展 | `kafka.replicaCount` |
| **Zookeeper** | 水平扩展 | `kafka.zookeeper.replicaCount` |

### 扩展示例

```yaml
# 3 副本 ClickVisual (需要 Redis)
clickvisual:
  replicaCount: 3
  config:
    isMultiCopy: true

# ClickHouse 集群 (3 shards × 2 replicas)
clickhouse:
  shards: 3
  replicaCount: 2

# Kafka 集群
kafka:
  replicaCount: 3
  zookeeper:
    replicaCount: 3
```

## 高可用架构

完整的高可用配置示例请参考 `examples/production-values.yaml`

---

## 总结

这个 Helm Chart 部署的是一个**标准的 Kubernetes 微服务架构**：

✅ 每个服务独立的 Deployment/StatefulSet
✅ 每个服务独立的 Service
✅ 每个服务独立的持久化存储
✅ 通过 Kubernetes Service 进行服务发现
✅ 支持独立扩展和升级
✅ 遵循 Kubernetes 最佳实践

**这不是一个 Pod 里跑多个容器的方案！**
