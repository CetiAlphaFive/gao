#!/usr/bin/env python3
"""GPU OCR PDFs with Surya for GAO requester backfill.

Usage:
    python3 ocr_backfill.py <pdf_list_file> <output_dir>

Reads a file with one PDF path per line. For each PDF, renders pages 1-5
to images with pdftoppm, runs Surya OCR on GPU, and writes combined text
to <output_dir>/<slug>.txt.

Resumable: skips PDFs that already have output files.
"""

import os
import sys
import subprocess
import tempfile
from pathlib import Path

import torch
from PIL import Image
from surya.foundation import FoundationPredictor
from surya.recognition import RecognitionPredictor
from surya.detection import DetectionPredictor


def pdf_to_images(pdf_path, pages=5, dpi=200):
    """Render first N pages of a PDF to PIL Images via pdftoppm."""
    with tempfile.TemporaryDirectory() as tmp:
        try:
            subprocess.run(
                ["pdftoppm", "-f", "1", "-l", str(pages), "-r", str(dpi),
                 "-png", pdf_path, os.path.join(tmp, "page")],
                capture_output=True, timeout=30
            )
        except subprocess.TimeoutExpired:
            return []
        images = []
        for img_path in sorted(Path(tmp).glob("page-*.png")):
            images.append(Image.open(img_path).copy())
        return images


def main():
    pdf_list_file = sys.argv[1]
    output_dir = sys.argv[2]

    os.makedirs(output_dir, exist_ok=True)

    with open(pdf_list_file) as f:
        pdfs = [line.strip() for line in f if line.strip()]

    # Skip already-done and >5MB files
    todo = []
    skipped_size = 0
    for p in pdfs:
        slug = Path(p).stem.lower()
        out_file = Path(output_dir) / f"{slug}.txt"
        if out_file.exists() and out_file.stat().st_size > 0:
            continue
        if os.path.getsize(p) > 5 * 1024 * 1024:
            skipped_size += 1
            continue
        todo.append(p)

    print(f"Total: {len(pdfs)} | Already done: {len(pdfs) - len(todo) - skipped_size} | Skipped (>5MB): {skipped_size} | Todo: {len(todo)}")
    if not todo:
        return

    # Load models once
    print("Loading Surya models...")
    foundation = FoundationPredictor()
    det_predictor = DetectionPredictor()
    rec_predictor = RecognitionPredictor(foundation)
    print(f"Models loaded. CUDA: {torch.cuda.is_available()}")

    done = 0
    errors = 0
    for pdf_path in todo:
        slug = Path(pdf_path).stem.lower()
        out_file = Path(output_dir) / f"{slug}.txt"

        try:
            images = pdf_to_images(pdf_path)
            if not images:
                errors += 1
                continue

            predictions = rec_predictor(images, det_predictor=det_predictor)

            page_texts = []
            for pred in predictions:
                lines = [line.text for line in pred.text_lines]
                page_texts.append("\n".join(lines))

            with open(out_file, "w") as f:
                f.write("\n\n".join(page_texts))

            done += 1
        except Exception as e:
            errors += 1
            if errors <= 5:
                print(f"  Error on {slug}: {e}")

        total = done + errors
        if total % 50 == 0:
            print(f"  Progress: {total}/{len(todo)} (done={done}, errors={errors})")

    print(f"Complete: {done} succeeded, {errors} failed out of {len(todo)}")


if __name__ == "__main__":
    main()
