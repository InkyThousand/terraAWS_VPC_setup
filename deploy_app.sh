#!/bin/bash
set -e

# Get the bastion host IP
BASTION_IP=$(terraform output -raw bastion_public_ip)

# Get the web app instance IPs
WEB_APP_IPS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=WebApp-ASG-dev" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].PrivateIpAddress" \
  --output text)

# Get S3 bucket and DynamoDB table names
S3_BUCKET=$(terraform output -raw image_storage_bucket)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table)
AWS_REGION=$(aws configure get region)

echo "Deploying application to web app instances..."
echo "S3 Bucket: $S3_BUCKET"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo "AWS Region: $AWS_REGION"

# Create application files
mkdir -p deploy_tmp
cd deploy_tmp

# Create index.php with the fixed code
cat > index.php << EOF
<?php
// Enable error reporting for debugging
ini_set('display_errors', 1);
error_reporting(E_ALL);

// AWS Region and resource names
\$region = '$AWS_REGION';
\$bucketName = '$S3_BUCKET';
\$tableName = '$DYNAMODB_TABLE';
?>
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
    </style>
</head>
<body>
    <h1>Image Analysis Application</h1>
    
    <form action="upload.php" method="post" enctype="multipart/form-data">
        <h2>Upload an Image for Analysis</h2>
        <input type="file" name="imageFile" accept="image/jpeg,image/png,image/jpg" required>
        <p>Supported formats: JPG, JPEG, PNG</p>
        <button type="submit">Upload & Analyze</button>
    </form>

    <h2>Recent Analyses</h2>
    <div class="images">
        <?php
        // Check if AWS SDK is available
        if (file_exists('vendor/autoload.php')) {
            require 'vendor/autoload.php';
            
            try {
                // Create DynamoDB client
                \$dynamoDb = new Aws\DynamoDb\DynamoDbClient([
                    'version' => 'latest',
                    'region'  => \$region
                ]);
                
                // Create S3 client
                \$s3 = new Aws\S3\S3Client([
                    'version' => 'latest',
                    'region'  => \$region
                ]);
                
                // Scan the table for recent items (limited to 10)
                \$result = \$dynamoDb->scan([
                    'TableName' => \$tableName,
                    'Limit' => 10
                ]);
                
                if (isset(\$result['Items']) && count(\$result['Items']) > 0) {
                    foreach (\$result['Items'] as \$item) {
                        \$imageId = \$item['image_id']['S'];
                        \$s3Key = \$item['s3_key']['S'];
                        \$timestamp = \$item['timestamp']['S'];
                        \$labels = isset(\$item['labels']['L']) ? \$item['labels']['L'] : [];
                        \$hasFaces = isset(\$item['has_faces']['BOOL']) ? \$item['has_faces']['BOOL'] : false;
                        \$faceCount = isset(\$item['face_count']['N']) ? \$item['face_count']['N'] : 0;
                        \$isInappropriate = isset(\$item['is_inappropriate']['BOOL']) ? \$item['is_inappropriate']['BOOL'] : false;
                        
                        // Generate a pre-signed URL for the image (valid for 1 hour)
                        // Use the correct method with array parameters
                        \$cmd = \$s3->getCommand('GetObject', [
                            'Bucket' => \$bucketName,
                            'Key'    => \$s3Key
                        ]);
                        \$request = \$s3->createPresignedRequest(\$cmd, '+1 hour');
                        \$imageUrl = (string) \$request->getUri();
                        
                        echo '<div class="image-card">';
                        echo '<h3>Image: ' . htmlspecialchars(\$imageId) . '</h3>';
                        echo '<img src="' . htmlspecialchars(\$imageUrl) . '" alt="Analyzed Image">';
                        echo '<p><strong>Analyzed:</strong> ' . htmlspecialchars(date('Y-m-d H:i:s', strtotime(\$timestamp))) . '</p>';
                        
                        echo '<p><strong>Labels:</strong> ';
                        if (!empty(\$labels)) {
                            foreach (\$labels as \$label) {
                                echo '<span class="label">' . htmlspecialchars(\$label['S']) . '</span> ';
                            }
                        } else {
                            echo 'No labels detected';
                        }
                        echo '</p>';
                        
                        if (\$hasFaces) {
                            echo '<p><span class="label face">Faces detected: ' . htmlspecialchars(\$faceCount) . '</span></p>';
                        }
                        if (\$isInappropriate) {
                            echo '<p><span class="label warning">Content warning</span></p>';
                        }
                        
                        echo '</div>';
                    }
                } else {
                    echo '<p>No images have been analyzed yet. Upload an image to get started!</p>';
                }
                
            } catch (Exception \$e) {
                echo '<p>Error: ' . htmlspecialchars(\$e->getMessage()) . '</p>';
            }
        } else {
            // AWS SDK not available, show local uploads
            echo '<p>AWS SDK not available. Showing local uploads only.</p>';
            
            // Display locally uploaded images
            \$uploadDir = 'uploads/';
            if (is_dir(\$uploadDir)) {
                \$files = scandir(\$uploadDir);
                \$imageFiles = array_filter(\$files, function(\$file) {
                    \$ext = strtolower(pathinfo(\$file, PATHINFO_EXTENSION));
                    return in_array(\$ext, ['jpg', 'jpeg', 'png']) && \$file != '.' && \$file != '..';
                });
                
                if (count(\$imageFiles) > 0) {
                    foreach (\$imageFiles as \$file) {
                        \$filePath = \$uploadDir . \$file;
                        \$imageId = pathinfo(\$file, PATHINFO_FILENAME);
                        
                        echo '<div class="image-card">';
                        echo '<h3>Image: ' . htmlspecialchars(\$imageId) . '</h3>';
                        echo '<img src="' . htmlspecialchars(\$filePath) . '" alt="Uploaded Image">';
                        echo '<p><strong>Uploaded:</strong> ' . htmlspecialchars(date('Y-m-d H:i:s', filemtime(\$filePath))) . '</p>';
                        echo '<p>Analysis pending...</p>';
                        echo '</div>';
                    }
                } else {
                    echo '<p>No images have been uploaded yet.</p>';
                }
            } else {
                echo '<p>Upload directory not found.</p>';
            }
        }
        ?>
    </div>
</body>
</html>
EOF

# Create upload.php
cat > upload.php << EOF
<?php
// Enable error reporting for debugging
ini_set('display_errors', 1);
error_reporting(E_ALL);

// AWS Region and resource names
\$region = '$AWS_REGION';
\$bucketName = '$S3_BUCKET';

// Function to generate a unique ID
function generateUniqueId() {
    return uniqid() . '-' . bin2hex(random_bytes(4));
}

// Function to get file extension
function getFileExtension(\$filename) {
    return strtolower(pathinfo(\$filename, PATHINFO_EXTENSION));
}

try {
    // Handle file upload
    if (\$_SERVER["REQUEST_METHOD"] == "POST" && isset(\$_FILES["imageFile"])) {
        \$file = \$_FILES["imageFile"];
        
        // Check for errors
        if (\$file["error"] !== UPLOAD_ERR_OK) {
            throw new Exception("Upload failed with error code " . \$file["error"]);
        }
        
        // Validate file type
        \$allowedTypes = ['image/jpeg', 'image/jpg', 'image/png'];
        if (!in_array(\$file["type"], \$allowedTypes)) {
            throw new Exception("Invalid file type. Only JPG, JPEG, and PNG are allowed.");
        }
        
        // Generate a unique ID and file path
        \$imageId = generateUniqueId();
        \$extension = getFileExtension(\$file["name"]);
        \$localPath = "uploads/{\$imageId}.{\$extension}";
        
        // Create uploads directory if it doesn't exist
        if (!is_dir('uploads')) {
            mkdir('uploads', 0777, true);
        }
        
        // Save file locally first
        if (!move_uploaded_file(\$file["tmp_name"], \$localPath)) {
            throw new Exception("Failed to save the uploaded file locally");
        }
        
        // Check if AWS SDK is available
        if (file_exists('vendor/autoload.php')) {
            require 'vendor/autoload.php';
            
            try {
                // Create S3 client
                \$s3 = new Aws\S3\S3Client([
                    'version' => 'latest',
                    'region'  => \$region
                ]);
                
                // Upload to S3
                \$key = "uploads/{\$imageId}.{\$extension}";
                \$result = \$s3->putObject([
                    'Bucket' => \$bucketName,
                    'Key'    => \$key,
                    'SourceFile' => \$localPath,
                    'ContentType' => \$file["type"]
                ]);
                
                echo "<h1>Upload Successful!</h1>";
                echo "<p>File uploaded to S3 for analysis.</p>";
                echo "<p>The analysis results will appear on the main page shortly.</p>";
                echo "<p><a href='index.php'>Back to home</a></p>";
            } catch (Exception \$e) {
                echo "<h1>S3 Upload Failed</h1>";
                echo "<p>Error: " . htmlspecialchars(\$e->getMessage()) . "</p>";
                echo "<p>The file was saved locally but could not be uploaded to S3 for analysis.</p>";
                echo "<p><a href='index.php'>Back to home</a></p>";
            }
        } else {
            echo "<h1>Upload Successful (Local Only)</h1>";
            echo "<p>The file was saved locally, but AWS SDK is not available for S3 upload.</p>";
            echo "<p><a href='index.php'>Back to home</a></p>";
        }
    } else {
        throw new Exception("No file uploaded or invalid request method");
    }
} catch (Exception \$e) {
    echo "<h1>Error</h1>";
    echo "<p>" . htmlspecialchars(\$e->getMessage()) . "</p>";
    echo "<p><a href='index.php'>Back to home</a></p>";
}
?>
EOF

# Create a script to install AWS SDK
cat > install_aws_sdk.sh << 'EOF'
#!/bin/bash
set -e

echo "Installing AWS SDK for PHP..."
cd /var/www/html

# Install required packages
sudo dnf install -y php-cli php-json php-xml php-curl php-zip unzip

# Install composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Create composer.json
cat > composer.json << 'COMPOSER'
{
    "require": {
        "aws/aws-sdk-php": "^3.0"
    }
}
COMPOSER

# Install AWS SDK using composer
composer install

echo "AWS SDK installed successfully!"
EOF

# Create a deployment package
tar -czf app_deploy.tar.gz index.php upload.php install_aws_sdk.sh

# Deploy to each web app instance
for IP in $WEB_APP_IPS; do
  echo "Deploying to $IP..."
  
  # Copy the deployment package to the bastion host
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/bastion_key \
    app_deploy.tar.gz ec2-user@$BASTION_IP:/tmp/
  
  # Copy the private key to the bastion host (temporarily)
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/bastion_key \
    ~/.ssh/bastion_key ec2-user@$BASTION_IP:/tmp/bastion_key_temp
  
  # Create a script on the bastion host to deploy to the web app instance
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/bastion_key ec2-user@$BASTION_IP << EOF
    # Set proper permissions for the key
    chmod 600 /tmp/bastion_key_temp
    
    # Create deployment script
    cat > /tmp/deploy_to_webapp.sh << 'SCRIPT'
#!/bin/bash
set -e
TARGET_IP="$IP"
echo "Deploying from bastion to \$TARGET_IP..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /tmp/bastion_key_temp /tmp/app_deploy.tar.gz ec2-user@\$TARGET_IP:/tmp/
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /tmp/bastion_key_temp ec2-user@\$TARGET_IP << 'ENDWEBSSH'
cd /tmp
tar -xzf app_deploy.tar.gz
sudo cp index.php upload.php /var/www/html/
sudo chmod +x install_aws_sdk.sh
sudo ./install_aws_sdk.sh
sudo mkdir -p /var/www/html/uploads
sudo chown -R apache:apache /var/www/html/
sudo chmod -R 755 /var/www/html/
sudo chmod 777 /var/www/html/uploads
ENDWEBSSH
echo "Deployment to \$TARGET_IP complete!"
SCRIPT
    chmod +x /tmp/deploy_to_webapp.sh
    /tmp/deploy_to_webapp.sh
    
    # Clean up the temporary key
    rm -f /tmp/bastion_key_temp
EOF

  echo "Deployment to $IP complete!"
done

# Clean up
cd ..
rm -rf deploy_tmp

echo "Application deployment complete!"
