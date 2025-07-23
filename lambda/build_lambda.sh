#!/bin/bash

# Navigate to the Lambda directory
cd "$(dirname "$0")"

# Install dependencies
npm install

# Create a zip file
zip -r media_processing.zip index.js node_modules

echo "Lambda package created: media_processing.zip"
