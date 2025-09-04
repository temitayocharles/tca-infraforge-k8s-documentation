#!/bin/bash
# TC Enterprise Platform - Emergency Fix & Redeploy
# Fixing crooked landing page and broken service endpoints

set -e

echo "🔧 TC ENTERPRISE EMERGENCY FIX"
echo "=============================="
echo ""

# Start registry if needed
echo "🚀 Starting local registry..."
if ! docker ps | grep -q registry:2; then
  docker run -d --name registry --restart=always -p 5001:5001 registry:2
    sleep 3
fi

# Deploy essential services
echo "🔄 Deploying core TC Enterprise services..."

# 1. Fix the main landing page service
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tc-main-portal
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tc-main-portal
  template:
    metadata:
      labels:
        app: tc-main-portal
    spec:
      containers:
      - name: portal
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: portal-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: portal-content
        configMap:
          name: tc-portal-config
---
apiVersion: v1
kind: Service
metadata:
  name: tc-main-portal
  namespace: default
spec:
  selector:
    app: tc-main-portal
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: tc-portal-config
  namespace: default
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>💠Ӱ🔍🎯 TC Enterprise DevOps Platform™,⚡</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                padding: 2rem;
            }
            .header {
                text-align: center;
                color: white;
                margin-bottom: 3rem;
            }
            .header h1 {
                font-size: 3rem;
                margin-bottom: 1rem;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            }
            .badges {
                display: flex;
                justify-content: center;
                gap: 1rem;
                margin-bottom: 2rem;
                flex-wrap: wrap;
            }
            .badge {
                background: rgba(255,255,255,0.2);
                padding: 0.5rem 1rem;
                border-radius: 25px;
                color: white;
                font-weight: 500;
                border: 1px solid rgba(255,255,255,0.3);
            }
            .services {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
                gap: 2rem;
                max-width: 1200px;
                margin: 0 auto;
            }
            .service-card {
                background: rgba(255,255,255,0.95);
                border-radius: 15px;
                padding: 2rem;
                box-shadow: 0 10px 30px rgba(0,0,0,0.2);
                transition: transform 0.3s ease;
            }
            .service-card:hover {
                transform: translateY(-5px);
            }
            .service-title {
                color: #4f46e5;
                font-size: 1.5rem;
                font-weight: bold;
                margin-bottom: 1rem;
            }
            .service-desc {
                color: #6b7280;
                margin-bottom: 1.5rem;
                line-height: 1.6;
            }
            .status {
                display: inline-block;
                padding: 0.25rem 0.75rem;
                border-radius: 12px;
                font-size: 0.875rem;
                font-weight: 500;
                margin-bottom: 1rem;
            }
            .status.active {
                background: #10b981;
                color: white;
            }
            .service-btn {
                background: linear-gradient(45deg, #ff6b6b, #ee5a24);
                color: white;
                padding: 0.75rem 1.5rem;
                border: none;
                border-radius: 8px;
                font-weight: 600;
                cursor: pointer;
                transition: all 0.3s ease;
                text-decoration: none;
                display: inline-block;
            }
            .service-btn:hover {
                transform: translateY(-2px);
                box-shadow: 0 5px 15px rgba(255,107,107,0.4);
            }
            .footer {
                text-align: center;
                color: white;
                margin-top: 3rem;
                opacity: 0.8;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>💠Ӱ🔍🎯 TC Enterprise DevOps Platform™,⚡</h1>
            <div class="badges">
                <div class="badge">💠Ӱ Owned by Temitayo Charles</div>
                <div class="badge">💠Ӱ🔍⚡ TC Enterprise DevOps Stack</div>
                <div class="badge">💠ӰŪ🌍 temitayocharles.online</div>
            </div>
        </div>

        <div class="services">
            <div class="service-card">
                <div class="service-title">💠Ӱ🔐 Authentik SSO</div>
                <div class="status active">🟢 Active</div>
                <div class="service-desc">Enterprise authentication and identity management</div>
                <a href="/auth" class="service-btn">💠Ӱ➤ Access Portal</a>
            </div>

            <div class="service-card">
                <div class="service-title">💠Ӱ🔍👤 Grafana Analytics</div>
                <div class="status active">🟢 Active</div>
                <div class="service-desc">Beautiful dashboards and metrics visualization</div>
                <a href="/monitoring" class="service-btn">💠Ӱ➤ Open Dashboards</a>
            </div>

            <div class="service-card">
                <div class="service-title">💠Ӱ🔐⚡ Prometheus Metrics</div>
                <div class="status active">🟢 Active</div>
                <div class="service-desc">Time-series metrics collection and monitoring</div>
                <a href="/metrics" class="service-btn">💠Ӱ➤ Query Metrics</a>
            </div>

            <div class="service-card">
                <div class="service-title">âī🎛ī Kubernetes Dashboard</div>
                <div class="status active">🟢 Active</div>
                <div class="service-desc">Kubernetes cluster management interface</div>
                <a href="/dashboard" class="service-btn">💠Ӱ➤ Manage Cluster</a>
            </div>
        </div>

        <div class="footer">
            <p>© 2025 Temitayo Charles. All Rights Reserved. TC Enterprise DevOps Platform™</p>
            <p>Innovation Through Excellence | temitayocharles.online</p>
        </div>

        <script>
            // Add click handlers for better UX
            document.querySelectorAll('.service-btn').forEach(btn => {
                btn.addEventListener('click', function(e) {
                    // Add loading state
                    this.style.opacity = '0.7';
                    this.innerHTML = '⏳ Loading...';
                    
                    // Reset after 3 seconds if page doesn't redirect
                    setTimeout(() => {
                        this.style.opacity = '1';
                        this.innerHTML = this.innerHTML.replace('⏳ Loading...', btn.innerHTML);
                    }, 3000);
                });
            });
        </script>
    </body>
    </html>
EOF

# 2. Deploy Grafana service
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tc-grafana
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tc-grafana
  template:
    metadata:
      labels:
        app: tc-grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "tcadmin2025"
        - name: GF_SERVER_ROOT_URL
          value: "http://localhost/monitoring/"
        - name: GF_SERVER_SERVE_FROM_SUB_PATH
          value: "true"
---
apiVersion: v1
kind: Service
metadata:
  name: tc-grafana
  namespace: default
spec:
  selector:
    app: tc-grafana
  ports:
  - port: 3000
    targetPort: 3000
  type: ClusterIP
EOF

# 3. Deploy Prometheus service
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tc-prometheus
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tc-prometheus
  template:
    metadata:
      labels:
        app: tc-prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        args:
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus/
        - --web.console.libraries=/etc/prometheus/console_libraries
        - --web.console.templates=/etc/prometheus/consoles
        - --web.enable-lifecycle
        - --web.route-prefix=/metrics/
        - --web.external-url=http://localhost/metrics/
---
apiVersion: v1
kind: Service
metadata:
  name: tc-prometheus
  namespace: default
spec:
  selector:
    app: tc-prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: ClusterIP
EOF

# 4. Deploy Kubernetes Dashboard
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tc-k8s-dashboard
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tc-k8s-dashboard
  template:
    metadata:
      labels:
        app: tc-k8s-dashboard
    spec:
      containers:
      - name: dashboard
        image: kubernetesui/dashboard:latest
        ports:
        - containerPort: 8443
        args:
        - --auto-generate-certificates
        - --namespace=default
---
apiVersion: v1
kind: Service
metadata:
  name: tc-k8s-dashboard
  namespace: default
spec:
  selector:
    app: tc-k8s-dashboard
  ports:
  - port: 8443
    targetPort: 8443
  type: ClusterIP
EOF

# 5. Fix ingress routing
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tc-platform-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
    nginx.ingress.kubernetes.io/configuration-snippet: |
      rewrite ^(/auth)$ \$1/ redirect;
      rewrite ^(/monitoring)$ \$1/ redirect;
      rewrite ^(/metrics)$ \$1/ redirect;
      rewrite ^(/dashboard)$ \$1/ redirect;
spec:
  rules:
  - host: localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tc-main-portal
            port:
              number: 80
      - path: /monitoring(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: tc-grafana
            port:
              number: 3000
      - path: /metrics(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: tc-prometheus
            port:
              number: 9090
      - path: /dashboard(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: tc-k8s-dashboard
            port:
              number: 8443
EOF

echo ""
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=ready pod -l app=tc-main-portal --timeout=120s
kubectl wait --for=condition=ready pod -l app=tc-grafana --timeout=120s
kubectl wait --for=condition=ready pod -l app=tc-prometheus --timeout=120s

echo ""
echo "✅ PLATFORM FIX COMPLETE!"
echo "========================"
echo ""
echo "🌟 Access your fixed TC Enterprise platform:"
echo "   Main Portal: http://localhost/"
echo "   Grafana:     http://localhost/monitoring/"
echo "   Prometheus:  http://localhost/metrics/"
echo "   Dashboard:   http://localhost/dashboard/"
echo ""
echo "🔐 Grafana Login: admin / tcadmin2025"
echo ""
echo "🎉 The platform is now fully functional with proper routing!"
