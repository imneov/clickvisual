# ClickVisual Stack 故障排查指南

## 常见问题和解决方案

### 问题 1: Pod 一直处于 Pending 状态

#### 症状
```bash
kubectl get pods -n clickvisual
NAME                                    READY   STATUS    RESTARTS   AGE
clickvisual-stack-mysql-0               0/1     Pending   0          5m
```

#### 可能原因

1. **没有可用的 StorageClass**

```bash
# 检查 PVC 状态
kubectl get pvc -n clickvisual

# 查看详细信息
kubectl describe pvc <pvc-name> -n clickvisual
```

**解决方案**:
```bash
# 查看可用的 StorageClass
kubectl get storageclass

# 指定 StorageClass
helm upgrade clickvisual-stack . \
  --namespace clickvisual \
  --set global.storageClass=<your-storage-class> \
  --reuse-values
```

2. **存储空间不足**

检查节点磁盘空间：
```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,DISKPRESSURE:.status.conditions[?(@.type==\"DiskPressure\")].status
```

3. **资源不足 (CPU/内存)**

```bash
# 查看节点资源
kubectl top nodes

# 减少资源请求
helm upgrade clickvisual-stack . \
  --namespace clickvisual \
  --set clickhouse.resources.requests.memory=1Gi \
  --reuse-values
```

---

### 问题 2: Pod 一直处于 Init 状态

#### 症状
```bash
NAME                                    READY   STATUS     RESTARTS   AGE
clickvisual-stack-clickvisual-xxx       0/1     Init:0/2   0          5m
```

#### 原因
ClickVisual 的 InitContainer 在等待 MySQL 或 ClickHouse 就绪。

#### 检查依赖服务

```bash
# 检查 MySQL
kubectl get pod -n clickvisual clickvisual-stack-mysql-0
kubectl logs -n clickvisual clickvisual-stack-mysql-0

# 检查 ClickHouse
kubectl get pod -n clickvisual clickvisual-stack-clickhouse-0
kubectl logs -n clickvisual clickvisual-stack-clickhouse-0

# 查看 InitContainer 日志
kubectl logs -n clickvisual <clickvisual-pod-name> -c wait-for-mysql
kubectl logs -n clickvisual <clickvisual-pod-name> -c wait-for-clickhouse
```

#### 解决方案

1. **MySQL 未启动**
```bash
kubectl describe pod clickvisual-stack-mysql-0 -n clickvisual
# 查看 Events 部分的错误信息
```

2. **ClickHouse 未启动**
```bash
kubectl describe pod clickvisual-stack-clickhouse-0 -n clickvisual
```

3. **网络问题**
```bash
# 测试 Service DNS 解析
kubectl run -it --rm debug --image=busybox --restart=Never -n clickvisual -- nslookup clickvisual-stack-mysql
```

---

### 问题 3: Pod 启动后立即 CrashLoopBackOff

#### 症状
```bash
NAME                                    READY   STATUS             RESTARTS   AGE
clickvisual-stack-clickvisual-xxx       0/1     CrashLoopBackOff   5          10m
```

#### 检查日志

```bash
# 查看 Pod 日志
kubectl logs -n clickvisual <pod-name>

# 查看上一次崩溃的日志
kubectl logs -n clickvisual <pod-name> --previous
```

#### 常见原因

1. **配置错误**

```bash
# 检查 ConfigMap
kubectl get configmap clickvisual-stack-clickvisual-config -n clickvisual -o yaml

# 验证配置语法
kubectl exec -it <pod-name> -n clickvisual -- cat /clickvisual/configs/default.toml
```

2. **数据库连接失败**

检查连接信息：
```bash
# 查看生成的连接串
helm get values clickvisual-stack -n clickvisual

# 测试 MySQL 连接
kubectl run -it --rm mysql-client --image=mysql:5.7 --restart=Never -n clickvisual -- \
  mysql -h clickvisual-stack-mysql -uroot -pshimo
```

3. **权限问题**

```bash
# 检查 MySQL 数据库是否初始化
kubectl exec -it clickvisual-stack-mysql-0 -n clickvisual -- \
  mysql -uroot -pshimo -e "SHOW DATABASES;"

# 应该看到 clickvisual 数据库
```

---

### 问题 4: Pod 运行但无法访问

#### 症状
```bash
NAME                                    READY   STATUS    RESTARTS   AGE
clickvisual-stack-clickvisual-xxx       1/1     Running   0          10m

# 但是访问 http://localhost:19001 没有响应
```

#### 检查步骤

1. **检查 Service**

```bash
kubectl get svc -n clickvisual clickvisual-stack-clickvisual

# 应该看到
NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
clickvisual-stack-clickvisual    ClusterIP   10.x.x.x        <none>        19001/TCP,19011/TCP
```

2. **检查端口转发**

```bash
# 正确的端口转发命令
kubectl port-forward -n clickvisual svc/clickvisual-stack-clickvisual 19001:19001

# 在浏览器访问 http://localhost:19001
```

3. **检查容器端口**

```bash
# 进入容器检查
kubectl exec -it <clickvisual-pod-name> -n clickvisual -- sh

# 检查进程
ps aux | grep clickvisual

# 检查端口监听
netstat -tlnp | grep 19001
```

4. **检查防火墙/网络策略**

```bash
kubectl get networkpolicies -n clickvisual
```

---

### 问题 5: Fluent-bit 无法发送日志到 Kafka

#### 症状
```bash
# Fluent-bit Pod 运行正常，但 Kafka 没有收到日志
kubectl logs -n clickvisual daemonset/clickvisual-stack-fluentbit
```

#### 检查步骤

1. **检查 Kafka 状态**

```bash
kubectl get pod -n clickvisual clickvisual-stack-kafka-0
kubectl logs -n clickvisual clickvisual-stack-kafka-0
```

2. **检查 Zookeeper**

```bash
kubectl get pod -n clickvisual clickvisual-stack-zookeeper-0
kubectl logs -n clickvisual clickvisual-stack-zookeeper-0
```

3. **测试 Kafka 连接**

```bash
# 进入 Kafka Pod
kubectl exec -it clickvisual-stack-kafka-0 -n clickvisual -- bash

# 列出 topics
kafka-topics.sh --list --bootstrap-server localhost:9092

# 应该看到类似的 topic
# app-logs-kubernetes-cluster
```

4. **检查 Fluent-bit 配置**

```bash
kubectl get configmap clickvisual-stack-fluentbit-config -n clickvisual -o yaml
```

---

### 问题 6: StatefulSet Pod 重启后数据丢失

#### 原因
PVC 可能没有正确绑定

#### 检查

```bash
# 查看 PVC 状态
kubectl get pvc -n clickvisual

# 应该都是 Bound 状态
NAME                                        STATUS   VOLUME   CAPACITY
data-clickvisual-stack-mysql-0              Bound    pvc-xxx  8Gi
data-clickvisual-stack-redis-0              Bound    pvc-xxx  2Gi
data-clickvisual-stack-clickhouse-0         Bound    pvc-xxx  20Gi
```

#### 解决方案

```bash
# 检查 PV
kubectl get pv | grep clickvisual

# 如果 PVC 是 Pending，检查 StorageClass
kubectl describe pvc <pvc-name> -n clickvisual
```

---

### 问题 7: 内存不足 (OOMKilled)

#### 症状
```bash
kubectl get pods -n clickvisual
NAME                                    READY   STATUS      RESTARTS   AGE
clickvisual-stack-clickhouse-0          0/1     OOMKilled   3          10m
```

#### 解决方案

增加内存限制：

```bash
helm upgrade clickvisual-stack . \
  --namespace clickvisual \
  --set clickhouse.resources.limits.memory=8Gi \
  --set clickhouse.resources.requests.memory=4Gi \
  --reuse-values
```

或使用最小化配置：

```bash
helm upgrade clickvisual-stack . \
  --namespace clickvisual \
  -f examples/minimal-values.yaml \
  --reuse-values
```

---

### 问题 8: 镜像拉取失败

#### 症状
```bash
kubectl get pods -n clickvisual
NAME                                    READY   STATUS         RESTARTS   AGE
clickvisual-stack-clickvisual-xxx       0/1     ImagePullBackOff   0      5m
```

#### 检查

```bash
kubectl describe pod <pod-name> -n clickvisual
# 查看 Events 部分
```

#### 常见原因

1. **镜像不存在或标签错误**

```bash
# 检查使用的镜像
kubectl get deployment clickvisual-stack-clickvisual -n clickvisual -o yaml | grep image:

# 修改镜像标签
helm upgrade clickvisual-stack . \
  --namespace clickvisual \
  --set clickvisual.image.tag=v0.5.0 \
  --reuse-values
```

2. **网络问题**

```bash
# 在节点上手动拉取镜像测试
docker pull clickvisual/clickvisual:latest
```

3. **私有仓库认证**

```bash
# 创建 docker-registry secret
kubectl create secret docker-registry regcred \
  --docker-server=<your-registry> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n clickvisual

# 配置 imagePullSecrets
helm upgrade clickvisual-stack . \
  --namespace clickvisual \
  --set clickvisual.image.pullSecrets[0].name=regcred \
  --reuse-values
```

---

## 快速诊断命令

### 一键检查所有资源

```bash
#!/bin/bash
echo "=== Pods ==="
kubectl get pods -n clickvisual

echo -e "\n=== Services ==="
kubectl get svc -n clickvisual

echo -e "\n=== PVC ==="
kubectl get pvc -n clickvisual

echo -e "\n=== Events (最近 10 条) ==="
kubectl get events -n clickvisual --sort-by='.lastTimestamp' | tail -10

echo -e "\n=== 有问题的 Pods ==="
kubectl get pods -n clickvisual | grep -v Running | grep -v Completed
```

保存为 `check-status.sh` 并运行：

```bash
chmod +x check-status.sh
./check-status.sh
```

---

## 完整重置（谨慎使用）

如果需要完全重置部署：

```bash
# 1. 卸载 Helm Release
helm uninstall clickvisual-stack -n clickvisual

# 2. 删除所有 PVC（数据将丢失！）
kubectl delete pvc -n clickvisual -l app.kubernetes.io/instance=clickvisual-stack

# 3. 删除命名空间
kubectl delete namespace clickvisual

# 4. 重新安装
kubectl create namespace clickvisual
helm install clickvisual-stack . --namespace clickvisual
```

---

## 收集诊断信息

如果需要提交 Issue，请收集以下信息：

```bash
#!/bin/bash
# 收集诊断信息

OUTPUT_DIR="clickvisual-debug-$(date +%Y%m%d-%H%M%S)"
mkdir -p $OUTPUT_DIR

echo "收集诊断信息到 $OUTPUT_DIR ..."

# 1. Helm 信息
helm list -n clickvisual > $OUTPUT_DIR/helm-list.txt
helm get values clickvisual-stack -n clickvisual > $OUTPUT_DIR/helm-values.yaml
helm get manifest clickvisual-stack -n clickvisual > $OUTPUT_DIR/helm-manifest.yaml

# 2. K8S 资源
kubectl get all -n clickvisual -o wide > $OUTPUT_DIR/all-resources.txt
kubectl get pvc -n clickvisual -o yaml > $OUTPUT_DIR/pvc.yaml
kubectl get configmap -n clickvisual -o yaml > $OUTPUT_DIR/configmaps.yaml

# 3. Pod 详细信息
for pod in $(kubectl get pods -n clickvisual -o name); do
    name=$(basename $pod)
    kubectl describe $pod -n clickvisual > $OUTPUT_DIR/describe-$name.txt
    kubectl logs $pod -n clickvisual > $OUTPUT_DIR/logs-$name.txt 2>&1 || true
done

# 4. Events
kubectl get events -n clickvisual --sort-by='.lastTimestamp' > $OUTPUT_DIR/events.txt

echo "诊断信息已保存到 $OUTPUT_DIR"
echo "请将此目录打包并提供给支持团队"
tar czf $OUTPUT_DIR.tar.gz $OUTPUT_DIR
echo "已创建: $OUTPUT_DIR.tar.gz"
```

---

## 获取帮助

- GitHub Issues: https://github.com/clickvisual/clickvisual/issues
- 文档: https://clickvisual.net
- 社区: 参考 README.md 中的联系方式
