#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1
set -x

echo "=== WEB APP USER DATA SCRIPT START ==="
echo "Script started at: $(date)"

# Update and install packages
dnf update -y
dnf install -y python3 python3-pip awscli

# Install Python packages
pip3 install flask boto3 gunicorn

# Create directories and set permissions
mkdir -p /var/www/html/uploads
chmod 777 /var/www/html/uploads

# Create Python app directory
mkdir -p /opt/webapp
cd /opt/webapp

# Create Flask application
cat > /opt/webapp/app.py << 'EOF'
from flask import Flask, render_template, request, redirect, url_for, flash
import boto3
import uuid
from datetime import datetime
import os

app = Flask(__name__)
app.secret_key = 'your-secret-key'

# AWS configuration
REGION = '${AWS_REGION}'
BUCKET_NAME = '${S3_BUCKET}'
TABLE_NAME = '${DYNAMODB_TABLE}'

# Initialize AWS clients using instance role
s3 = boto3.client('s3', region_name=REGION)
dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(TABLE_NAME)

@app.route('/')
def index():
    try:
        # Get recent analyses from DynamoDB
        response = table.scan(Limit=10)
        items = response.get('Items', [])
        
        # Use direct S3 URLs for public access
        for item in items:
            if 's3_key' in item:
                item['image_url'] = f"https://{BUCKET_NAME}.s3.{REGION}.amazonaws.com/{item['s3_key']}"
        
        return render_template('index.html', items=items)
    except Exception as e:
        return render_template('index.html', items=[], error=str(e))

@app.route('/upload', methods=['POST'])
def upload():
    if 'file' not in request.files:
        flash('No file selected')
        return redirect(url_for('index'))
    
    file = request.files['file']
    if file.filename == '':
        flash('No file selected')
        return redirect(url_for('index'))
    
    if file and allowed_file(file.filename):
        try:
            # Generate unique filename
            file_ext = file.filename.rsplit('.', 1)[1].lower()
            filename = f"uploads/{uuid.uuid4()}.{file_ext}"
            
            # Upload to S3
            content_type = file.content_type or 'image/jpeg'
            s3.upload_fileobj(
                file,
                BUCKET_NAME,
                filename,
                ExtraArgs={
                    'ContentType': content_type,
                    'CacheControl': 'max-age=3600'
                }
            )
            
            flash('Image uploaded successfully! Analysis in progress...')
        except Exception as e:
            flash(f'Upload failed: {str(e)}')
    else:
        flash('Invalid file type. Only JPG, JPEG, PNG allowed.')
    
    return redirect(url_for('index'))

@app.route('/health')
def health():
    return 'OK'

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in {'jpg', 'jpeg', 'png'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# Create templates directory
mkdir -p /opt/webapp/templates

# Create HTML template
cat > /opt/webapp/templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Image Analysis App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        form { margin-bottom: 20px; padding: 15px; border: 1px solid #ddd; }
        .images { display: flex; flex-wrap: wrap; }
        .image-card { margin: 10px; padding: 10px; border: 1px solid #ccc; width: 300px; }
        .image-card img { max-width: 100%; max-height: 200px; }
        .label { display: inline-block; margin: 2px; padding: 2px 6px; background: #eee; border-radius: 3px; }
        .face { background: #d4edda; }
        .warning { background: #f8d7da; }
        .flash { padding: 10px; margin: 10px 0; border-radius: 4px; }
        .flash.success { background: #d4edda; color: #155724; }
        .flash.error { background: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <h1>Image Analysis Application</h1>
    
    {% with messages = get_flashed_messages() %}
        {% if messages %}
            {% for message in messages %}
                <div class="flash success">{{ message }}</div>
            {% endfor %}
        {% endif %}
    {% endwith %}
    
    <form action="{{ url_for('upload') }}" method="post" enctype="multipart/form-data">
        <h2>Upload an Image for Analysis</h2>
        <input type="file" name="file" accept="image/jpeg,image/png,image/jpg" required>
        <p>Supported formats: JPG, JPEG, PNG</p>
        <button type="submit">Upload & Analyze</button>
    </form>

    <h2>Recent Analyses</h2>
    <div class="images">
        {% if error %}
            <p>Error: {{ error }}</p>
        {% elif items %}
            {% for item in items %}
                <div class="image-card">
                    <h3>Image: {{ item.image_id }}</h3>
                    {% if item.image_url %}
                        <img src="{{ item.image_url }}" alt="Analyzed Image">
                    {% endif %}
                    <p><strong>Analyzed:</strong> {{ item.timestamp }}</p>
                    
                    <p><strong>Labels:</strong>
                    {% if item.labels %}
                        {% for label in item.labels %}
                            <span class="label">{{ label }}</span>
                        {% endfor %}
                    {% else %}
                        No labels detected
                    {% endif %}
                    </p>
                    
                    {% if item.has_faces %}
                        <p><span class="label face">Faces detected: {{ item.face_count or 0 }}</span></p>
                    {% endif %}
                    {% if item.is_inappropriate %}
                        <p><span class="label warning">Content warning</span></p>
                    {% endif %}
                </div>
            {% endfor %}
        {% else %}
            <p>No images have been analyzed yet. Upload an image to get started!</p>
        {% endif %}
    </div>
</body>
</html>
EOF

# Create systemd service for Flask app
cat > /etc/systemd/system/webapp.service << 'EOF'
[Unit]
Description=Flask Web Application
After=network.target

[Service]
User=root
WorkingDirectory=/opt/webapp
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Install and configure nginx
dnf install -y nginx

# Configure nginx to proxy to Flask
cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        location / {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        location /health {
            proxy_pass http://127.0.0.1:5000/health;
        }
    }
}
NGINX_EOF

# Start nginx
systemctl enable nginx
systemctl start nginx

# Set permissions and start service
chmod +x /opt/webapp/app.py
systemctl daemon-reload
systemctl enable webapp
systemctl start webapp

echo "=== WEB APP USER DATA SCRIPT COMPLETED ==="
