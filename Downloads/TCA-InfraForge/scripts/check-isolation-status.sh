#!/bin/bash

# FoodShare Isolation Status Checker
# Shows the complete separation between lab and application

echo "🔍 FoodShare Isolation Status Report"
echo "===================================="
echo ""

LAB_DIR="/Volumes/256-B/tc-enterprise-devops-platform"
ISOLATED_DIR="/Volumes/256-B/foodshare-app"

echo "📁 LAB DIRECTORY: $LAB_DIR"
echo "=========================="
if [ -d "$LAB_DIR" ]; then
    echo "✅ Lab directory exists"

    # Check for FoodShare files in lab
    if [ -d "$LAB_DIR/foodshare" ]; then
        echo "❌ FoodShare app directory still exists in lab"
    else
        echo "✅ FoodShare app directory removed from lab"
    fi

    if [ -d "$LAB_DIR/foodshare-public-repo" ]; then
        echo "❌ FoodShare public repo still exists in lab"
    else
        echo "✅ FoodShare public repo removed from lab"
    fi

    if [ -f "$LAB_DIR/foodshare-port-forward.service" ]; then
        echo "❌ FoodShare service file still exists in lab"
    else
        echo "✅ FoodShare service file removed from lab"
    fi

    # Show remaining lab files
    echo ""
    echo "📋 Remaining lab files:"
    ls -la "$LAB_DIR" | grep -E '\.(yaml|sh|py|md)$' | head -10
    echo "... (and more lab infrastructure files)"
else
    echo "❌ Lab directory not found"
fi

echo ""
echo "📁 ISOLATED APPLICATION: $ISOLATED_DIR"
echo "======================================"
if [ -d "$ISOLATED_DIR" ]; then
    echo "✅ Isolated FoodShare directory exists"

    if [ -d "$ISOLATED_DIR/app" ]; then
        echo "✅ Application code directory exists"
        echo "   Files: $(ls "$ISOLATED_DIR/app" | wc -l) application files"
    else
        echo "❌ Application code directory missing"
    fi

    if [ -d "$ISOLATED_DIR/docs" ]; then
        echo "✅ Documentation directory exists"
    else
        echo "❌ Documentation directory missing"
    fi

    if [ -d "$ISOLATED_DIR/demo" ]; then
        echo "✅ Demo materials directory exists"
    else
        echo "❌ Demo materials directory missing"
    fi

    if [ -d "$ISOLATED_DIR/public" ]; then
        echo "✅ Public repository files exist"
    else
        echo "❌ Public repository files missing"
    fi
else
    echo "❌ Isolated FoodShare directory not found"
fi

echo ""
echo "🎯 ISOLATION STATUS:"
echo "==================="
if [ ! -d "$LAB_DIR/foodshare" ] && [ ! -d "$LAB_DIR/foodshare-public-repo" ] && [ ! -f "$LAB_DIR/foodshare-port-forward.service" ] && [ -d "$ISOLATED_DIR" ]; then
    echo "✅ COMPLETE ISOLATION ACHIEVED!"
    echo "   • FoodShare removed from lab ✅"
    echo "   • Application isolated ✅"
    echo "   • Independent development ready ✅"
else
    echo "⚠️  PARTIAL ISOLATION - Some files may still be mixed"
fi

echo ""
echo "🚀 NEXT STEPS:"
echo "=============="
echo "1. Work on FoodShare: cd $ISOLATED_DIR"
echo "2. Work on Lab: cd $LAB_DIR"
echo "3. Deploy FoodShare to lab: Use isolation manager script"
echo "4. Push FoodShare to GitHub: Independent repository"
echo ""
echo "📝 Remember:"
echo "   • Lab = Infrastructure only"
echo "   • FoodShare = Application only"
echo "   • No more mixed changes! 🎉"
