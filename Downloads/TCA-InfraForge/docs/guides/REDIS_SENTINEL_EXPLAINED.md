# 🍃 Redis Sentinel Explained - High Availability Caching Architecture

**Comprehensive guide to Redis Sentinel clustering for TCA InfraForge high availability**

## 🎯 What is Redis Sentinel?

Redis Sentinel is Redis's **high availability solution** that provides:
- ✅ **Automatic failover** when the master goes down
- ✅ **Configuration provider** for clients to discover the current master
- ✅ **Notification system** for administrators about cluster events
- ✅ **Monitoring** of Redis instances and detection of failures

Think of Sentinel as a **smart load balancer** that not only routes traffic but also **watches your Redis instances like a guardian** and takes action when problems occur.

## 🏗️ Redis Sentinel Architecture

### **High-Level Architecture**
```
┌─────────────────────────────────────────────────────────────────┐
│                    REDIS SENTINEL CLUSTER                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Applications/Clients    Sentinel Nodes       Redis Instances  │
│  ┌─────────────────┐     ┌─────────────────┐   ┌─────────────────┐
│  │ 🚀 App 1        │────▶│ 👁️ Sentinel 1   │──▶│ 🔴 Redis Master │
│  │                 │     │                 │   │                 │
│  │ ├─ Redis Client │     │ ├─ Monitor      │   │ ├─ Read/Write   │
│  │ ├─ Sentinel    │     │ ├─ Failover     │   │ ├─ Replication  │
│  │ │   Aware       │     │ ├─ Config      │   │ └─ Persistence  │
│  │ └─ Auto-Reconnect     │ └─ Notification │   └─────────────────┘
│  └─────────────────┘     └─────────────────┘                    │
│           │                        │                           │
│           │               ┌─────────────────┐                   │
│           └──────────────▶│ 👁️ Sentinel 2   │                   │
│                          │                 │   ┌─────────────────┐
│  ┌─────────────────┐     │ ├─ Monitor      │──▶│ 🔸 Redis Replica│
│  │ 🚀 App 2        │     │ ├─ Failover     │   │                 │
│  │                 │────▶│ ├─ Config      │   │ ├─ Read Only    │
│  │ ├─ Redis Client │     │ └─ Notification │   │ ├─ Sync Master │
│  │ └─ Load Balance │     └─────────────────┘   │ └─ Backup       │
│  └─────────────────┘              │           └─────────────────┘
│                           ┌─────────────────┐                    │
│                          │ 👁️ Sentinel 3   │                    │
│  ┌─────────────────┐     │                 │   ┌─────────────────┐
│  │ 🚀 App N        │────▶│ ├─ Monitor      │──▶│ 🔸 Redis Replica│
│  │                 │     │ ├─ Failover     │   │                 │
│  │ └─ Highly       │     │ ├─ Config      │   │ ├─ Read Only    │
│  │   Available     │     │ └─ Notification │   │ ├─ Sync Master │
│  └─────────────────┘     └─────────────────┘   │ └─ Backup       │
│                                                └─────────────────┘
│                                                                 │
│  📊 Key Features:                                              │
│  • Automatic master discovery                                  │
│  • Failover automation (no human intervention)                │
│  • Client notification of topology changes                    │
│  • Distributed consensus for leader election                  │
│  • Monitoring and alerting integration                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### **Sentinel Network Communication**
```
┌─────────────────────────────────────────────────────────────────┐
│                  SENTINEL COMMUNICATION FLOW                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Discovery Phase        Monitoring Phase       Failover Phase  │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  │ 🔍 Auto-Discovery│    │ ⏰ Health Checks │    │ 🚨 Failure Detect│
│  │                 │    │                 │    │                 │
│  │ ├─ Master Scan  │    │ ├─ Ping/Pong    │    │ ├─ Quorum Vote  │
│  │ ├─ Replica Scan │    │ ├─ INFO commands│    │ ├─ Leader Election│
│  │ ├─ Sentinel    │    │ ├─ Replication  │    │ ├─ Master Promo │
│  │ │   Discovery   │    │ │   Lag Monitor │    │ ├─ Client Notify│
│  │ └─ Topology Map │    │ └─ Performance  │    │ └─ Config Update│
│  └─────────────────┘    │   Metrics       │    └─────────────────┘
│                         └─────────────────┘                     │
│                                                                 │
│  Communication Channels:                                        │
│  ┌─────────────────────────────────────────────────────────────┐
│  │ • TCP connections to Redis instances (port 6379)           │
│  │ • Sentinel-to-Sentinel communication (port 26379)         │
│  │ • Pub/Sub channels for event notifications                │
│  │ • Client discovery via Sentinel API queries               │
│  │ • Configuration updates through Redis CONFIG SET          │
│  └─────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────┘
```

## ⚙️ How Sentinel Works - Deep Dive

### **1. Service Discovery & Monitoring**

#### **Master Discovery Process**
```bash
# Sentinel configuration for master discovery
sentinel monitor mymaster 192.168.1.100 6379 2

# What happens internally:
# 1. Sentinel connects to the configured master
# 2. Executes INFO replication to discover replicas
# 3. Discovers other Sentinels via SENTINEL SENTINELS command
# 4. Builds complete topology map
# 5. Starts monitoring all instances
```

#### **Continuous Health Monitoring**
```
Every 1 second:
├─ PING command to all Redis instances
├─ INFO replication command to check replication status
├─ SENTINEL HELLO pub/sub to discover other Sentinels
└─ Performance metrics collection

Every 10 seconds:
├─ Detailed INFO commands for system metrics
├─ Replication offset monitoring
├─ Memory usage and connection counts
└─ Sentinel configuration synchronization
```

### **2. Failure Detection & Consensus**

#### **Failure Detection Algorithm**
```
Subjective Down (SDOWN):
┌─────────────────────────────────────┐
│ Single Sentinel detects failure     │
│ ├─ No PING response for down-time   │
│ ├─ Connection refused/timeout       │
│ ├─ Redis instance returns errors    │
│ └─ Marks instance as SDOWN          │
└─────────────────────────────────────┘
                 ↓
Objective Down (ODOWN):
┌─────────────────────────────────────┐
│ Quorum of Sentinels agree failure   │
│ ├─ Query other Sentinels            │
│ ├─ Count SDOWN confirmations        │
│ ├─ Reach quorum threshold (e.g., 2) │
│ └─ Declare instance as ODOWN        │
└─────────────────────────────────────┘
```

#### **Quorum and Leader Election**
```yaml
# Example: 3 Sentinels, quorum = 2
sentinels:
  - sentinel-1: "SDOWN detected on master"
  - sentinel-2: "SDOWN confirmed"      # Quorum reached!
  - sentinel-3: "Master seems OK"      # Minority opinion

# Leader election for failover:
# 1. First Sentinel to detect ODOWN starts election
# 2. Requests votes from other Sentinels
# 3. Majority vote wins (2 out of 3)
# 4. Winner becomes failover leader
# 5. Leader executes failover procedure
```

### **3. Automatic Failover Process**

#### **Detailed Failover Steps**
```
Step 1: Replica Selection
┌─────────────────────────────────────┐
│ Choose best replica for promotion   │
│ ├─ Replica with latest offset      │
│ ├─ Lowest replica priority number  │
│ ├─ Smallest lexicographic runid    │
│ └─ Healthy network connectivity     │
└─────────────────────────────────────┘
                 ↓
Step 2: Promotion
┌─────────────────────────────────────┐
│ Promote selected replica to master  │
│ ├─ Send REPLICAOF NO ONE command   │
│ ├─ Wait for promotion confirmation  │
│ ├─ Verify master role assignment    │
│ └─ Update internal state            │
└─────────────────────────────────────┘
                 ↓
Step 3: Reconfiguration  
┌─────────────────────────────────────┐
│ Reconfigure remaining replicas      │
│ ├─ Point replicas to new master     │
│ ├─ Send REPLICAOF <new-master> cmds │
│ ├─ Wait for replication sync        │
│ └─ Verify topology consistency      │
└─────────────────────────────────────┘
                 ↓
Step 4: Client Notification
┌─────────────────────────────────────┐
│ Notify clients of topology change   │
│ ├─ Update Sentinel configuration    │
│ ├─ Publish +switch-master event     │
│ ├─ Respond to client queries        │
│ └─ Log failover completion          │
└─────────────────────────────────────┘
```

## 🚀 TCA InfraForge Deployment Configuration

### **Production Sentinel Configuration**
```ini
# /etc/redis/sentinel.conf
# Basic configuration
port 26379
sentinel announce-ip 192.168.1.10
sentinel announce-port 26379

# Master definition with quorum
sentinel monitor mymaster 192.168.1.100 6379 2

# Authentication (if Redis has AUTH enabled)
sentinel auth-pass mymaster your-redis-password

# Timing parameters
sentinel down-after-milliseconds mymaster 5000
sentinel parallel-syncs mymaster 2
sentinel failover-timeout mymaster 10000

# Advanced configuration for production
sentinel deny-scripts-reconfig yes
sentinel resolve-hostnames yes
sentinel announce-hostnames yes

# Custom scripts for notifications
sentinel notification-script mymaster /etc/redis/notify.sh
sentinel client-reconfig-script mymaster /etc/redis/reconfig.sh

# Log configuration
logfile /var/log/redis/sentinel.log
syslog-enabled yes
syslog-ident redis-sentinel
syslog-facility local0

# Security settings
protected-mode yes
bind 192.168.1.10 127.0.0.1
requirepass your-sentinel-password
```

### **Kubernetes Deployment with High Availability**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-sentinel
  namespace: redis-system
  labels:
    app: redis-sentinel
spec:
  serviceName: redis-sentinel
  replicas: 3
  selector:
    matchLabels:
      app: redis-sentinel
  template:
    metadata:
      labels:
        app: redis-sentinel
    spec:
      serviceAccountName: redis-sentinel
      affinity:
        # Ensure Sentinels run on different nodes
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: redis-sentinel
            topologyKey: kubernetes.io/hostname
      containers:
      - name: redis-sentinel
        image: redis:7-alpine
        command:
        - redis-sentinel
        - /etc/redis/sentinel.conf
        ports:
        - containerPort: 26379
          name: sentinel
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        - name: SENTINEL_QUORUM
          value: "2"
        - name: SENTINEL_DOWN_AFTER
          value: "5000"
        - name: SENTINEL_FAILOVER_TIMEOUT
          value: "10000"
        volumeMounts:
        - name: config
          mountPath: /etc/redis/
          readOnly: true
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: 128Mi
            cpu: 100m
          limits:
            memory: 256Mi
            cpu: 200m
        livenessProbe:
          tcpSocket:
            port: 26379
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - -p
            - "26379"
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: redis-sentinel-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi

---
# Sentinel configuration ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-sentinel-config
  namespace: redis-system
data:
  sentinel.conf: |
    port 26379
    sentinel monitor mymaster redis-master 6379 2
    sentinel auth-pass mymaster $REDIS_PASSWORD
    sentinel down-after-milliseconds mymaster $SENTINEL_DOWN_AFTER
    sentinel parallel-syncs mymaster 1
    sentinel failover-timeout mymaster $SENTINEL_FAILOVER_TIMEOUT
    
    # Security
    protected-mode no  # Disabled for Kubernetes internal networking
    
    # Logging
    logfile ""
    
    # Custom notification scripts
    sentinel notification-script mymaster /etc/redis/notify.sh
    
    # Configuration for dynamic discovery in Kubernetes
    sentinel resolve-hostnames yes
    sentinel announce-hostnames yes

  notify.sh: |
    #!/bin/bash
    # Notification script for Sentinel events
    EVENT_TYPE=$1
    EVENT_NAME=$2
    EVENT_IP=$3
    EVENT_PORT=$4
    
    case $EVENT_TYPE in
        "+switch-master")
            echo "Master switched from $EVENT_IP:$EVENT_PORT to new master"
            # Send alert to monitoring system
            curl -X POST "http://alertmanager:9093/api/v1/alerts" \
              -H "Content-Type: application/json" \
              -d '[{
                "labels": {
                  "alertname": "RedisMasterSwitched",
                  "service": "redis",
                  "severity": "warning"
                },
                "annotations": {
                  "summary": "Redis master has switched",
                  "description": "Redis master switched from '$EVENT_IP:$EVENT_PORT'"
                }
              }]'
            ;;
        "+slave-reconf-sent")
            echo "Reconfiguration sent to replica $EVENT_IP:$EVENT_PORT"
            ;;
        "+slave-reconf-inprog")
            echo "Reconfiguration in progress for replica $EVENT_IP:$EVENT_PORT"
            ;;
        "+slave-reconf-done")
            echo "Reconfiguration completed for replica $EVENT_IP:$EVENT_PORT"
            ;;
    esac

---
# Service for Sentinel discovery
apiVersion: v1
kind: Service
metadata:
  name: redis-sentinel
  namespace: redis-system
  labels:
    app: redis-sentinel
spec:
  clusterIP: None  # Headless service for StatefulSet
  ports:
  - port: 26379
    targetPort: 26379
    name: sentinel
  selector:
    app: redis-sentinel

---
# External service for client access
apiVersion: v1
kind: Service
metadata:
  name: redis-sentinel-client
  namespace: redis-system
  labels:
    app: redis-sentinel
spec:
  type: ClusterIP
  ports:
  - port: 26379
    targetPort: 26379
    name: sentinel
  selector:
    app: redis-sentinel
```

### **Redis Master-Replica with Sentinel**
```yaml
# Redis Master StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-master
  namespace: redis-system
spec:
  serviceName: redis-master
  replicas: 1
  selector:
    matchLabels:
      app: redis
      role: master
  template:
    metadata:
      labels:
        app: redis
        role: master
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command:
        - redis-server
        - /etc/redis/redis.conf
        ports:
        - containerPort: 6379
          name: redis
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        volumeMounts:
        - name: config
          mountPath: /etc/redis/
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: 512Mi
            cpu: 250m
          limits:
            memory: 1Gi
            cpu: 500m
      volumes:
      - name: config
        configMap:
          name: redis-master-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 10Gi

---
# Redis Replica StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-replica
  namespace: redis-system
spec:
  serviceName: redis-replica
  replicas: 2
  selector:
    matchLabels:
      app: redis
      role: replica
  template:
    metadata:
      labels:
        app: redis
        role: replica
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command:
        - redis-server
        - /etc/redis/redis.conf
        - --replicaof
        - redis-master
        - "6379"
        ports:
        - containerPort: 6379
          name: redis
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        volumeMounts:
        - name: config
          mountPath: /etc/redis/
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: 256Mi
            cpu: 125m
          limits:
            memory: 512Mi
            cpu: 250m
      volumes:
      - name: config
        configMap:
          name: redis-replica-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 10Gi

---
# Redis Master Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-master-config
  namespace: redis-system
data:
  redis.conf: |
    # Network and security
    bind 0.0.0.0
    protected-mode yes
    port 6379
    requirepass $REDIS_PASSWORD
    
    # Persistence
    save 900 1
    save 300 10
    save 60 10000
    rdbcompression yes
    rdbchecksum yes
    dbfilename dump.rdb
    dir /data
    
    # Append only file
    appendonly yes
    appendfilename "appendonly.aof"
    appendfsync everysec
    no-appendfsync-on-rewrite no
    auto-aof-rewrite-percentage 100
    auto-aof-rewrite-min-size 64mb
    
    # Memory management
    maxmemory 512mb
    maxmemory-policy allkeys-lru
    
    # Replication (master settings)
    min-replicas-to-write 1
    min-replicas-max-lag 10
    
    # Logging
    loglevel notice
    logfile ""
    
    # Client management
    timeout 300
    tcp-keepalive 300
    maxclients 10000

---
# Redis Replica Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-replica-config
  namespace: redis-system
data:
  redis.conf: |
    # Network and security
    bind 0.0.0.0
    protected-mode yes
    port 6379
    requirepass $REDIS_PASSWORD
    masterauth $REDIS_PASSWORD
    
    # Replica configuration
    replica-read-only yes
    replica-serve-stale-data yes
    replica-priority 100
    
    # Persistence (usually disabled on replicas for performance)
    save ""
    appendonly no
    
    # Memory management
    maxmemory 256mb
    maxmemory-policy allkeys-lru
    
    # Logging
    loglevel notice
    logfile ""
    
    # Client management
    timeout 300
    tcp-keepalive 300
    maxclients 10000
```

## 👥 Client Integration Patterns

### **Java/Spring Boot Integration**
```java
// Jedis with Sentinel support
@Configuration
public class RedisConfig {
    
    @Value("${redis.sentinel.master-name}")
    private String masterName;
    
    @Value("${redis.sentinel.nodes}")
    private String sentinelNodes;
    
    @Value("${redis.password}")
    private String password;
    
    @Bean
    public JedisSentinelPool jedisSentinelPool() {
        Set<String> sentinels = Arrays.stream(sentinelNodes.split(","))
                .collect(Collectors.toSet());
        
        GenericObjectPoolConfig poolConfig = new GenericObjectPoolConfig();
        poolConfig.setMaxTotal(20);
        poolConfig.setMaxIdle(10);
        poolConfig.setMinIdle(5);
        poolConfig.setTestOnBorrow(true);
        poolConfig.setTestOnReturn(true);
        poolConfig.setTestWhileIdle(true);
        
        return new JedisSentinelPool(
            masterName, 
            sentinels, 
            poolConfig, 
            2000, // timeout
            password
        );
    }
    
    @Bean
    public RedisTemplate<String, Object> redisTemplate(JedisSentinelPool pool) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        
        JedisConnectionFactory factory = new JedisConnectionFactory(
            new RedisSentinelConfiguration(masterName, sentinels)
        );
        factory.setPassword(password);
        factory.setPoolConfig(poolConfig);
        
        template.setConnectionFactory(factory);
        template.setDefaultSerializer(new GenericJackson2JsonRedisSerializer());
        template.setKeySerializer(new StringRedisSerializer());
        template.setHashKeySerializer(new StringRedisSerializer());
        
        return template;
    }
}

// Service with automatic failover handling
@Service
public class CacheService {
    
    private final RedisTemplate<String, Object> redisTemplate;
    private final JedisSentinelPool sentinelPool;
    
    @Retryable(value = {RedisConnectionFailureException.class}, maxAttempts = 3)
    public void set(String key, Object value, Duration ttl) {
        try {
            redisTemplate.opsForValue().set(key, value, ttl);
        } catch (RedisConnectionFailureException e) {
            log.warn("Redis connection failed, retrying...", e);
            throw e;
        }
    }
    
    @Retryable(value = {RedisConnectionFailureException.class}, maxAttempts = 3)
    public Optional<Object> get(String key) {
        try {
            Object value = redisTemplate.opsForValue().get(key);
            return Optional.ofNullable(value);
        } catch (RedisConnectionFailureException e) {
            log.warn("Redis connection failed, retrying...", e);
            throw e;
        }
    }
    
    // Health check method
    public boolean isHealthy() {
        try (Jedis jedis = sentinelPool.getResource()) {
            return "PONG".equals(jedis.ping());
        } catch (Exception e) {
            log.error("Redis health check failed", e);
            return false;
        }
    }
}
```

### **Node.js/Express Integration**
```javascript
// Redis client with Sentinel support
const Redis = require('ioredis');

class RedisSentinelClient {
    constructor(options = {}) {
        const defaultOptions = {
            sentinels: [
                { host: 'sentinel-1', port: 26379 },
                { host: 'sentinel-2', port: 26379 },
                { host: 'sentinel-3', port: 26379 }
            ],
            name: 'mymaster',
            password: process.env.REDIS_PASSWORD,
            sentinelPassword: process.env.SENTINEL_PASSWORD,
            
            // Connection pool settings
            maxRetriesPerRequest: 3,
            retryDelayOnFailover: 100,
            enableOfflineQueue: false,
            maxRetriesPerRequest: null,
            
            // Reconnection settings
            connectTimeout: 10000,
            commandTimeout: 5000,
            retryDelayOnClusterDown: 300,
            retryDelayOnFailover: 100,
            maxRetriesPerRequest: 3,
            
            // Sentinel specific settings
            enableReadyCheck: true,
            sentinelRetryTime: 2000,
            sentinelMaxRetriesPerRequest: 3
        };
        
        this.options = { ...defaultOptions, ...options };
        this.client = null;
        this.isConnected = false;
        
        this.connect();
        this.setupEventHandlers();
    }
    
    connect() {
        this.client = new Redis(this.options);
    }
    
    setupEventHandlers() {
        this.client.on('connect', () => {
            console.log('Connected to Redis via Sentinel');
            this.isConnected = true;
        });
        
        this.client.on('ready', () => {
            console.log('Redis client ready');
        });
        
        this.client.on('error', (err) => {
            console.error('Redis client error:', err);
            this.isConnected = false;
        });
        
        this.client.on('close', () => {
            console.log('Redis connection closed');
            this.isConnected = false;
        });
        
        this.client.on('reconnecting', () => {
            console.log('Redis client reconnecting...');
        });
        
        this.client.on('+switch-master', (master) => {
            console.log('Switched to new master:', master);
        });
    }
    
    async get(key) {
        try {
            return await this.client.get(key);
        } catch (error) {
            console.error(`Failed to get key ${key}:`, error);
            throw error;
        }
    }
    
    async set(key, value, ttlSeconds = null) {
        try {
            if (ttlSeconds) {
                return await this.client.setex(key, ttlSeconds, value);
            }
            return await this.client.set(key, value);
        } catch (error) {
            console.error(`Failed to set key ${key}:`, error);
            throw error;
        }
    }
    
    async del(key) {
        try {
            return await this.client.del(key);
        } catch (error) {
            console.error(`Failed to delete key ${key}:`, error);
            throw error;
        }
    }
    
    async healthCheck() {
        try {
            const result = await this.client.ping();
            return result === 'PONG';
        } catch (error) {
            console.error('Redis health check failed:', error);
            return false;
        }
    }
    
    async getMasterInfo() {
        try {
            // Get master info from Sentinel
            const sentinelClient = new Redis.Cluster([
                { host: 'sentinel-1', port: 26379 }
            ]);
            
            const masters = await sentinelClient.sentinel('masters');
            return masters.find(master => master[1] === this.options.name);
        } catch (error) {
            console.error('Failed to get master info:', error);
            return null;
        }
    }
    
    disconnect() {
        if (this.client) {
            this.client.disconnect();
        }
    }
}

// Usage in Express app
const express = require('express');
const app = express();

const redisClient = new RedisSentinelClient({
    sentinels: [
        { host: process.env.SENTINEL_HOST_1, port: 26379 },
        { host: process.env.SENTINEL_HOST_2, port: 26379 },
        { host: process.env.SENTINEL_HOST_3, port: 26379 }
    ]
});

// Middleware for caching
const cacheMiddleware = (ttl = 300) => {
    return async (req, res, next) => {
        const key = `cache:${req.originalUrl}`;
        
        try {
            const cached = await redisClient.get(key);
            if (cached) {
                return res.json(JSON.parse(cached));
            }
            
            // Store original res.json
            const originalJson = res.json;
            res.json = function(data) {
                // Cache the response
                redisClient.set(key, JSON.stringify(data), ttl)
                    .catch(err => console.error('Caching error:', err));
                
                // Call original json method
                originalJson.call(this, data);
            };
            
            next();
        } catch (error) {
            console.error('Cache middleware error:', error);
            next();
        }
    };
};

// Health check endpoint
app.get('/health', async (req, res) => {
    const isHealthy = await redisClient.healthCheck();
    const masterInfo = await redisClient.getMasterInfo();
    
    res.json({
        redis: {
            healthy: isHealthy,
            connected: redisClient.isConnected,
            master: masterInfo ? {
                ip: masterInfo[3],
                port: masterInfo[5],
                flags: masterInfo[9]
            } : null
        }
    });
});

// Cached endpoint
app.get('/api/data', cacheMiddleware(600), async (req, res) => {
    // This response will be cached for 10 minutes
    const data = await fetchExpensiveData();
    res.json(data);
});

module.exports = app;
```

### **Python/Django Integration**
```python
# settings.py
import os
from django_redis import get_redis_connection

CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': [
            'redis://sentinel-1:26379/0',
            'redis://sentinel-2:26379/0', 
            'redis://sentinel-3:26379/0',
        ],
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.SentinelClient',
            'SENTINELS': [
                ('sentinel-1', 26379),
                ('sentinel-2', 26379),
                ('sentinel-3', 26379),
            ],
            'SENTINEL_KWARGS': {
                'password': os.getenv('SENTINEL_PASSWORD'),
            },
            'PASSWORD': os.getenv('REDIS_PASSWORD'),
            'MASTER_NAME': 'mymaster',
            'CONNECTION_POOL_KWARGS': {
                'retry_on_timeout': True,
                'health_check_interval': 30,
            },
        }
    }
}

# Redis sentinel client wrapper
import redis.sentinel
from django.conf import settings
from django.core.cache import cache
import logging

logger = logging.getLogger(__name__)

class RedisSentinelManager:
    def __init__(self):
        self.sentinels = redis.sentinel.Sentinel([
            ('sentinel-1', 26379),
            ('sentinel-2', 26379), 
            ('sentinel-3', 26379)
        ], password=settings.SENTINEL_PASSWORD)
        
        self.master_name = 'mymaster'
        self.redis_password = settings.REDIS_PASSWORD
    
    def get_master(self):
        """Get Redis master connection"""
        try:
            master = self.sentinels.master_for(
                self.master_name,
                password=self.redis_password,
                socket_timeout=0.5,
                socket_connect_timeout=0.5,
                retry_on_timeout=True
            )
            return master
        except Exception as e:
            logger.error(f"Failed to get Redis master: {e}")
            raise
    
    def get_slave(self):
        """Get Redis slave connection for read operations"""
        try:
            slave = self.sentinels.slave_for(
                self.master_name,
                password=self.redis_password,
                socket_timeout=0.5,
                socket_connect_timeout=0.5,
                retry_on_timeout=True
            )
            return slave
        except Exception as e:
            logger.warning(f"Failed to get Redis slave, falling back to master: {e}")
            return self.get_master()
    
    def get_master_info(self):
        """Get current master information"""
        try:
            sentinel_client = redis.Redis(host='sentinel-1', port=26379, 
                                        password=settings.SENTINEL_PASSWORD)
            master_info = sentinel_client.sentinel_masters()[self.master_name]
            return {
                'ip': master_info['ip'],
                'port': master_info['port'],
                'flags': master_info['flags'],
                'num_slaves': master_info['num-slaves'],
                'num_other_sentinels': master_info['num-other-sentinels']
            }
        except Exception as e:
            logger.error(f"Failed to get master info: {e}")
            return None
    
    def health_check(self):
        """Check Redis cluster health"""
        try:
            master = self.get_master()
            response = master.ping()
            return response == True
        except Exception as e:
            logger.error(f"Redis health check failed: {e}")
            return False

# Django service with caching
from django.core.cache import cache
from django.core.cache.utils import make_template_fragment_key
from django.utils.decorators import method_decorator
from django.views.decorators.cache import cache_page
from django.views.decorators.vary import vary_on_cookie

redis_manager = RedisSentinelManager()

class CacheService:
    @staticmethod
    def get_or_set(key, default_func, timeout=300):
        """Get from cache or set with function result"""
        try:
            value = cache.get(key)
            if value is None:
                value = default_func()
                cache.set(key, value, timeout)
            return value
        except Exception as e:
            logger.error(f"Cache operation failed for key {key}: {e}")
            # Fallback to function call if cache fails
            return default_func()
    
    @staticmethod
    def invalidate_pattern(pattern):
        """Invalidate all keys matching pattern"""
        try:
            master = redis_manager.get_master()
            keys = master.keys(pattern)
            if keys:
                master.delete(*keys)
                logger.info(f"Invalidated {len(keys)} keys matching pattern: {pattern}")
        except Exception as e:
            logger.error(f"Failed to invalidate pattern {pattern}: {e}")
    
    @staticmethod
    def get_cache_stats():
        """Get cache statistics"""
        try:
            master = redis_manager.get_master()
            info = master.info()
            return {
                'used_memory_human': info['used_memory_human'],
                'connected_clients': info['connected_clients'],
                'total_commands_processed': info['total_commands_processed'],
                'keyspace_hits': info['keyspace_hits'],
                'keyspace_misses': info['keyspace_misses'],
                'hit_rate': info['keyspace_hits'] / (info['keyspace_hits'] + info['keyspace_misses']) * 100
            }
        except Exception as e:
            logger.error(f"Failed to get cache stats: {e}")
            return None

# Views with caching
from django.http import JsonResponse
from django.views import View

class HealthCheckView(View):
    def get(self, request):
        redis_health = redis_manager.health_check()
        master_info = redis_manager.get_master_info()
        cache_stats = CacheService.get_cache_stats()
        
        return JsonResponse({
            'redis': {
                'healthy': redis_health,
                'master': master_info,
                'stats': cache_stats
            }
        })

@method_decorator(cache_page(600), name='dispatch')
@method_decorator(vary_on_cookie, name='dispatch')
class CachedDataView(View):
    def get(self, request):
        # This view is cached for 10 minutes
        data = CacheService.get_or_set(
            f'expensive_data:{request.user.id}',
            lambda: self.get_expensive_data(request.user),
            timeout=1800  # 30 minutes
        )
        return JsonResponse(data)
    
    def get_expensive_data(self, user):
        # Expensive database operation
        return {'data': 'expensive computation result'}
```

## 📊 Monitoring & Alerting

### **Prometheus Monitoring Configuration**
```yaml
# Redis Sentinel ServiceMonitor
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: redis-sentinel
  namespace: redis-system
  labels:
    app: redis-sentinel
spec:
  selector:
    matchLabels:
      app: redis-sentinel
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s

---
# Redis exporter for detailed metrics
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-exporter
  namespace: redis-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis-exporter
  template:
    metadata:
      labels:
        app: redis-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9121"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: redis-exporter
        image: oliver006/redis_exporter:latest
        ports:
        - containerPort: 9121
          name: metrics
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
        - name: REDIS_ADDR
          value: "redis://redis-sentinel-client:26379"
        - name: REDIS_EXPORTER_IS_SENTINEL
          value: "true"
        - name: REDIS_EXPORTER_SENTINEL_MASTER_NAME
          value: "mymaster"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi

---
# Alert rules for Redis Sentinel
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: redis-sentinel-alerts
  namespace: redis-system
  labels:
    app: redis-sentinel
spec:
  groups:
  - name: redis-sentinel
    interval: 30s
    rules:
    - alert: RedisMasterDown
      expr: redis_sentinel_master_ok == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Redis master is down"
        description: "Redis master {{ $labels.master_name }} has been down for more than 1 minute"
    
    - alert: RedisReplicationLag
      expr: redis_slave_lag_in_seconds > 30
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Redis replication lag is high"
        description: "Redis replica {{ $labels.instance }} is lagging by {{ $value }} seconds"
    
    - alert: RedisSentinelDown
      expr: up{job="redis-sentinel"} == 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Redis Sentinel is down"
        description: "Redis Sentinel {{ $labels.instance }} is down"
    
    - alert: RedisMemoryUsageHigh
      expr: redis_memory_used_bytes / redis_memory_max_bytes * 100 > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Redis memory usage is high"
        description: "Redis instance {{ $labels.instance }} memory usage is {{ $value }}%"
    
    - alert: RedisConnectionSpike
      expr: increase(redis_connections_received_total[5m]) > 1000
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Redis connection spike detected"
        description: "Redis instance {{ $labels.instance }} received {{ $value }} new connections in the last 5 minutes"
    
    - alert: RedisSlowLogEntries
      expr: increase(redis_slowlog_length[5m]) > 10
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Redis slow queries detected"
        description: "Redis instance {{ $labels.instance }} has {{ $value }} slow log entries in the last 5 minutes"
```

### **Grafana Dashboard Configuration**
```json
{
  "dashboard": {
    "id": null,
    "title": "Redis Sentinel Cluster",
    "tags": ["redis", "sentinel", "caching"],
    "timezone": "browser",
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "Cluster Overview",
        "type": "stat",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "redis_sentinel_masters",
            "legendFormat": "Masters",
            "refId": "A"
          },
          {
            "expr": "redis_sentinel_slaves",
            "legendFormat": "Replicas",
            "refId": "B"
          },
          {
            "expr": "count(up{job=\"redis-sentinel\"})",
            "legendFormat": "Sentinels",
            "refId": "C"
          }
        ]
      },
      {
        "id": 2,
        "title": "Master Status",
        "type": "stat",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "redis_sentinel_master_ok",
            "legendFormat": "Master OK",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "mappings": [
              {
                "options": {
                  "0": {"text": "DOWN", "color": "red"},
                  "1": {"text": "UP", "color": "green"}
                },
                "type": "value"
              }
            ]
          }
        }
      },
      {
        "id": 3,
        "title": "Memory Usage",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "redis_memory_used_bytes",
            "legendFormat": "{{ instance }} - Used Memory",
            "refId": "A"
          },
          {
            "expr": "redis_memory_max_bytes",
            "legendFormat": "{{ instance }} - Max Memory",
            "refId": "B"
          }
        ]
      },
      {
        "id": 4,
        "title": "Commands Per Second",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16},
        "targets": [
          {
            "expr": "rate(redis_commands_processed_total[5m])",
            "legendFormat": "{{ instance }} - Commands/sec",
            "refId": "A"
          }
        ]
      },
      {
        "id": 5,
        "title": "Replication Lag",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16},
        "targets": [
          {
            "expr": "redis_slave_lag_in_seconds",
            "legendFormat": "{{ instance }} - Lag (seconds)",
            "refId": "A"
          }
        ]
      },
      {
        "id": 6,
        "title": "Connected Clients",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 24},
        "targets": [
          {
            "expr": "redis_connected_clients",
            "legendFormat": "{{ instance }} - Clients",
            "refId": "A"
          }
        ]
      },
      {
        "id": 7,
        "title": "Keyspace Hit Rate",
        "type": "stat",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 24},
        "targets": [
          {
            "expr": "rate(redis_keyspace_hits_total[5m]) / (rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m])) * 100",
            "legendFormat": "Hit Rate %",
            "refId": "A"
          }
        ]
      }
    ]
  }
}
```

## 🔧 Operational Best Practices

### **Deployment Checklist**
```yaml
# Pre-deployment checklist
pre_deployment:
  infrastructure:
    - [ ] Network connectivity between all nodes
    - [ ] Proper DNS resolution or IP reachability
    - [ ] Firewall rules allow Redis (6379) and Sentinel (26379) ports
    - [ ] NTP synchronization across all nodes
    - [ ] Sufficient disk space for data and logs
    - [ ] Memory allocation planning completed
  
  configuration:
    - [ ] Quorum size properly calculated (N/2 + 1)
    - [ ] Authentication passwords configured
    - [ ] Persistence settings configured per requirements
    - [ ] Log levels and locations configured
    - [ ] Notification scripts tested
    - [ ] Backup procedures documented and tested
  
  security:
    - [ ] Redis AUTH enabled with strong passwords
    - [ ] Sentinel AUTH configured
    - [ ] Network isolation implemented
    - [ ] SSL/TLS configured if required
    - [ ] Monitoring and alerting configured

# Post-deployment validation
post_deployment:
  functional:
    - [ ] Master-replica replication working
    - [ ] Sentinel discovery functioning
    - [ ] Automatic failover tested
    - [ ] Client connectivity verified
    - [ ] Performance benchmarks completed
  
  operational:
    - [ ] Monitoring dashboards active
    - [ ] Alerts configured and tested
    - [ ] Backup procedures validated
    - [ ] Documentation updated
    - [ ] Team training completed
```

### **Troubleshooting Guide**
```bash
#!/bin/bash
# Redis Sentinel troubleshooting script

echo "=== Redis Sentinel Cluster Health Check ==="

# Check Sentinel processes
echo "1. Checking Sentinel processes..."
kubectl get pods -n redis-system -l app=redis-sentinel

# Check Sentinel configuration
echo "2. Checking Sentinel configuration..."
kubectl logs -n redis-system -l app=redis-sentinel --tail=50

# Check master discovery
echo "3. Checking master discovery..."
kubectl exec -it redis-sentinel-0 -n redis-system -- redis-cli -p 26379 sentinel masters

# Check replica status
echo "4. Checking replica status..."
kubectl exec -it redis-sentinel-0 -n redis-system -- redis-cli -p 26379 sentinel replicas mymaster

# Check other Sentinels
echo "5. Checking other Sentinels..."
kubectl exec -it redis-sentinel-0 -n redis-system -- redis-cli -p 26379 sentinel sentinels mymaster

# Test failover capability
echo "6. Testing failover capability (simulation)..."
kubectl exec -it redis-sentinel-0 -n redis-system -- redis-cli -p 26379 sentinel failover mymaster

# Check Redis master status
echo "7. Checking Redis master status..."
MASTER_IP=$(kubectl exec -it redis-sentinel-0 -n redis-system -- redis-cli -p 26379 sentinel get-master-addr-by-name mymaster | head -1 | tr -d '\r')
MASTER_PORT=$(kubectl exec -it redis-sentinel-0 -n redis-system -- redis-cli -p 26379 sentinel get-master-addr-by-name mymaster | tail -1 | tr -d '\r')
echo "Current master: $MASTER_IP:$MASTER_PORT"

# Check replication status
echo "8. Checking replication status..."
kubectl exec -it redis-master-0 -n redis-system -- redis-cli INFO replication

# Performance test
echo "9. Running performance test..."
kubectl exec -it redis-master-0 -n redis-system -- redis-cli --latency-history -h $MASTER_IP -p $MASTER_PORT

echo "=== Health check completed ==="
```

### **Maintenance Procedures**
```bash
# Rolling restart procedure for Sentinels
rolling_restart_sentinels() {
    echo "Starting rolling restart of Sentinel nodes..."
    
    for i in {0..2}; do
        echo "Restarting redis-sentinel-$i..."
        kubectl delete pod redis-sentinel-$i -n redis-system
        
        # Wait for pod to be ready
        kubectl wait --for=condition=Ready pod/redis-sentinel-$i -n redis-system --timeout=300s
        
        # Verify Sentinel is functioning
        kubectl exec redis-sentinel-$i -n redis-system -- redis-cli -p 26379 sentinel masters
        
        echo "Sentinel $i restarted successfully"
        sleep 30  # Wait before restarting next Sentinel
    done
    
    echo "Rolling restart completed"
}

# Scale replica nodes
scale_replicas() {
    local new_count=$1
    echo "Scaling Redis replicas to $new_count..."
    
    kubectl scale statefulset redis-replica --replicas=$new_count -n redis-system
    kubectl wait --for=condition=Ready pod -l role=replica -n redis-system --timeout=300s
    
    # Update Sentinel configuration if needed
    echo "Verifying Sentinel can discover new replicas..."
    sleep 60  # Wait for Sentinel discovery
    kubectl exec redis-sentinel-0 -n redis-system -- redis-cli -p 26379 sentinel replicas mymaster
}

# Backup procedure
backup_redis_data() {
    local backup_name="redis-backup-$(date +%Y%m%d-%H%M%S)"
    echo "Creating backup: $backup_name"
    
    # Create Redis data snapshot
    kubectl exec redis-master-0 -n redis-system -- redis-cli BGSAVE
    
    # Wait for background save to complete
    while [ "$(kubectl exec redis-master-0 -n redis-system -- redis-cli LASTSAVE)" == "$(kubectl exec redis-master-0 -n redis-system -- redis-cli LASTSAVE)" ]; do
        sleep 5
    done
    
    # Copy data files to backup location
    kubectl cp redis-system/redis-master-0:/data /backup/$backup_name
    
    echo "Backup completed: $backup_name"
}
```

---

## 🎯 Conclusion: Redis Sentinel Mastery

Redis Sentinel provides **TCA InfraForge-grade high availability** for Redis with:

### **🏆 Key Benefits**
- ✅ **Automatic Failover**: No manual intervention required during outages
- ✅ **Configuration Discovery**: Clients automatically find current master
- ✅ **High Availability**: Survives individual node failures
- ✅ **Monitoring Integration**: Built-in health checks and notifications
- ✅ **Distributed Consensus**: Quorum-based decision making prevents split-brain

### **💡 Best Practices Implemented**
- ✅ **Odd Number of Sentinels** (3 or 5) for proper quorum
- ✅ **Geographic Distribution** across availability zones
- ✅ **Monitoring & Alerting** with Prometheus and Grafana
- ✅ **Client Integration** with automatic reconnection
- ✅ **Security Hardening** with authentication and network policies

### **🚀 Production Ready**
This Redis Sentinel setup provides the **high availability caching layer** that your TCA InfraForge lab needs for production workloads. It automatically handles failures, scales with your needs, and integrates seamlessly with your monitoring stack.

**Your TCA InfraForge lab now has bulletproof caching! 🛡️**
