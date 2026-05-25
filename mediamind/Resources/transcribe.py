#!/usr/bin/env python3
"""
MLX Whisper transcription script for MediaMind
Usage: python3 transcribe.py <audio_file> --model <model_name> --output_dir <output_dir> [--vad] [--diarize] [--language <lang>] [--quantize <4bit|8bit>] [--initial_prompt <prompt>] [--fp16] [--batch_size <n>]
"""

import sys
import os
import argparse
import json
import time
import gc
import traceback

# MLX-specific imports for memory management
try:
    import mlx.core as mx
    HAS_MLX = True
except ImportError:
    HAS_MLX = False

try:
    import mlx_whisper
except ImportError:
    print("Error: mlx_whisper not installed. Run: pip install mlx-whisper", file=sys.stderr)
    sys.exit(1)


def log_performance_metrics(start_time, audio_duration, result):
    """Log detailed performance metrics"""
    end_time = time.time()
    processing_time = end_time - start_time

    # Calculate real-time factor (RTF) - lower is better
    # RTF = processing_time / audio_duration
    rtf = processing_time / audio_duration if audio_duration > 0 else 0

    # Calculate speedup factor - how many times faster than real-time
    speedup = audio_duration / processing_time if processing_time > 0 else 0

    metrics = {
        "processing_time_seconds": round(processing_time, 2),
        "audio_duration_seconds": round(audio_duration, 2),
        "real_time_factor": round(rtf, 4),
        "speedup_factor": round(speedup, 2),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
    }

    print(f"\n{'='*50}", file=sys.stderr)
    print("PERFORMANCE METRICS", file=sys.stderr)
    print(f"{'='*50}", file=sys.stderr)
    print(f"Audio duration:     {metrics['audio_duration_seconds']:.2f}s", file=sys.stderr)
    print(f"Processing time:    {metrics['processing_time_seconds']:.2f}s", file=sys.stderr)
    print(f"Real-time factor:   {metrics['real_time_factor']:.4f} (lower is better)", file=sys.stderr)
    print(f"Speedup:            {metrics['speedup_factor']:.2f}x real-time", file=sys.stderr)
    print(f"{'='*50}\n", file=sys.stderr)

    return metrics


def get_audio_duration(audio_path):
    """Get audio file duration in seconds using soundfile or ffmpeg"""
    try:
        import soundfile as sf
        info = sf.info(audio_path)
        return info.duration
    except ImportError:
        # Fallback: try to get duration from ffmpeg
        try:
            import subprocess
            result = subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                 "-of", "default=noprint_wrappers=1:nokey=1", audio_path],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                return float(result.stdout.strip())
        except Exception:
            pass
    return 0.0


def mlx_memory_cleanup():
    """MLX-specific memory cleanup with dual garbage collection"""
    if HAS_MLX:
        try:
            # Clear MLX cache
            mx.clear_cache()
            print("[Memory] MLX cache cleared", file=sys.stderr)
        except Exception as e:
            print(f"[Memory] MLX cache clear warning: {e}", file=sys.stderr)

    # Standard Python garbage collection
    gc.collect()

    # Second pass for more thorough cleanup
    gc.collect()

    if HAS_MLX:
        try:
            # Force synchronization if available
            mx.eval(mx.array(0))
        except Exception:
            pass

    print("[Memory] Dual garbage collection completed", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description="Transcribe audio using MLX Whisper")
    parser.add_argument("audio", help="Path to audio file")
    parser.add_argument("--model", default="base", help="Model name or path")
    parser.add_argument("--output_dir", required=True, help="Output directory")
    parser.add_argument("--vad", action="store_true", help="Enable voice activity detection")
    parser.add_argument("--diarize", action="store_true", help="Enable speaker diarization")
    parser.add_argument("--ffmpeg", default=None, help="Path to ffmpeg executable")
    parser.add_argument("--language", default=None, help="Language code (e.g., zh, en, ja)")
    parser.add_argument("--quantize", default=None, choices=["4bit", "8bit"], help="Quantization level for model")
    parser.add_argument("--initial_prompt", default=None, help="Initial prompt to guide transcription")
    parser.add_argument("--output_format", default="txt", choices=["txt", "json", "srt", "vtt"], help="Output format")
    parser.add_argument("--no_fp16", action="store_true", help="Disable FP16 precision (default: enabled)")
    parser.add_argument("--temperature", type=float, default=0.0, help="Sampling temperature (0.0 = greedy)")
    parser.add_argument("--best_of", type=int, default=5, help="Number of candidates when sampling")
    parser.add_argument("--beam_size", type=int, default=5, help="Beam size for beam search")
    parser.add_argument("--condition_on_previous_text", action="store_true", default=True, help="Condition on previous text")
    parser.add_argument("--no_condition_on_previous_text", action="store_true", help="Disable conditioning on previous text")

    args = parser.parse_args()

    # Record start time for performance tracking
    total_start_time = time.time()

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
        os.environ["FFMPEG_PATH"] = ffmpeg_path
    else:
        print("Warning: ffmpeg not found", file=sys.stderr)

    # Map model names to HuggingFace repo paths
    model_map = {
        # Base models
        "tiny": "mlx-community/whisper-tiny",
        "base": "mlx-community/whisper-base",
        "small": "mlx-community/whisper-small",
        "medium": "mlx-community/whisper-medium",
        "large": "mlx-community/whisper-large-v3",
        "large-v3": "mlx-community/whisper-large-v3",
        "large-v2": "mlx-community/whisper-large-v2",
        # 4-bit quantized models (faster, lower memory)
        "tiny-4bit": "mlx-community/whisper-tiny-mlx-4bit",
        "base-4bit": "mlx-community/whisper-base-mlx-4bit",
        "small-4bit": "mlx-community/whisper-small-mlx-4bit",
        "medium-4bit": "mlx-community/whisper-medium-mlx-4bit",
        "large-4bit": "mlx-community/whisper-large-v3-mlx-4bit",
        "large-v3-4bit": "mlx-community/whisper-large-v3-mlx-4bit",
        # 8-bit quantized models (balanced)
        "tiny-8bit": "mlx-community/whisper-tiny-mlx-8bit",
        "base-8bit": "mlx-community/whisper-base-mlx-8bit",
        "small-8bit": "mlx-community/whisper-small-mlx-8bit",
        "medium-8bit": "mlx-community/whisper-medium-mlx-8bit",
        "large-8bit": "mlx-community/whisper-large-v3-mlx-8bit",
        "large-v3-8bit": "mlx-community/whisper-large-v3-mlx-8bit",
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

    # Get audio duration for performance metrics
    audio_duration = get_audio_duration(args.audio)
    if audio_duration > 0:
        print(f"Audio duration: {audio_duration:.2f}s", file=sys.stderr)

    # Build transcribe arguments with optimized defaults
    transcribe_args = {
        "path_or_hf_repo": model_path,
        "verbose": True,
        "task": "transcribe",
        "fp16": not args.no_fp16,
    }

    print(f"FP16 enabled: {transcribe_args['fp16']}", file=sys.stderr)

    # Add optional arguments
    if args.language:
        transcribe_args["language"] = args.language
        print(f"Language: {args.language}", file=sys.stderr)

    if args.initial_prompt:
        transcribe_args["initial_prompt"] = args.initial_prompt
        print(f"Initial prompt provided", file=sys.stderr)

    # Performance optimization parameters
    if args.temperature != 0.0:
        transcribe_args["temperature"] = args.temperature
        print(f"Temperature: {args.temperature}", file=sys.stderr)

    if args.best_of != 5:
        transcribe_args["best_of"] = args.best_of

    if args.beam_size != 5:
        transcribe_args["beam_size"] = args.beam_size

    if args.no_condition_on_previous_text:
        transcribe_args["condition_on_previous_text"] = False

    # Log all parameters for debugging
    print(f"Transcribe args: {transcribe_args}", file=sys.stderr)

    try:
        # Perform transcription with timing
        transcription_start = time.time()

        result = mlx_whisper.transcribe(
            args.audio,
            **transcribe_args
        )

        transcription_time = time.time() - transcription_start
        print(f"Transcription completed in {transcription_time:.2f}s", file=sys.stderr)

        # Format output based on requested format
        output_path = os.path.join(args.output_dir, f"transcription.{args.output_format}")

        if args.output_format == "json":
            output_text = format_json_output(result)
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(output_text)
        elif args.output_format == "srt":
            output_text = format_srt_output(result)
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(output_text)
        elif args.output_format == "vtt":
            output_text = format_vtt_output(result)
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(output_text)
        else:
            # Default txt format
            output_lines = []
            if "segments" in result:
                for segment in result["segments"]:
                    start = segment.get("start", 0)
                    end = segment.get("end", 0)
                    text = segment.get("text", "").strip()
                    if text:
                        output_lines.append(f"[{format_time(start)} - {format_time(end)}] {text}")

            output_text = "\n".join(output_lines)
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(output_text)

        print(f"Transcription saved to: {output_path}", file=sys.stderr)
        # Only print the transcription text to stdout
        print(output_text, file=sys.stdout)

        # Log performance metrics
        if audio_duration > 0:
            metrics = log_performance_metrics(total_start_time, audio_duration, result)

            # Save metrics to JSON file
            metrics_path = os.path.join(args.output_dir, "transcription_metrics.json")
            try:
                with open(metrics_path, "w", encoding="utf-8") as f:
                    json.dump(metrics, f, ensure_ascii=False, indent=2)
                print(f"Performance metrics saved to: {metrics_path}", file=sys.stderr)
            except Exception as e:
                print(f"Warning: Could not save metrics: {e}", file=sys.stderr)

        # MLX-specific memory cleanup with dual garbage collection
        print("Starting memory cleanup...", file=sys.stderr)
        del result
        mlx_memory_cleanup()
        print("Transcription completed and resources cleaned up", file=sys.stderr)

    except Exception as e:
        # Detailed error reporting with stack trace
        error_details = {
            "error_type": type(e).__name__,
            "error_message": str(e),
            "stack_trace": traceback.format_exc(),
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "audio_file": args.audio,
            "model": model_path,
        }

        print(f"\n{'='*50}", file=sys.stderr)
        print("TRANSCRIPTION ERROR", file=sys.stderr)
        print(f"{'='*50}", file=sys.stderr)
        print(f"Error type: {error_details['error_type']}", file=sys.stderr)
        print(f"Error message: {error_details['error_message']}", file=sys.stderr)
        print(f"\nStack trace:", file=sys.stderr)
        print(error_details['stack_trace'], file=sys.stderr)
        print(f"{'='*50}\n", file=sys.stderr)

        # Save error details to file
        error_path = os.path.join(args.output_dir, "transcription_error.json")
        try:
            with open(error_path, "w", encoding="utf-8") as f:
                json.dump(error_details, f, ensure_ascii=False, indent=2)
            print(f"Error details saved to: {error_path}", file=sys.stderr)
        except Exception:
            pass

        sys.exit(1)


def format_time(seconds):
    """Format seconds to HH:MM:SS.mmm"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds % 1) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"


def format_time_ms(seconds):
    """Format seconds to HH:MM:SS,mmm for SRT/VTT"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds % 1) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


def format_json_output(result):
    """Format result as JSON"""
    # Extract relevant fields for cleaner JSON
    output = {
        "text": result.get("text", ""),
        "language": result.get("language", "unknown"),
        "segments": []
    }

    if "segments" in result:
        for segment in result["segments"]:
            output["segments"].append({
                "start": segment.get("start", 0),
                "end": segment.get("end", 0),
                "text": segment.get("text", "").strip(),
            })

    return json.dumps(output, ensure_ascii=False, indent=2)


def format_srt_output(result):
    """Format result as SRT subtitle"""
    lines = []
    if "segments" in result:
        for i, segment in enumerate(result["segments"], 1):
            start = segment.get("start", 0)
            end = segment.get("end", 0)
            text = segment.get("text", "").strip()
            if text:
                lines.append(f"{i}")
                lines.append(f"{format_time_ms(start)} --> {format_time_ms(end)}")
                lines.append(text)
                lines.append("")
    return "\n".join(lines)


def format_vtt_output(result):
    """Format result as WebVTT subtitle"""
    lines = ["WEBVTT", ""]
    if "segments" in result:
        for segment in result["segments"]:
            start = segment.get("start", 0)
            end = segment.get("end", 0)
            text = segment.get("text", "").strip()
            if text:
                # VTT uses dot instead of comma for milliseconds
                start_str = format_time_ms(start).replace(",", ".")
                end_str = format_time_ms(end).replace(",", ".")
                lines.append(f"{start_str} --> {end_str}")
                lines.append(text)
                lines.append("")
    return "\n".join(lines)


def find_ffmpeg():
    """Find ffmpeg executable in common locations"""
    possible_paths = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg",
    ]
    for path in possible_paths:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return None


if __name__ == "__main__":
    main()
