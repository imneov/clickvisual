# ClickVisual Stack 快速开始

## 5 分钟快速部署

### 步骤 1: 克隆仓库

```bash
git clone https://github.com/clickvisual/clickvisual.git
cd clickvisual/data/helm/clickvisual-stack
```

### 步骤 2: 一键安装

```bash
# 使用安装脚本（推荐）
./install.sh

# 或使用 Helm 命令
helm install clickvisual-stack . --namespace clickvisual --create-namespace --wait
```

### 步骤 3: 访问 ClickVisual

```bash
# 端口转发
kubectl port-forward -n clickvisual svc/clickvisual-stack-clickvisual 19001:19001

# 打开浏览器访问 http://localhost:19001
# 默认账号: clickvisual / clickvisual
```

## 不同场景的部署

### 场景 1: 开发环境（最小资源）

```bash
./install.sh --mode minimal
```

或

```bash
helm install clickvisual-stack . \
  --namespace clickvisual \
  --create-namespace \
  -f examples/minimal-values.yaml
```

**资源需求**: ~4GB RAM, ~15GB 存储

### 场景 2: 生产环境（高可用）

```bash
./install.sh --mode production
```

或

```bash
helm install clickvisual-stack . \
  --namespace production \
  --create-namespace \
  -f examples/production-values.yaml
```

**资源需求**: ~32GB RAM, ~400GB 存储

⚠️ **重要**: 修改 `examples/production-values.yaml` 中的密码！

### 场景 3: 使用现有数据库

如果你已有 MySQL、Redis、ClickHouse，可以只部署 ClickVisual 应用：

```bash
# 1. 复制并修改配置
cp examples/external-services-values.yaml my-config.yaml

# 2. 编辑 my-config.yaml，填写你的数据库连接信息
vim my-config.yaml

# 3. 部署
helm install clickvisual-stack . \
  --namespace clickvisual \
  --create-namespace \
  -f my-config.yaml
```

## 验证部署

### 检查所有 Pod 运行状态

```bash
kubectl get pods -n clickvisual
```

期望输出（完整部署）：
```
NAME                                      READY   STATUS    RESTARTS   AGE
clickvisual-stack-clickhouse-0           1/1     Running   0          2m
clickvisual-stack-clickvisual-xxx-xxx    1/1     Running   0          2m
clickvisual-stack-kafka-0                 1/1     Running   0          2m
clickvisual-stack-mysql-0                 1/1     Running   0          2m
clickvisual-stack-redis-0                 1/1     Running   0          2m
clickvisual-stack-zookeeper-0             1/1     Running   0          2m
clickvisual-stack-fluentbit-xxx           1/1     Running   0          2m
```

### 查看服务

```bash
kubectl get svc -n clickvisual
```

### 查看持久化卷

```bash
kubectl get pvc -n clickvisual
```

## 常见问题

### Q: Pod 一直 Pending？

A: 检查存储类：

```bash
# 查看可用的 StorageClass
kubectl get storageclass

# 如果没有默认 SC，指定一个
helm upgrade clickvisual-stack . \
  --namespace clickvisual \
  --set global.storageClass=your-storage-class \
  --reuse-values
```

### Q: 如何访问数据库？

```bash
# MySQL
kubectl exec -it -n clickvisual clickvisual-stack-mysql-0 -- \
  mysql -uroot -pshimo

# ClickHouse
kubectl exec -it -n clickvisual clickvisual-stack-clickhouse-0 -- \
  clickhouse-client -u root --password shimo

# Redis
kubectl exec -it -n clickvisual clickvisual-stack-redis-0 -- \
  redis-cli
```

### Q: 如何查看日志？

```bash
# ClickVisual 应用日志
kubectl logs -n clickvisual deployment/clickvisual-stack-clickvisual

# Fluent-bit 日志
kubectl logs -n clickvisual daemonset/clickvisual-stack-fluentbit

# 所有组件日志
kubectl logs -n clickvisual -l app.kubernetes.io/instance=clickvisual-stack
```

### Q: 如何升级？

```bash
# 升级到新版本
helm upgrade clickvisual-stack . \
  --namespace clickvisual \
  --set clickvisual.image.tag=v1.2.0 \
  --reuse-values
```

### Q: 如何卸载？

```bash
# 卸载（保留数据）
helm uninstall clickvisual-stack -n clickvisual

# 删除所有数据（谨慎！）
kubectl delete pvc -n clickvisual -l app.kubernetes.io/instance=clickvisual-stack

# 删除命名空间
kubectl delete namespace clickvisual
```

## 下一步

- 📚 阅读完整文档: [README.md](README.md)
- 🔧 自定义配置: 编辑 [values.yaml](values.yaml)
- 📋 生产部署: 参考 [examples/production-values.yaml](examples/production-values.yaml)
- 🌐 访问官网: https://clickvisual.net
- 💬 加入社区: https://github.com/clickvisual/clickvisual

## 获取帮助

```bash
# 查看 Helm 部署信息
helm status clickvisual-stack -n clickvisual

# 查看部署后的说明
helm get notes clickvisual-stack -n clickvisual

# 查看所有配置值
helm get values clickvisual-stack -n clickvisual
```

祝使用愉快! 🚀
