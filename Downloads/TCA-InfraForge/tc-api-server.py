from flask import Flask, jsonify, request
import subprocess
import json
import os
from datetime import datetime

app = Flask(__name__)

# TC Enterprise branding
TC_INFO = {
    "platform": "TC Enterprise DevOps Platform™",
    "owner": "Temitayo Charles",
    "version": "1.0",
    "trademark": "© 2025 Temitayo Charles. All Rights Reserved.",
    "domain": "temitayocharles.online"
}

@app.route('/', methods=['GET'])
def platform_info():
    return jsonify({
        "message": "Welcome to TC Enterprise DevOps Platform™ API",
        "owner": TC_INFO["owner"],
        "platform": TC_INFO["platform"],
        "version": TC_INFO["version"],
        "trademark": TC_INFO["trademark"],
        "domain": TC_INFO["domain"],
        "timestamp": datetime.now().isoformat(),
        "endpoints": [
            "/health",
            "/services",
            "/registry",
            "/monitoring",
            "/security"
        ]
    })

@app.route('/health', methods=['GET'])
def health_check():
    try:
        # Check Kubernetes services
        result = subprocess.run(['kubectl', 'get', 'services', '--no-headers'], 
                              capture_output=True, text=True)
        services = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
        
        return jsonify({
            "status": "healthy",
            "platform": TC_INFO["platform"],
            "owner": TC_INFO["owner"],
            "services_count": services,
            "timestamp": datetime.now().isoformat(),
            "uptime": "operational"
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "message": str(e),
            "timestamp": datetime.now().isoformat()
        }), 500

@app.route('/services', methods=['GET'])
def get_services():
    try:
        result = subprocess.run(['kubectl', 'get', 'services', '-o', 'json'], 
                              capture_output=True, text=True)
        services_data = json.loads(result.stdout)
        
        tc_services = []
        for service in services_data.get('items', []):
            tc_services.append({
                "name": service['metadata']['name'],
                "type": service['spec']['type'],
                "ports": service['spec']['ports'],
                "cluster_ip": service['spec']['clusterIP']
            })
        
        return jsonify({
            "platform": TC_INFO["platform"], 
            "owner": TC_INFO["owner"],
            "services": tc_services,
            "total_count": len(tc_services),
            "timestamp": datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }), 500

@app.route('/registry', methods=['GET'])
def registry_status():
    try:
        # Check registry images
        result = subprocess.run(['docker', 'images', 'localhost:5000/*', '--format', 'json'],
                              capture_output=True, text=True)
        
        images = []
        for line in result.stdout.strip().split('\n'):
            if line:
                try:
                    img_data = json.loads(line)
                    images.append({
                        "repository": img_data.get('Repository', 'unknown'),
                        "tag": img_data.get('Tag', 'unknown'),
                        "size": img_data.get('Size', 'unknown'),
                        "created": img_data.get('CreatedSince', 'unknown')
                    })
                except:
                    continue
        
        return jsonify({
            "platform": TC_INFO["platform"],
            "registry": "localhost:5000",
            "images": images,
            "total_images": len(images),
            "timestamp": datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }), 500

@app.route('/monitoring', methods=['GET'])
def monitoring_status():
    return jsonify({
        "platform": TC_INFO["platform"],
        "monitoring": {
            "prometheus": "http://localhost/prometheus/",
            "grafana": "http://localhost/grafana/",
            "status": "operational"
        },
        "dashboards": [
            "TC Enterprise Executive Dashboard",
            "Platform Health Overview",
            "Resource Utilization"
        ],
        "timestamp": datetime.now().isoformat()
    })

@app.route('/security', methods=['GET'])
def security_status():
    return jsonify({
        "platform": TC_INFO["platform"],
        "security": {
            "policy": "All services ClusterIP only",
            "reverse_proxy": "NGINX Ingress Controller",
            "ssl": "Let's Encrypt certificates",
            "scanning": "Trivy security scanner",
            "compliance": "SOC2/ISO27001 ready"
        },
        "trademark": TC_INFO["trademark"],
        "timestamp": datetime.now().isoformat()
    })

if __name__ == '__main__':
    print(f"🚀 Starting {TC_INFO['platform']} API")
    print(f"👑 Owner: {TC_INFO['owner']}")
    print(f"🌐 Domain: {TC_INFO['domain']}")
    app.run(host='0.0.0.0', port=8080, debug=False)
