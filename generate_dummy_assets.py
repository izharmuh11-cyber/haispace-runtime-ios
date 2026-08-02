import os
import json
from PIL import Image, ImageDraw

def create_package(name, slots, width, height):
    base_dir = os.path.join(os.path.dirname(__file__), 'docs', 'dummy_assets', name)
    os.makedirs(base_dir, exist_ok=True)
    
    # Create template.json
    template = {
        "canvas": {
            "width": width,
            "height": height,
            "dpi": 300,
            "orientation": "portrait" if height > width else "landscape"
        },
        "bleed": {"top": 30, "bottom": 30, "left": 30, "right": 30},
        "safeArea": {"top": 60, "bottom": 60, "left": 60, "right": 60},
        "slots": slots
    }
    with open(os.path.join(base_dir, 'template.json'), 'w') as f:
        json.dump(template, f, indent=2)
        
    # Create asset-manifest.json
    manifest = {
        "assetId": name,
        "type": "frame",
        "version": 1,
        "checksum": "dummy-checksum",
        "name": name.replace("-", " ").title(),
        "author": "Antigravity",
        "createdAt": "2026-08-02T00:00:00Z",
        "compatibility": {"minArchitectureVersion": 1},
        "files": ["asset-manifest.json", "frame.png", "template.json", "thumbnail.webp"]
    }
    with open(os.path.join(base_dir, 'asset-manifest.json'), 'w') as f:
        json.dump(manifest, f, indent=2)
        
    # Create frame.png (White background with transparent holes)
    img = Image.new("RGBA", (width, height), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    # Draw simple decorations or text
    draw.text((50, 50), f"Haispace - {name}", fill=(0,0,0,255))
    
    # Make holes transparent
    for slot in slots:
        x, y, w, h = slot['x'], slot['y'], slot['width'], slot['height']
        # Draw a slightly darker border around the slot
        draw.rectangle([x-2, y-2, x+w+2, y+h+2], outline=(200,200,200,255), width=2)
        # Clear the slot hole
        draw.rectangle([x, y, x+w, y+h], fill=(0, 0, 0, 0))
        
    img.save(os.path.join(base_dir, 'frame.png'))
    
    # Create thumbnail.webp
    thumb = img.resize((256, int(256 * height / width)))
    thumb.save(os.path.join(base_dir, 'thumbnail.webp'), format="WEBP")
    
    print(f"Generated {name} in {base_dir}")

# 1. Single Frame (1200x1800)
create_package("mock-single", [
    {"index": 0, "x": 100, "y": 150, "width": 1000, "height": 1300, "rotation": 0, "zIndex": -1}
], 1200, 1800)

# 2. Strip Frame (600x1800, 3 vertical slots)
create_package("mock-strip", [
    {"index": 0, "x": 50, "y": 100, "width": 500, "height": 450, "rotation": 0, "zIndex": -1},
    {"index": 1, "x": 50, "y": 600, "width": 500, "height": 450, "rotation": 0, "zIndex": -1},
    {"index": 2, "x": 50, "y": 1100, "width": 500, "height": 450, "rotation": 0, "zIndex": -1}
], 600, 1800)

# 3. Grid Frame (1200x1200, 2x2 grid)
create_package("mock-grid", [
    {"index": 0, "x": 100, "y": 100, "width": 450, "height": 450, "rotation": 0, "zIndex": -1},
    {"index": 1, "x": 650, "y": 100, "width": 450, "height": 450, "rotation": 0, "zIndex": -1},
    {"index": 2, "x": 100, "y": 650, "width": 450, "height": 450, "rotation": 0, "zIndex": -1},
    {"index": 3, "x": 650, "y": 650, "width": 450, "height": 450, "rotation": 0, "zIndex": -1}
], 1200, 1200)

