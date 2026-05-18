#!/usr/bin/env python3
"""
MLX Whisper transcription script for MediaMind
Usage: python3 transcribe.py <audio_file> --model <model_name> --output_dir <output_dir> [--vad] [--diarize]
"""

import sys
import os
import argparse

try:
    import mlx_whisper
except ImportError:
    print("Error: mlx_whisper not installed. Run: pip install mlx-whisper", file=sys.stderr)
    sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Transcribe audio using MLX Whisper")
    parser.add_argument("audio", help="Path to audio file")
    parser.add_argument("--model", default="base", help="Model name or path")
    parser.add_argument("--output_dir", required=True, help="Output directory")
    parser.add_argument("--vad", action="store_true", help="Enable voice activity detection")
    parser.add_argument("--diarize", action="store_true", help="Enable speaker diarization")
    parser.add_argument("--ffmpeg", default=None, help="Path to ffmpeg executable")

    args = parser.parse_args()

    # Set ffmpeg path - use provided path or find it
    if args.ffmpeg and os.path.isfile(args.ffmpeg):
        ffmpeg_path = args.ffmpeg
        print(f"Using provided ffmpeg: {ffmpeg_path}", file=sys.stderr)
    else:
        ffmpeg_path = find_ffmpeg()
        print(f"Found ffmpeg: {ffmpeg_path}", file=sys.stderr)

    if ffmpeg_path:
        ffmpeg_dir = os.path.dirname(ffmpeg_path)
        os.environ["PATH"] = ffmpeg_dir + ":" + os.environ.get("PATH", "")
        # Also set a known location symlink if needed
        os.environ["FFMPEG_PATH"] = ffmpeg_path
    else:
        print("Warning: ffmpeg not found", file=sys.stderr)

    # Map model names to HuggingFace repo paths
    model_map = {
        "tiny": "mlx-community/whisper-tiny",
        "base": "mlx-community/whisper-base",
        "small": "mlx-community/whisper-small",
        "medium": "mlx-community/whisper-medium",
        "large": "mlx-community/whisper-large-v3",
        "large-v3": "mlx-community/whisper-large-v3",
        "large-v2": "mlx-community/whisper-large-v2",
    }

    # 处理用户输入的模型名称
    model_input = args.model.strip()

    # 如果用户输入的是完整路径或 HuggingFace repo，直接使用
    if model_input.startswith("mlx-community/") or model_input.startswith("/") or os.path.exists(model_input):
        model_path = model_input
    # 如果包含冒号（如 mlx-community:whisper-large-v2-mlx-4bit），替换为斜杠
    elif ":" in model_input and "/" not in model_input:
        model_path = model_input.replace(":", "/")
    else:
        model_path = model_map.get(model_input, model_input)

    print(f"Transcribing with model: {model_path}", file=sys.stderr)
    print(f"Audio file: {args.audio}", file=sys.stderr)

    try:
        result = mlx_whisper.transcribe(
            args.audio,
            path_or_hf_repo=model_path,
            verbose=True
        )

        # Format output
        output_lines = []
        if "segments" in result:
            for segment in result["segments"]:
                start = segment.get("start", 0)
                end = segment.get("end", 0)
                text = segment.get("text", "").strip()
                if text:
                    output_lines.append(f"[{format_time(start)} - {format_time(end)}] {text}")

        output_text = "\n".join(output_lines)

        # Write to output file
        output_path = os.path.join(args.output_dir, "transcription.txt")
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(output_text)

        print(f"Transcription saved to: {output_path}", file=sys.stderr)
        print(output_text)

    except Exception as e:
        print(f"Transcription failed: {e}", file=sys.stderr)
        sys.exit(1)

def format_time(seconds):
    """Format seconds to HH:MM:SS"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"

if __name__ == "__main__":
    main()
