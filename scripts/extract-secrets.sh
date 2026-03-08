#!/usr/bin/env bash
set -euo pipefail

# Script to extract original secrets from sealed secrets in the cluster
# This recreates the secrets/ folder from the deployed secrets

if ! command -v kubectl 2>&1 >/dev/null; then
    echo "kubectl is not installed or not in PATH"
    exit 1
fi

if ! command -v yq 2>&1 >/dev/null; then
    echo "yq is not installed or not in PATH"
    echo "Install with: brew install yq"
    exit 1
fi

# Check if kubectl is connected to a cluster
if ! kubectl cluster-info &>/dev/null; then
    echo "kubectl is not connected to a cluster or cluster is not accessible"
    exit 1
fi

echo "Extracting secrets from cluster..."

# Create secrets directory if it doesn't exist
mkdir -p secrets

extracted_count=0

# Function to decode base64 values and convert to stringData
decode_and_convert_to_stringdata() {
    local temp_file="$1"
    
    # Check if the secret has a 'data' section
    if yq -e '.data' "$temp_file" >/dev/null 2>&1; then
        echo "    Converting base64 data to human-readable stringData..."
        
        # Create a temporary file for the conversion
        local new_file="${temp_file}.new"
        
        # Start building the new YAML
        {
            # Copy metadata and other sections (everything except data)
            yq 'del(.data)' "$temp_file"
            
            # Add stringData section header
            echo "stringData:"
            
            # Process each data entry and decode it
            yq -r '.data | to_entries[] | .key' "$temp_file" | while IFS= read -r key; do
                # Get the base64 value and decode it
                base64_value=$(yq -r ".data[\"$key\"]" "$temp_file")
                decoded_value=$(echo "$base64_value" | base64 -d 2>/dev/null || echo "$base64_value")
                
                # Escape any quotes in the decoded value and output
                escaped_value=$(printf '%s\n' "$decoded_value" | sed 's/\\/\\\\/g; s/"/\\"/g')
                echo "  $key: \"$escaped_value\""
            done
        } > "$new_file"
        
        # Replace the original file if conversion succeeded
        if [[ -f "$new_file" && -s "$new_file" ]]; then
            mv "$new_file" "$temp_file"
        else
            echo "    Warning: Failed to convert to stringData, keeping original format"
            [[ -f "$new_file" ]] && rm "$new_file"
        fi
    fi
}

# Function to extract secret data and create YAML file
extract_secret() {
    local secret_name="$1"
    local namespace="$2"
    local output_file="$3"
    
    echo "Extracting $secret_name from namespace $namespace..."
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" &>/dev/null; then
        echo "    Warning: Namespace $namespace not found in cluster"
        return 1
    fi
    
    # Check if secret exists in the cluster
    if ! kubectl get secret "$secret_name" -n "$namespace" &>/dev/null; then
        echo "    Warning: Secret $secret_name not found in namespace $namespace"
        return 1
    fi
    
    # Get the secret and clean it up
    local temp_file="secrets/${output_file}.tmp"
    
    kubectl get secret "$secret_name" -n "$namespace" -o yaml | \
        # Remove kubernetes metadata we don't want
        yq 'del(.metadata.uid, .metadata.resourceVersion, .metadata.selfLink, .metadata.creationTimestamp, .metadata.annotations, .metadata.managedFields, .metadata.ownerReferences)' | \
        # Remove status fields and other auto-generated fields
        yq 'del(.status)' > "$temp_file"
    
    # Convert base64 data to human-readable stringData
    decode_and_convert_to_stringdata "$temp_file"
    
    # Move to final location
    mv "$temp_file" "secrets/$output_file"
    
    echo "    ✓ Created secrets/$output_file"
    return 0
}

# Function to parse sealed secret files and extract info
parse_sealed_secret() {
    local sealed_file="$1"
    
    echo ""
    echo "📄 Parsing $sealed_file..."
    
    # Extract secret name and namespace from the sealed secret
    local secret_name
    local namespace
    
    secret_name=$(yq '.spec.template.metadata.name // .metadata.name' "$sealed_file" 2>/dev/null)
    namespace=$(yq '.spec.template.metadata.namespace // .metadata.namespace' "$sealed_file" 2>/dev/null)
    
    if [[ -z "$secret_name" || "$secret_name" == "null" ]]; then
        echo "    ❌ Could not determine secret name from $sealed_file"
        return 1
    fi
    
    if [[ -z "$namespace" || "$namespace" == "null" ]]; then
        echo "    ❌ Could not determine namespace from $sealed_file"
        return 1
    fi
    
    # Extract filename from path
    local filename
    filename=$(basename "$sealed_file")

    echo "    🔍 Found: $secret_name in namespace $namespace"

    if extract_secret "$secret_name" "$namespace" "$filename"; then
        ((extracted_count++))
    else
        echo "    ❌ Failed to extract secret"
    fi
}

# Auto-discover all sealed secret files
echo "🔍 Auto-discovering sealed secrets..."
total_files=0
for sealed_file in resources/*-secret.yaml openclaw/*secret*.yaml; do
    if [[ -f "$sealed_file" ]]; then
        ((total_files++))
        parse_sealed_secret "$sealed_file" || true  # Continue even if one fails
    fi
done

if [[ $total_files -eq 0 ]]; then
    echo "❌ No sealed secret files found"
    exit 1
fi

echo ""
if [[ $extracted_count -gt 0 ]]; then
    echo "✅ Successfully extracted $extracted_count out of $total_files secret(s) to the secrets/ folder"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Review the extracted secrets in the secrets/ folder"
    echo "   2. Run './scripts/seal-secrets.sh' to regenerate the sealed secrets"
    echo "   3. Compare with your existing sealed secrets to verify correctness"
else
    echo "❌ No secrets were successfully extracted"
    echo ""
    echo "💡 Possible reasons:"
    echo "   - The secrets don't exist in the current cluster"
    echo "   - The namespaces don't exist"
    echo "   - You don't have permission to read the secrets"
    echo "   - The cluster connection is not working"
    echo ""
    echo "🔧 Try running: kubectl get secrets --all-namespaces | grep -E '(argo|discord|tailscale|longhorn|monitoring)'"
    exit 1
fi
