#!/usr/bin/env python3
"""
YOLO-World + MobileSAM Model Conversion Script

This script converts YOLO-World and MobileSAM models to Core ML format
for on-device inference on iOS.

Usage:
    # Install dependencies first:
    pip install ultralytics coremltools torch transformers

    # Run conversion:
    python convert_models.py

Output:
    - YOLOWorldS.mlpackage (or .mlmodelc after Xcode compilation)
    - TextEmbeddings.json (pre-computed CLIP embeddings)
    - MobileSAM_Encoder.mlpackage (optional)
    - MobileSAM_Decoder.mlpackage (optional)
"""

import os
import json
import argparse
from pathlib import Path


def convert_yoloworld(output_dir: Path, model_size: str = "s", imgsz: int = 640):
    """Convert YOLO-World to Core ML format."""
    print(f"\n{'='*50}")
    print(f"Converting YOLO-World-{model_size.upper()}")
    print(f"{'='*50}")

    try:
        from ultralytics import YOLO
    except ImportError:
        print("ERROR: ultralytics not installed. Run: pip install ultralytics")
        return None

    # Load YOLO-World model
    model_name = f"yolov8{model_size}-worldv2.pt"
    print(f"Loading {model_name}...")
    model = YOLO(model_name)

    # Set classes for open-vocabulary detection
    # These are the classes the model will detect
    # You can change these or add more
    classes = [
        "person", "face", "hand",
        "dog", "cat", "bird", "horse",
        "car", "bicycle", "motorcycle", "bus", "truck",
        "cup", "bottle", "phone", "laptop", "keyboard", "mouse",
        "bag", "backpack", "handbag", "suitcase",
        "hat", "shoe", "glasses", "watch",
        "chair", "couch", "bed", "table", "desk",
        "flower", "plant", "tree",
        "food", "pizza", "burger", "sandwich", "cake", "coffee",
        "book", "pen", "scissors",
        "ball", "frisbee", "skateboard", "surfboard",
    ]

    print(f"Setting {len(classes)} detection classes...")
    model.set_classes(classes)

    # Export to Core ML
    print(f"Exporting to Core ML (imgsz={imgsz})...")
    output_path = model.export(
        format="coreml",
        imgsz=imgsz,
        nms=True,  # Include NMS in model
        half=True,  # FP16 for smaller size
    )

    if output_path:
        # Move to output directory
        import shutil
        output_name = f"YOLOWorld{model_size.upper()}.mlpackage"
        dest_path = output_dir / output_name
        if Path(output_path).exists():
            if dest_path.exists():
                shutil.rmtree(dest_path)
            shutil.move(output_path, dest_path)
            print(f"✅ Saved: {dest_path}")
            return dest_path

    print("❌ Export failed")
    return None


def generate_text_embeddings(output_dir: Path):
    """Pre-compute CLIP text embeddings for common prompts."""
    print(f"\n{'='*50}")
    print("Generating Text Embeddings")
    print(f"{'='*50}")

    try:
        import torch
        from transformers import CLIPTokenizer, CLIPTextModel
    except ImportError:
        print("ERROR: transformers not installed. Run: pip install transformers torch")
        return None

    # Common prompts to pre-compute
    prompts = [
        # People
        "person", "people", "man", "woman", "child", "baby", "face", "hand", "head",

        # Animals
        "dog", "cat", "bird", "fish", "horse", "cow", "sheep", "elephant", "bear",

        # Vehicles
        "car", "truck", "bus", "motorcycle", "bicycle", "airplane", "boat", "train",

        # Electronics
        "phone", "laptop", "computer", "keyboard", "mouse", "tv", "camera",

        # Everyday objects
        "cup", "bottle", "glass", "plate", "bowl", "fork", "knife", "spoon",
        "bag", "backpack", "purse", "wallet", "umbrella",
        "book", "pen", "pencil", "scissors", "paper",
        "chair", "table", "desk", "couch", "bed",

        # Accessories
        "hat", "cap", "glasses", "sunglasses", "watch", "shoe", "shirt", "pants",

        # Food
        "food", "pizza", "burger", "sandwich", "salad", "cake", "coffee", "fruit", "apple", "banana",

        # Nature
        "flower", "plant", "tree", "leaf", "grass", "sky", "cloud", "sun", "moon",

        # Sports
        "ball", "basketball", "football", "tennis", "frisbee", "skateboard", "surfboard",
    ]

    print(f"Loading CLIP model...")
    tokenizer = CLIPTokenizer.from_pretrained("openai/clip-vit-base-patch32")
    text_encoder = CLIPTextModel.from_pretrained("openai/clip-vit-base-patch32")
    text_encoder.eval()

    embeddings = {}

    print(f"Computing embeddings for {len(prompts)} prompts...")
    with torch.no_grad():
        for prompt in prompts:
            inputs = tokenizer(prompt, return_tensors="pt", padding=True, truncation=True)
            outputs = text_encoder(**inputs)
            # Use pooled output or mean of last hidden state
            embedding = outputs.last_hidden_state.mean(dim=1).squeeze().tolist()
            embeddings[prompt.lower()] = embedding

    # Save to JSON
    output_path = output_dir / "TextEmbeddings.json"
    with open(output_path, "w") as f:
        json.dump(embeddings, f, indent=2)

    print(f"✅ Saved: {output_path}")
    print(f"   {len(embeddings)} embeddings, {os.path.getsize(output_path) / 1024:.1f} KB")

    return output_path


def convert_mobilesam(output_dir: Path):
    """Convert MobileSAM to Core ML format."""
    print(f"\n{'='*50}")
    print("Converting MobileSAM")
    print(f"{'='*50}")

    try:
        import torch
        import coremltools as ct
    except ImportError:
        print("ERROR: Required packages not installed.")
        print("Run: pip install torch coremltools")
        return None

    # Check if mobile_sam is installed
    try:
        from mobile_sam import sam_model_registry, SamPredictor
    except ImportError:
        print("⚠️ MobileSAM not installed. Skipping...")
        print("To install: pip install git+https://github.com/ChaoningZhang/MobileSAM.git")
        return None

    # Download checkpoint if needed
    checkpoint_path = Path("mobile_sam.pt")
    if not checkpoint_path.exists():
        print("Downloading MobileSAM checkpoint...")
        import urllib.request
        url = "https://github.com/ChaoningZhang/MobileSAM/raw/master/weights/mobile_sam.pt"
        urllib.request.urlretrieve(url, checkpoint_path)

    print("Loading MobileSAM...")
    sam = sam_model_registry["vit_t"](checkpoint=str(checkpoint_path))
    sam.eval()

    # Export Image Encoder
    print("Converting image encoder...")

    class ImageEncoderWrapper(torch.nn.Module):
        def __init__(self, encoder):
            super().__init__()
            self.encoder = encoder

        def forward(self, x):
            return self.encoder(x)

    encoder = ImageEncoderWrapper(sam.image_encoder)
    encoder.eval()

    try:
        # Trace the encoder
        dummy_input = torch.randn(1, 3, 1024, 1024)
        traced_encoder = torch.jit.trace(encoder, dummy_input)

        # Convert to Core ML
        encoder_mlmodel = ct.convert(
            traced_encoder,
            inputs=[ct.TensorType(name="image", shape=(1, 3, 1024, 1024))],
            outputs=[ct.TensorType(name="embedding")],
            minimum_deployment_target=ct.target.iOS17,
            compute_units=ct.ComputeUnit.ALL,
        )

        encoder_path = output_dir / "MobileSAM_Encoder.mlpackage"
        encoder_mlmodel.save(str(encoder_path))
        print(f"✅ Saved: {encoder_path}")

    except Exception as e:
        print(f"❌ Encoder conversion failed: {e}")
        return None

    # Export Mask Decoder (more complex, may require custom handling)
    print("⚠️ Mask decoder conversion requires additional setup.")
    print("   See: https://github.com/ChaoningZhang/MobileSAM for details")

    return output_dir / "MobileSAM_Encoder.mlpackage"


def main():
    parser = argparse.ArgumentParser(description="Convert models to Core ML")
    parser.add_argument("--output", "-o", type=str, default="./models",
                        help="Output directory for converted models")
    parser.add_argument("--yolo-size", type=str, default="s", choices=["s", "m", "l"],
                        help="YOLO-World model size (s/m/l)")
    parser.add_argument("--imgsz", type=int, default=640,
                        help="YOLO input image size")
    parser.add_argument("--skip-yolo", action="store_true",
                        help="Skip YOLO-World conversion")
    parser.add_argument("--skip-sam", action="store_true",
                        help="Skip MobileSAM conversion")
    parser.add_argument("--skip-embeddings", action="store_true",
                        help="Skip text embeddings generation")

    args = parser.parse_args()

    # Create output directory
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"\nOutput directory: {output_dir.absolute()}")

    # Convert YOLO-World
    if not args.skip_yolo:
        convert_yoloworld(output_dir, args.yolo_size, args.imgsz)

    # Generate text embeddings
    if not args.skip_embeddings:
        generate_text_embeddings(output_dir)

    # Convert MobileSAM
    if not args.skip_sam:
        convert_mobilesam(output_dir)

    print(f"\n{'='*50}")
    print("Conversion Complete!")
    print(f"{'='*50}")
    print(f"\nNext steps:")
    print(f"1. Copy the .mlpackage files to your Xcode project")
    print(f"2. Copy TextEmbeddings.json to your Xcode project")
    print(f"3. Add them to your app target")
    print(f"\nOutput location: {output_dir.absolute()}")


if __name__ == "__main__":
    main()
