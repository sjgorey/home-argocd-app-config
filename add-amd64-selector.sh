#!/bin/bash

# Script to add AMD64 nodeSelector to all Deployments and StatefulSets

set -e

echo "Adding AMD64 nodeSelector to Deployments and StatefulSets..."

# Function to add nodeSelector if it doesn't exist
add_node_selector() {
    local file="$1"
    
    # Skip if file already has amd64 selector
    if grep -q "kubernetes.io/arch: amd64" "$file"; then
        echo "  ✓ $file already has AMD64 selector"
        return
    fi
    
    # Skip if file has arm64 selector (keep those as-is)
    if grep -q "kubernetes.io/arch: arm64" "$file"; then
        echo "  - $file has ARM64 selector, changing to AMD64"
        sed -i 's/kubernetes.io\/arch: arm64/kubernetes.io\/arch: amd64/' "$file"
        return
    fi
    
    # Check if file has a nodeSelector section
    if grep -q "nodeSelector:" "$file"; then
        # Check if it's empty or has other selectors
        if grep -A1 "nodeSelector:" "$file" | grep -q "kubernetes.io/"; then
            echo "  ✓ $file already has nodeSelector"
            return
        else
            # Add arch selector to existing nodeSelector
            echo "  + Adding to existing nodeSelector in $file"
            sed -i '/nodeSelector:/a\        kubernetes.io/arch: amd64' "$file"
        fi
    else
        # Need to add nodeSelector section
        # Find the spec: section under template: and add nodeSelector
        if grep -q "template:" "$file"; then
            echo "  + Adding nodeSelector to $file"
            # Add after 'spec:' that comes after 'template:'
            awk '/template:/{p=1} p&&/^      spec:/{print; print "      nodeSelector:"; print "        kubernetes.io/arch: amd64"; p=0; next} 1' "$file" > "$file.tmp"
            mv "$file.tmp" "$file"
        fi
    fi
}

# Process all Deployment files
echo ""
echo "Processing Deployments..."
find infrastructure -name "*.yaml" -type f -exec grep -l "kind: Deployment" {} \; | while read file; do
    # Skip large generated files (they need special handling)
    if [[ "$file" == *"strimzi-kafka.yaml"* ]] || \
       [[ "$file" == *"prometheus-stack.yaml"* ]] || \
       [[ "$file" == *"longhorn.yaml"* ]] || \
       [[ "$file" == *"recommended.yaml"* ]]; then
        echo "  ⊘ Skipping large file: $file (handle manually)"
        continue
    fi
    
    add_node_selector "$file"
done

# Process all StatefulSet files
echo ""
echo "Processing StatefulSets..."
find infrastructure -name "*.yaml" -type f -exec grep -l "kind: StatefulSet" {} \; | while read file; do
    # Skip large generated files
    if [[ "$file" == *"loki-stack.yaml"* ]]; then
        echo "  ⊘ Skipping large file: $file (handle manually)"
        continue
    fi
    
    add_node_selector "$file"
done

echo ""
echo "✓ Done! Please review the changes with 'git diff'"
echo ""
echo "Files that need manual review:"
echo "  - infrastructure/kafka/strimzi-kafka.yaml"
echo "  - infrastructure/prometheus/prometheus-stack.yaml"
echo "  - infrastructure/longhorn/longhorn.yaml"
echo "  - infrastructure/loki/loki-stack.yaml"
echo "  - infrastructure/dashboard/recommended.yaml"
